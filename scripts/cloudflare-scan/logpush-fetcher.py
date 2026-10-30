#!/usr/bin/env python3
"""
Cloudflare Account-Scoped Logpush Consolidator
==============================================
Fetches, filters, and consolidates Cloudflare Logpush logs from Cloudflare R2:
1. Connects to R2 using credentials loaded directly from backend/.env.
2. Filters log batches for the last 30 days (or customizable --days) based on
   the Cloudflare Logpush filename timestamp (YYYYMMDDTHHMMSSZ).
3. Decompresses each .log.gz stream on the fly and merges all records into a
   single consolidated .jsonl file (no zip needed).
4. Optionally flattens into CSV for downstream security auditor scripts.

Usage:
------
# Using Miniconda environment:
conda activate localpython

# Default: Fetch last 30 days and merge into scripts/cloudflare-scan/data/cloudflare_requests_log.jsonl (and .csv)
python3 logpush-fetcher.py

# Convert existing JSONL to CSV without re-downloading:
python3 logpush-fetcher.py --convert-only

# Custom bucket or day range:
python3 logpush-fetcher.py --bucket my-logpush-bucket --days 14

# Save individual raw .log.gz files as well:
python3 logpush-fetcher.py --save-raw
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Tuple

try:
    import boto3
    from botocore.config import Config
    from botocore.exceptions import ClientError
except ImportError:
    print("[ERROR] 'boto3' is required. Run: conda activate localpython && pip install boto3")
    sys.exit(1)

try:
    from rich.console import Console
    from rich.progress import BarColumn, Progress, SpinnerColumn, TextColumn, TimeRemainingColumn
    from rich.table import Table
    console = Console()
    HAS_RICH = True
except ImportError:
    console = None
    HAS_RICH = False


# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_ENV_FILE = PROJECT_ROOT / "backend" / ".env"
DEFAULT_OUTPUT_DIR = SCRIPT_DIR / "data"
DEFAULT_OUTPUT_JSONL = DEFAULT_OUTPUT_DIR / "cloudflare_requests_log.jsonl"

# Cloudflare Logpush Timestamp Regex (e.g. 20261014T004530Z_20261014T004530Z_36f426b1.log.gz)
TIMESTAMP_REGEX = re.compile(r"(\d{8}T\d{6}Z)")


def log_info(msg: str):
    if HAS_RICH and console:
        console.print(f"[bold blue]INFO[/bold blue] {msg}")
    else:
        print(f"INFO: {msg}")


def log_success(msg: str):
    if HAS_RICH and console:
        console.print(f"[bold green]SUCCESS[/bold green] {msg}")
    else:
        print(f"SUCCESS: {msg}")


def log_warn(msg: str):
    if HAS_RICH and console:
        console.print(f"[bold yellow]WARNING[/bold yellow] {msg}")
    else:
        print(f"WARNING: {msg}")


def log_error(msg: str):
    if HAS_RICH and console:
        console.print(f"[bold red]ERROR[/bold red] {msg}")
    else:
        print(f"ERROR: {msg}", file=sys.stderr)


def load_env_credentials(env_path: Path) -> Dict[str, str]:
    """
    Parses key-value pairs from .env without external dependencies.
    Handles export prefixes, quoted strings, inline comments, and whitespace.
    """
    credentials = {}
    if not env_path.is_file():
        return credentials

    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # Strip optional 'export '
            if line.startswith("export "):
                line = line[7:].strip()
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            key = key.strip()
            val = val.strip()
            # Remove surrounding matching quotes
            if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            credentials[key] = val

    return credentials


def parse_file_timestamp(key: str) -> Optional[datetime]:
    """
    Extracts the UTC start datetime from the Cloudflare Logpush filename.
    Format: 20261014T004530Z_... -> datetime(2026, 10, 14, 0, 45, 30, tzinfo=UTC)
    """
    filename = Path(key).name
    match = TIMESTAMP_REGEX.search(filename)
    if match:
        try:
            return datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None


def get_r2_client(account_id: str, access_key: str, secret_key: str):
    """Initializes a Boto3 S3 client configured for Cloudflare R2."""
    endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(
            retries={"max_attempts": 5, "mode": "standard"},
            connect_timeout=15,
            read_timeout=60,
        ),
    )


def list_matching_logpush_objects(
    client,
    bucket: str,
    prefix: str,
    cutoff_datetime: datetime,
    limit: Optional[int] = None,
) -> List[Tuple[str, int, datetime]]:
    """
    Scans R2 bucket for .log.gz objects whose timestamp falls within the cutoff window.
    Returns sorted list of (key, size, timestamp).
    """
    matching: List[Tuple[str, int, datetime]] = []
    paginator = client.get_paginator("list_objects_v2")

    log_info(f"Scanning bucket [cyan]'{bucket}'[/cyan] with prefix [cyan]'{prefix}'[/cyan]...")
    total_scanned = 0

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        contents = page.get("Contents", [])
        total_scanned += len(contents)
        for obj in contents:
            key = obj["Key"]
            if not key.endswith(".log.gz"):
                continue

            size = obj.get("Size", 0)
            file_time = parse_file_timestamp(key)
            if file_time is None:
                # Fallback to S3 LastModified if filename doesn't match standard pattern
                file_time = obj.get("LastModified", datetime.now(timezone.utc))

            if file_time >= cutoff_datetime:
                matching.append((key, size, file_time))
                if limit and len(matching) >= limit:
                    break
        if limit and len(matching) >= limit:
            break

    # Sort chronologically by timestamp
    matching.sort(key=lambda x: x[2])
    log_info(f"Total objects scanned: {total_scanned} | Matching within timeframe: [bold]{len(matching)}[/bold]")
    return matching


def stream_decompress_and_merge(
    client,
    bucket: str,
    objects: List[Tuple[str, int, datetime]],
    output_path: Path,
    raw_dir: Optional[Path] = None,
) -> Dict[str, Any]:
    """
    Downloads and decompresses .log.gz files on the fly, streaming JSON lines
    directly into a single consolidated .jsonl file.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if raw_dir:
        raw_dir.mkdir(parents=True, exist_ok=True)

    total_records = 0
    total_bytes_downloaded = 0
    total_bytes_written = 0
    start_time = time.time()
    field_names = set()

    with open(output_path, "w", encoding="utf-8") as out_f:
        if HAS_RICH and console:
            progress = Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
                TextColumn("• {task.completed}/{task.total} files"),
                TimeRemainingColumn(),
            )
            with progress:
                task = progress.add_task("[green]Consolidating logs...", total=len(objects))
                for key, size, _ in objects:
                    records, dl_bytes, wr_bytes, fnames = _process_single_object(
                        client, bucket, key, out_f, raw_dir
                    )
                    total_records += records
                    total_bytes_downloaded += dl_bytes
                    total_bytes_written += wr_bytes
                    field_names.update(fnames)
                    progress.advance(task)
        else:
            for i, (key, size, _) in enumerate(objects, 1):
                records, dl_bytes, wr_bytes, fnames = _process_single_object(
                    client, bucket, key, out_f, raw_dir
                )
                total_records += records
                total_bytes_downloaded += dl_bytes
                total_bytes_written += wr_bytes
                field_names.update(fnames)
                if i % 25 == 0 or i == len(objects):
                    print(f"Progress: {i}/{len(objects)} files processed ({total_records} records)...")

    duration = time.time() - start_time
    return {
        "files_processed": len(objects),
        "total_records": total_records,
        "bytes_downloaded": total_bytes_downloaded,
        "bytes_written": total_bytes_written,
        "duration_seconds": duration,
        "field_names": sorted(field_names),
        "output_path": output_path,
    }


