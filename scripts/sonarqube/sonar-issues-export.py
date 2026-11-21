#!/usr/bin/env python3
"""
SonarQube Issues Export Tool
Exports SonarQube project issues to Excel (.xlsx) or CSV format with memory-efficient
chunking, retry logic, data flattening, logging, and summary reporting.

Follows the specifications defined in scripts/sonarqube/sonar-audit-format.md.
Credentials and configuration are loaded from backend/.env and environment variables.
Defaults to exporting ALL open issues to scripts/sonarqube/reports/sonarqube-issue.xlsx.
"""

import os
import sys
import argparse
import base64
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path

# Dependency checks with actionable install guidance
try:
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util import Retry
except ImportError:
    print("❌ Missing required dependency: requests")
    print("Run: pip install -r scripts/sonarqube/requirements.txt")
    sys.exit(1)

try:
    import pandas as pd
    import openpyxl
except ImportError:
    print("❌ Missing required dependencies: pandas, openpyxl")
    print("Run: pip install -r scripts/sonarqube/requirements.txt")
    sys.exit(1)

try:
    from tqdm import tqdm
    TQDM_AVAILABLE = True
except ImportError:
    TQDM_AVAILABLE = False

# Path resolution
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
BACKEND_ENV_PATH = REPO_ROOT / 'backend' / '.env'
REPORTS_DIR = REPO_ROOT / 'reports' / 'sonarqube'
LOGS_DIR = REPORTS_DIR / 'logs'

# Ensure output directories exist
os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

DEFAULT_OUTPUT_XLSX = REPORTS_DIR / 'sonarqube-issue.xlsx'
DEFAULT_OUTPUT_CSV = REPORTS_DIR / 'sonarqube-issue.csv'