def _process_single_object(
    client,
    bucket: str,
    key: str,
    out_f,
    raw_dir: Optional[Path],
) -> Tuple[int, int, int, set]:
    """Helper to download, decompress, and write a single log object."""
    resp = client.get_object(Bucket=bucket, Key=key)
    compressed_data = resp["Body"].read()
    dl_bytes = len(compressed_data)

    if raw_dir:
        raw_file_path = raw_dir / Path(key).name
        with open(raw_file_path, "wb") as rf:
            rf.write(compressed_data)

    records = 0
    wr_bytes = 0
    fnames = set()

    with gzip.GzipFile(fileobj=io.BytesIO(compressed_data), mode="rb") as gz:
        for line in gz:
            line_str = line.decode("utf-8", errors="replace").strip()
            if not line_str:
                continue
            out_f.write(line_str + "\n")
            wr_bytes += len(line_str) + 1
            records += 1

            # Sample first few lines for field discovery
            if records <= 3:
                try:
                    data = json.loads(line_str)
                    if isinstance(data, dict):
                        fnames.update(data.keys())
                except Exception:
                    pass

    return records, dl_bytes, wr_bytes, fnames


def convert_jsonl_to_csv(jsonl_path: Path, csv_path: Path, field_names: Optional[List[str]] = None) -> int:
    """Converts consolidated .jsonl into a flattened CSV."""
    if not jsonl_path.is_file():
        log_error(f"Cannot convert: {jsonl_path} does not exist.")
        return 0

    fields = set(field_names or [])
    # Scan all records to ensure every column from every event type is included
    with open(jsonl_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                if isinstance(data, dict):
                    fields.update(data.keys())
            except Exception:
                pass

    ordered_fields = sorted(fields)
    log_info(f"Converting JSONL to CSV: [cyan]{csv_path.name}[/cyan] ({len(ordered_fields)} columns)...")
    records = 0
    with open(jsonl_path, "r", encoding="utf-8") as jf, open(csv_path, "w", newline="", encoding="utf-8") as cf:
        writer = csv.DictWriter(cf, fieldnames=ordered_fields, extrasaction="ignore")
        writer.writeheader()
        for line in jf:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
                if isinstance(row, dict):
                    cleaned = {}
                    for k, v in row.items():
                        if isinstance(v, (dict, list)):
                            cleaned[k] = json.dumps(v, ensure_ascii=False)
                        else:
                            cleaned[k] = v
                    writer.writerow(cleaned)
                    records += 1
            except Exception:
                pass

    return records


def format_bytes(num_bytes: int) -> str:
    """Formats bytes to human-readable size."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if abs(num_bytes) < 1024.0:
            return f"{num_bytes:3.1f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.1f} PB"


def print_summary_table(stats: Dict[str, Any], days: int, bucket: str):
    """Renders a formatted completion summary."""
    if HAS_RICH and console:
        table = Table(title="Cloudflare Logpush Consolidation Summary", border_style="cyan")
        table.add_column("Property", style="bold white")
        table.add_column("Value", style="green")

        table.add_row("R2 Bucket", bucket)
        table.add_row("Timeframe Filter", f"Last {days} days")
        table.add_row("Log Batches Consolidated", f"{stats['files_processed']:,} files")
        table.add_row("Total Records Extracted", f"{stats['total_records']:,} lines")
        table.add_row("Compressed Bytes Downloaded", format_bytes(stats["bytes_downloaded"]))
        table.add_row("Uncompressed File Size", format_bytes(stats["bytes_written"]))
        table.add_row("Consolidated Output", str(stats["output_path"]))
        table.add_row("Duration", f"{stats['duration_seconds']:.2f} seconds")

        console.print("")
        console.print(table)
        console.print("")
    else:
        print("\n" + "=" * 60)
        print("CLOUDFLARE LOGPUSH CONSOLIDATION SUMMARY")
        print("=" * 60)
        print(f"R2 Bucket:               {bucket}")
        print(f"Timeframe:               Last {days} days")
        print(f"Log Batches:             {stats['files_processed']} files")
        print(f"Total Records:           {stats['total_records']} lines")
        print(f"Downloaded Size:         {format_bytes(stats['bytes_downloaded'])}")
        print(f"Uncompressed File Size:  {format_bytes(stats['bytes_written'])}")
        print(f"Output File:             {stats['output_path']}")
        print(f"Duration:                {stats['duration_seconds']:.2f} seconds")
        print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Fetch, filter, and consolidate Cloudflare Account Logpush from R2 into a single .jsonl file."
    )
    parser.add_argument(
        "--days",
        type=int,
        default=30,
        help="Number of past days of logs to retrieve (default: 30).",
    )
    parser.add_argument(
        "--bucket",
        type=str,
        default=None,
        help="Override R2 bucket name (default: reads R2_BUCKET_NAME or R2_LOGPUSH_BUCKET_NAME from backend/.env).",
    )
    parser.add_argument(
        "--prefix",
        type=str,
        default="",
        help="Subfolder / prefix in R2 bucket where Logpush writes (default: empty / bucket root).",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help=f"Output consolidated .jsonl path (default: {DEFAULT_OUTPUT_JSONL}).",
    )
    parser.add_argument(
        "--env-file",
        type=str,
        default=str(DEFAULT_ENV_FILE),
        help=f"Path to .env containing R2 credentials (default: {DEFAULT_ENV_FILE}).",
    )
    parser.add_argument(
        "--no-csv",
        dest="to_csv",
        action="store_false",
        help="Disable automatic CSV export (CSV is generated by default alongside .jsonl).",
    )
    parser.add_argument(
        "--to-csv",
        dest="to_csv",
        action="store_true",
        default=True,
        help="Export a flattened .csv file alongside the .jsonl (enabled by default).",
    )
    parser.add_argument(
        "--convert-only",
        nargs="?",
        const=str(DEFAULT_OUTPUT_JSONL),
        default=None,
        help=f"Convert an existing .jsonl file to .csv without re-downloading from R2 (default: {DEFAULT_OUTPUT_JSONL}).",
    )
    parser.add_argument(
        "--save-raw",
        action="store_true",
        help="Also save downloaded .log.gz files into data/raw_logs/.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional safety limit on maximum number of .log.gz batches to process (useful for test runs).",
    )

    args = parser.parse_args()

    # Short-circuit: Direct JSONL-to-CSV conversion mode
    if args.convert_only is not None:
        jsonl_in = Path(args.convert_only).resolve()
        if not jsonl_in.is_file():
            log_error(f"Target JSONL file not found: {jsonl_in}")
            sys.exit(1)
        csv_out = jsonl_in.with_suffix(".csv")
        log_info(f"Direct JSONL-to-CSV mode: reading [cyan]{jsonl_in}[/cyan]...")
        count = convert_jsonl_to_csv(jsonl_in, csv_out)
        log_success(f"Converted [bold green]{count}[/bold green] records to [bold green]{csv_out}[/bold green]")
        return

    # 1. Load credentials
    env_path = Path(args.env_file).resolve()
    if not env_path.is_file():
        # Fallback to local .env in current working dir
        fallback = Path(".env").resolve()
        if fallback.is_file():
            env_path = fallback

    log_info(f"Loading R2 credentials from [cyan]'{env_path}'[/cyan]...")
    env_vars = load_env_credentials(env_path)

    account_id = env_vars.get("R2_ACCOUNT_ID") or os.environ.get("R2_ACCOUNT_ID")
    access_key = env_vars.get("R2_LOGPUSH_ACCESS_KEY_ID") or os.environ.get("R2_ACCESS_KEY_ID")
    secret_key = env_vars.get("R2_LOGPUSH_SECRET_ACCESS_KEY") or os.environ.get("R2_SECRET_ACCESS_KEY")
    bucket = (
        args.bucket
        or env_vars.get("R2_LOGPUSH_BUCKET_NAME")
        or env_vars.get("R2_BUCKET_NAME")
        or os.environ.get("R2_BUCKET_NAME")
    )

    if not account_id or not access_key or not secret_key:
        log_error("Missing R2 credentials. Ensure R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY exist in .env.")
        sys.exit(1)

    if not bucket:
        log_error("R2 bucket name not specified. Pass --bucket <name> or set R2_BUCKET_NAME in backend/.env.")
        sys.exit(1)

    output_path = Path(args.output).resolve() if args.output else DEFAULT_OUTPUT_JSONL
    raw_dir = (output_path.parent / "raw_logs") if args.save_raw else None

    # 2. Compute date cutoff
    now_utc = datetime.now(timezone.utc)
    cutoff_datetime = now_utc - timedelta(days=args.days)
    log_info(f"Consolidation window: [bold]{cutoff_datetime.strftime('%Y-%m-%d %H:%M:%S UTC')}[/bold] to [bold]{now_utc.strftime('%Y-%m-%d %H:%M:%S UTC')}[/bold] ({args.days} days)")

    # 3. Connect to Cloudflare R2
    try:
        client = get_r2_client(account_id, access_key, secret_key)
    except Exception as e:
        log_error(f"Failed to initialize R2 client: {e}")
        sys.exit(1)

    # 4. List matching Logpush objects
    try:
        matching_objects = list_matching_logpush_objects(
            client=client,
            bucket=bucket,
            prefix=args.prefix,
            cutoff_datetime=cutoff_datetime,
            limit=args.limit,
        )
    except ClientError as e:
        log_error(f"R2 API ClientError while listing objects: {e}")
        sys.exit(1)
    except Exception as e:
        log_error(f"Failed scanning bucket: {e}")
        sys.exit(1)

    if not matching_objects:
        log_warn(f"No .log.gz files found in bucket '{bucket}' within the last {args.days} days.")
        log_info("Tip: If Logpush writes to a specific prefix, pass --prefix <prefix_path> (e.g. --prefix logs/).")
        sys.exit(0)

    # 5. Stream decompress and merge into single .jsonl
    log_info(f"Extracting and merging [bold]{len(matching_objects)}[/bold] log batches into [green]{output_path.name}[/green]...")
    stats = stream_decompress_and_merge(
        client=client,
        bucket=bucket,
        objects=matching_objects,
        output_path=output_path,
        raw_dir=raw_dir,
    )

    # 6. Optional CSV conversion
    if args.to_csv:
        csv_path = output_path.with_suffix(".csv")
        convert_jsonl_to_csv(output_path, csv_path, stats["field_names"])
        stats["csv_path"] = csv_path

    # 7. Print summary
    print_summary_table(stats, args.days, bucket)
    log_success(f"Log consolidation complete: [bold green]{output_path}[/bold green]")
    if args.to_csv:
        log_success(f"CSV export ready: [bold green]{output_path.with_suffix('.csv')}[/bold green]")


if __name__ == "__main__":
    main()