def load_env_variables():
    """
    Load environment variables from backend/.env (primary target)
    and fallback .env files, without overriding explicitly set process environment vars.
    """
    # 1. Try python-dotenv if available
    try:
        from dotenv import load_dotenv
        if BACKEND_ENV_PATH.is_file():
            load_dotenv(dotenv_path=BACKEND_ENV_PATH, override=False)
        local_env = SCRIPT_DIR / '.env'
        if local_env.is_file():
            load_dotenv(dotenv_path=local_env, override=False)
    except ImportError:
        pass

    # 2. Manual parser fallback to guarantee reading backend/.env
    if BACKEND_ENV_PATH.is_file():
        try:
            with open(BACKEND_ENV_PATH, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#') or '=' not in line:
                        continue
                    key, val = line.split('=', 1)
                    key = key.strip()
                    val = val.strip().strip("'\"")
                    if key and val and key not in os.environ:
                        os.environ[key] = val
        except Exception as e:
            print(f"⚠️ Warning reading backend/.env manually: {e}")


load_env_variables()

# Configure logging (Priority 2.1)
log_filename = LOGS_DIR / f'sonar-export-{datetime.now().strftime("%Y%m%d-%H%M%S")}.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def create_session_with_retries():
    """
    Create a requests Session with automatic retry strategy (Priority 2.2).
    Retries on transient network errors and rate-limiting / server error status codes.
    """
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,  # Wait 1s, 2s, 4s between retries
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def flatten_issue(issue):
    """
    Extract and flatten useful fields from a SonarQube issue JSON (Priority 2.3).
    Returns a clean dictionary suitable for CSV / Excel export.
    """
    text_range = issue.get('textRange', {})
    tags = issue.get('tags', [])
    transitions = issue.get('transitions', [])
    actions = issue.get('actions', [])
    comments = issue.get('comments', [])
    flows = issue.get('flows', [])

    return {
        'key': issue.get('key', ''),
        'rule': issue.get('rule', ''),
        'severity': issue.get('severity', ''),
        'component': issue.get('component', ''),
        'componentLongName': issue.get('componentLongName', ''),
        'project': issue.get('project', ''),
        'subProject': issue.get('subProject', ''),
        'line': issue.get('line', text_range.get('startLine', '')),
        'hash': issue.get('hash', ''),
        'textRange': json.dumps(text_range) if text_range else '',
        'message': issue.get('message', ''),
        'author': issue.get('author', ''),
        'assignee': issue.get('assignee', ''),
        'status': issue.get('status', ''),
        'resolution': issue.get('resolution', ''),
        'type': issue.get('type', ''),
        'tags': ','.join(tags) if isinstance(tags, list) else str(tags),
        'creationDate': issue.get('creationDate', ''),
        'updateDate': issue.get('updateDate', ''),
        'closeDate': issue.get('closeDate', ''),
        'effort': issue.get('effort', ''),
        'debt': issue.get('debt', ''),
        'transitions': ','.join(transitions) if isinstance(transitions, list) else '',
        'actions': ','.join(actions) if isinstance(actions, list) else '',
        'comments': len(comments) if isinstance(comments, list) else 0,
        'flows': len(flows) if isinstance(flows, list) else 0,
    }


def write_chunk_to_csv(filename, chunk_data, mode='w'):
    """
    Write a chunk of issue data to a CSV file in a memory-efficient way (Priority 1.2).
    """
    df = pd.DataFrame(chunk_data)
    df.to_csv(filename, index=False, mode=mode, header=(mode == 'w'), encoding='utf-8')


def convert_csv_to_excel(csv_file, xlsx_file, keep_csv=False):
    """
    Convert CSV file to Excel format in chunks to avoid memory bottlenecks (Priority 1.2).
    """
    logger.info("🔄 Converting CSV to Excel format...")
    try:
        chunk_size = 50000
        chunks = []
        for chunk in pd.read_csv(csv_file, chunksize=chunk_size, low_memory=False):
            chunks.append(chunk)

        if chunks:
            df = pd.concat(chunks, ignore_index=True)
        else:
            df = pd.DataFrame()

        df.to_excel(xlsx_file, index=False, engine='openpyxl')
        logger.info(f"✅ Excel file created: {xlsx_file}")

        if not keep_csv and os.path.exists(csv_file) and str(csv_file) != str(xlsx_file):
            try:
                os.remove(csv_file)
                logger.info(f"🗑️ Removed intermediate CSV file: {csv_file}")
            except OSError as err:
                logger.warning(f"Could not remove intermediate CSV: {err}")
    except Exception as e:
        logger.error(f"⚠️ Warning: Could not convert to Excel: {e}")
        logger.info(f"💡 CSV file is still available at: {csv_file}")


def generate_summary_report(data_file, output_txt_file):
    """
    Generate an executive summary report from exported issue data (Priority 2.5).
    """
    try:
        if str(data_file).endswith('.csv'):
            df = pd.read_csv(data_file, low_memory=False)
        else:
            df = pd.read_excel(data_file, engine='openpyxl')

        if df.empty:
            logger.info("ℹ️ No data available for summary report.")
            return

        summary = []
        summary.append("=" * 70)
        summary.append("SONARQUBE EXPORT AUDIT SUMMARY REPORT")
        summary.append("=" * 70)
        summary.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        summary.append(f"Source File: {data_file}")
        summary.append(f"Total Open Issues Exported: {len(df):,}")

        # By Severity
        if 'severity' in df.columns:
            summary.append("\n" + "-" * 70)
            summary.append("ISSUES BY SEVERITY")
            summary.append("-" * 70)
            for severity, count in df['severity'].value_counts().items():
                pct = (count / len(df)) * 100
                summary.append(f"  {severity:<18} {count:>8,} ({pct:>5.1f}%)")

        # By Type
        if 'type' in df.columns:
            summary.append("\n" + "-" * 70)
            summary.append("ISSUES BY TYPE")
            summary.append("-" * 70)
            for itype, count in df['type'].value_counts().items():
                pct = (count / len(df)) * 100
                summary.append(f"  {itype:<18} {count:>8,} ({pct:>5.1f}%)")

        # By Status
        if 'status' in df.columns:
            summary.append("\n" + "-" * 70)
            summary.append("ISSUES BY STATUS")
            summary.append("-" * 70)
            for status, count in df['status'].value_counts().items():
                pct = (count / len(df)) * 100
                summary.append(f"  {status:<18} {count:>8,} ({pct:>5.1f}%)")

        # Top 10 Rules
        if 'rule' in df.columns:
            summary.append("\n" + "-" * 70)
            summary.append("TOP 10 RULES TRIGGERED")
            summary.append("-" * 70)
            for i, (rule, count) in enumerate(df['rule'].value_counts().head(10).items(), 1):
                summary.append(f"  {i:>2}. {rule[:50]:<50} {count:>6,}")

        # Date Range
        if 'creationDate' in df.columns and df['creationDate'].dropna().any():
            try:
                date_series = pd.to_datetime(df['creationDate'], errors='coerce').dropna()
                if not date_series.empty:
                    summary.append("\n" + "-" * 70)
                    summary.append("CREATION DATE RANGE")
                    summary.append("-" * 70)
                    summary.append(f"  Earliest: {date_series.min()}")
                    summary.append(f"  Latest:   {date_series.max()}")
            except Exception:
                pass

        summary.append("\n" + "=" * 70)
        report_text = '\n'.join(summary)
        print(f"\n{report_text}\n")

        with open(output_txt_file, 'w', encoding='utf-8') as f:
            f.write(report_text)
        logger.info(f"📄 Summary audit report saved to: {output_txt_file}")

    except Exception as e:
        logger.error(f"Could not generate summary report: {e}")


def get_last_export_info(project_key):
    """Retrieve metadata about the last export for incremental export mode (Priority 3.2)."""
    safe_key = project_key.replace(":", "-").replace("/", "-").replace("_", "-")
    filename = f'.last-export-{safe_key}.json'
    state_file = LOGS_DIR / filename
    if not state_file.is_file():
        # Fallback to check legacy or reports dir
        legacy_name = f'.last_export_{project_key.replace(":", "_").replace("/", "_")}.json'
        for candidate in [LOGS_DIR / legacy_name, REPORTS_DIR / filename, REPORTS_DIR / legacy_name]:
            if candidate.is_file():
                state_file = candidate
                break
    if state_file.is_file():
        try:
            with open(state_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return None
    return None


def save_export_info(project_key, end_date, issue_count):
    """Persist metadata for subsequent incremental exports (Priority 3.2)."""
    safe_key = project_key.replace(":", "-").replace("/", "-").replace("_", "-")
    state_file = LOGS_DIR / f'.last-export-{safe_key}.json'
    try:
        state = {
            'project_key': project_key,
            'last_export_date': end_date.strftime('%Y-%m-%d') if isinstance(end_date, datetime) else str(end_date),
            'last_export_timestamp': datetime.now().isoformat(),
            'issue_count': issue_count
        }
        with open(state_file, 'w', encoding='utf-8') as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        logger.warning(f"Could not save incremental export state: {e}")


def parse_arguments():
    """Parse and validate command line options."""
    parser = argparse.ArgumentParser(
        description='Export SonarQube issues to Excel (.xlsx) or CSV format according to sonar-audit-format.md.'
    )
    parser.add_argument(
        '--format', type=str, choices=['xlsx', 'csv'], default='xlsx',
        help='Output file format: xlsx (default) or csv'
    )
    parser.add_argument(
        '--output', '-o', type=str, default=None,
        help=f'Output filename or path (default: {DEFAULT_OUTPUT_XLSX})'
    )
    parser.add_argument(
        '--start-date', type=str, default=None,
        help='Start date for issue retrieval (YYYY-MM-DD). If omitted, exports all issues from project inception.'
    )
    parser.add_argument(
        '--end-date', type=str, default=None,
        help='End date for issue retrieval (YYYY-MM-DD), default: today'
    )
    parser.add_argument(
        '--statuses', type=str, default='OPEN,CONFIRMED,REOPENED',
        help='Filter by comma-separated statuses (default: "OPEN,CONFIRMED,REOPENED" to export all open issues).'
    )
    parser.add_argument(
        '--all-statuses', action='store_true', default=False,
        help='Include both open and resolved/closed issues (disables open-only filter).'
    )
    parser.add_argument(
        '--severities', type=str, default=None,
        help='Filter by comma-separated severities: BLOCKER,CRITICAL,MAJOR,MINOR,INFO'
    )
    parser.add_argument(
        '--types', type=str, default=None,
        help='Filter by comma-separated types: BUG,VULNERABILITY,CODE_SMELL,SECURITY_HOTSPOT'
    )
    parser.add_argument(
        '--chunk-size', type=int, default=5000,
        help='Chunk size for writing records to disk (default: 5000)'
    )
    parser.add_argument(
        '--page-size', type=int, default=500,
        help='API page size, max 500 (default: 500)'
    )
    parser.add_argument(
        '--summary', action='store_true', default=True,
        help='Generate an audit summary report after export (default: True)'
    )
    parser.add_argument(
        '--no-summary', dest='summary', action='store_false',
        help='Skip generating the summary report'
    )
    parser.add_argument(
        '--incremental', action='store_true', default=False,
        help='Only export new issues created since the last successful export'
    )
    parser.add_argument(
        '--keep-csv', action='store_true', default=False,
        help='Retain intermediate CSV file when format is xlsx'
    )
    return parser.parse_args()


def main():
    args = parse_arguments()

    # Read and normalize configuration parameters
    raw_url = os.getenv('SONAR_URL', '').strip()
    if not raw_url:
        raw_url = 'http://localhost:9000/api/issues/search'
    if not raw_url.endswith('/api/issues/search'):
        raw_url = raw_url.rstrip('/') + '/api/issues/search'

    sonar_url = raw_url
    project_key = os.getenv('SONAR_PROJECT_KEY', '').strip()
    token = os.getenv('SONAR_TOKEN', '').strip()

    # Credential validation with explicit actionable error message
    if not project_key or not token:
        logger.error("❌ Configuration error: SONAR_PROJECT_KEY and SONAR_TOKEN must be configured.")
        logger.error(f"Checked source: {BACKEND_ENV_PATH} and system environment variables.")
        logger.info("\nPlease update backend/.env:")
        logger.info("  SONAR_URL=https://sonarcloud.io")
        logger.info("  SONAR_PROJECT_KEY=your_project_key")
        logger.info("  SONAR_TOKEN=your_sonarqube_token")
        logger.info("\nOr export them directly in your shell:")
        logger.info("  export SONAR_URL='https://sonarcloud.io'")
        logger.info("  export SONAR_PROJECT_KEY='your_project_key'")
        logger.info("  export SONAR_TOKEN='your_sonarqube_token'")
        sys.exit(1)

    # Resolve output file path (strictly inside reports/sonarqube by default)
    if args.output:
        custom_path = Path(args.output)
        if custom_path.is_absolute() or len(custom_path.parts) > 1:
            target_output = custom_path
        else:
            target_output = REPORTS_DIR / custom_path.name
    else:
        target_output = DEFAULT_OUTPUT_XLSX if args.format == 'xlsx' else DEFAULT_OUTPUT_CSV

    expected_ext = f".{args.format}"
    if target_output.suffix.lower() != expected_ext:
        target_output = target_output.with_suffix(expected_ext)

    # Intermediate CSV path for chunked writing
    if args.format == 'xlsx':
        csv_file = target_output.with_suffix('.intermediate.csv')
        final_file = target_output
    else:
        csv_file = target_output
        final_file = target_output

    # Auth headers
    auth_header_val = base64.b64encode(f'{token}:'.encode()).decode()
    headers = {
        'Authorization': f'Basic {auth_header_val}',
        'Accept': 'application/json'
    }

    session = create_session_with_retries()

    # Determine status & resolution filters (Default: All open issues)
    base_params = {
        'componentKeys': project_key,
        'ps': min(args.page_size, 500)
    }

    if not args.all_statuses:
        base_params['resolved'] = 'false'
        if args.statuses:
            base_params['statuses'] = args.statuses
    elif args.statuses:
        base_params['statuses'] = args.statuses

    if args.severities:
        base_params['severities'] = args.severities
    if args.types:
        base_params['types'] = args.types

    # Incremental mode handling
    if args.incremental:
        last_info = get_last_export_info(project_key)
        if last_info and 'last_export_date' in last_info:
            args.start_date = last_info['last_export_date']
            logger.info(f"📅 Incremental mode active: fetching issues since {args.start_date}")

    # Check total matching issue count first to choose optimal retrieval strategy
    probe_params = dict(base_params)
    probe_params['ps'] = 1
    probe_params['p'] = 1
    if args.start_date:
        probe_params['createdAfter'] = args.start_date
    if args.end_date:
        probe_params['createdBefore'] = args.end_date

    try:
        probe_resp = session.get(sonar_url, headers=headers, params=probe_params, timeout=30)
        if probe_resp.status_code == 200:
            total_available = probe_resp.json().get('total', 0)
        else:
            if probe_resp.status_code == 401:
                logger.error("❌ Authentication failed (401). Please verify SONAR_TOKEN.")
            elif probe_resp.status_code == 403:
                logger.error("❌ Access denied (403). Check project permissions.")
            elif probe_resp.status_code == 404:
                logger.error(f"❌ Project '{project_key}' or endpoint not found (404).")
            else:
                logger.error(f"❌ Probe request failed: HTTP {probe_resp.status_code} - {probe_resp.text[:200]}")
            sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Failed to reach SonarQube API at {sonar_url}: {e}")
        sys.exit(1)

    logger.info("=" * 70)
    logger.info("🚀 Starting SonarQube Open Issues Export")
    logger.info(f"🎯 Target Project   : {project_key}")
    logger.info(f"🌐 SonarQube URL    : {sonar_url}")
    logger.info(f"📊 Open Issues Found: {total_available:,}")
    logger.info(f"📦 Output Target    : {final_file}")
    logger.info(f"⚙️ Output Format    : {args.format.upper()}")
    if base_params.get('resolved') == 'false':
        logger.info(f"🔓 Issues Scope     : ALL OPEN ISSUES (resolved=false, statuses={base_params.get('statuses', 'ALL')})")
    if args.severities:
        logger.info(f"🔍 Severities Filter: {args.severities}")
    if args.types:
        logger.info(f"🔍 Types Filter     : {args.types}")
    logger.info("=" * 70)

    all_issues = []
    chunk_size = args.chunk_size
    write_mode = 'w'
    total_issues_count = 0
    pbar = tqdm(total=total_available, desc="Exporting open issues", unit=" issues") if TQDM_AVAILABLE else None

    # STRATEGY 1: Direct Pagination (fastest & cleanest when total <= 10,000)
    # SonarQube pagination ceiling is 10,000 issues. If <= 10,000, we paginate directly.
    if total_available <= 10000 and not (args.start_date and args.end_date):
        current_page = 1
        page_size = base_params['ps']

        while True:
            params = dict(base_params)
            params['p'] = current_page
            if args.start_date:
                params['createdAfter'] = args.start_date
            if args.end_date:
                params['createdBefore'] = args.end_date

            try:
                resp = session.get(sonar_url, headers=headers, params=params, timeout=30)
                if resp.status_code != 200:
                    logger.error(f"❌ Failed to fetch page {current_page}: HTTP {resp.status_code}")
                    break

                data = resp.json()
                raw_issues = data.get('issues', [])
                if not raw_issues:
                    break

                flattened = [flatten_issue(issue) for issue in raw_issues]
                all_issues.extend(flattened)
                total_issues_count += len(flattened)

                if pbar:
                    pbar.update(len(flattened))
                else:
                    logger.info(f"   📄 Page {current_page}: {len(flattened)} issues ({total_issues_count}/{total_available})")

                if len(all_issues) >= chunk_size:
                    write_chunk_to_csv(csv_file, all_issues, mode=write_mode)
                    all_issues = []
                    write_mode = 'a'

                if len(raw_issues) < page_size or total_issues_count >= total_available:
                    break
                current_page += 1

            except Exception as e:
                logger.error(f"❌ Error fetching page {current_page}: {e}")
                break

    # STRATEGY 2: Date Window Chunking (for large datasets > 10,000 issues)
    else:
        start_date_str = args.start_date if args.start_date else '2000-01-01'
        end_date_str = args.end_date if args.end_date else datetime.now().strftime('%Y-%m-%d')
        start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
        end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
        delta = timedelta(days=30)
        current_start_date = start_date

        logger.info(f"📅 Using date chunking from {start_date_str} to {end_date_str}...")

        while current_start_date < end_date:
            current_end_date = current_start_date + delta
            if current_end_date > end_date:
                current_end_date = end_date

            params = dict(base_params)
            params['createdAfter'] = current_start_date.strftime('%Y-%m-%d')
            params['createdBefore'] = current_end_date.strftime('%Y-%m-%d')
            params['p'] = 1

            while True:
                try:
                    resp = session.get(sonar_url, headers=headers, params=params, timeout=30)
                    if resp.status_code != 200:
                        logger.error(f"❌ Failed chunk fetch: HTTP {resp.status_code}")
                        break

                    data = resp.json()
                    raw_issues = data.get('issues', [])
                    if raw_issues:
                        flattened = [flatten_issue(issue) for issue in raw_issues]
                        all_issues.extend(flattened)
                        total_issues_count += len(flattened)

                        if pbar:
                            pbar.update(len(flattened))

                    if len(all_issues) >= chunk_size:
                        write_chunk_to_csv(csv_file, all_issues, mode=write_mode)
                        all_issues = []
                        write_mode = 'a'

                    if len(raw_issues) < params['ps']:
                        break
                    params['p'] += 1

                except Exception as e:
                    logger.error(f"❌ Error during chunked fetch: {e}")
                    break

            current_start_date = current_end_date

    if pbar:
        pbar.close()

    # Flush any remaining buffer
    if all_issues:
        write_chunk_to_csv(csv_file, all_issues, mode=write_mode)
        all_issues = []

    # Final conversion and reporting
    if total_issues_count > 0:
        logger.info(f"\n🎉 Issue retrieval complete! Total open issues exported: {total_issues_count:,}")

        if args.format == 'xlsx':
            convert_csv_to_excel(csv_file, final_file, keep_csv=args.keep_csv)

        logger.info(f"✅ Final report ready at: {final_file}")

        # Summary Audit Report (Priority 2.5)
        if args.summary:
            summary_txt = LOGS_DIR / f'sonar-audit-summary-{datetime.now().strftime("%Y%m%d-%H%M%S")}.txt'
            generate_summary_report(final_file, summary_txt)

        # Persist incremental state
        save_export_info(project_key, datetime.now(), total_issues_count)

    else:
        logger.info("ℹ️ No open issues matched the specified filters.")
        empty_df = pd.DataFrame([flatten_issue({})]).iloc[0:0]
        if args.format == 'xlsx':
            empty_df.to_excel(final_file, index=False, engine='openpyxl')
        else:
            empty_df.to_csv(final_file, index=False, encoding='utf-8')
        logger.info(f"Created empty template file at: {final_file}")


if __name__ == '__main__':
    main()
