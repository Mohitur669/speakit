#!/usr/bin/env python3
"""
SonarQube Issues Export Tool
Exports SonarQube project issues to Excel (.xlsx) or CSV format with memory-efficient
chunking, retry logic, data flattening, logging, and summary reporting.

Follows the specifications defined in scripts/sonarqube/sonar-audit-format.md.
Credentials and configuration are loaded from backend/.env and environment variables.
Defaults to exporting ALL open issues to reports/sonarqube/sonarqube-issue.xlsx.
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

DEFAULT_OUTPUT_XLSX = REPORTS_DIR / 'sonarqube-issues.xlsx'
DEFAULT_OUTPUT_CSV = REPORTS_DIR / 'sonarqube-issues.csv'


def _parse_env_line(line: str):
    line = line.strip()
    if not line or line.startswith('#') or '=' not in line:
        return None, None
    key, val = line.split('=', 1)
    return key.strip(), val.strip().strip("'\"")


def _read_env_file(path: Path):
    if not path.is_file():
        return
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            key, val = _parse_env_line(line)
            if key and val and key not in os.environ:
                os.environ[key] = val


def load_env_variables():
    """Load environment variables from backend/.env and fallback files."""
    for p in [BACKEND_ENV_PATH, SCRIPT_DIR / '.env']:
        try:
            _read_env_file(p)
        except Exception:
            pass


load_env_variables()

# Configure logging
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
    """Create a requests Session with automatic retry strategy."""
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def flatten_issue(issue):
    """Extract and flatten useful fields from a SonarQube issue JSON."""
    text_range = issue.get('textRange', {})
    tags = issue.get('tags', [])
    tags_str = ', '.join(tags) if isinstance(tags, list) else str(tags or '')

    flows = issue.get('flows', [])
    flow_steps = sum(len(f.get('locations', [])) for f in flows if isinstance(f, dict))

    return {
        'key': issue.get('key'),
        'rule': issue.get('rule'),
        'severity': issue.get('severity'),
        'component': issue.get('component'),
        'componentLongName': issue.get('componentLongName', issue.get('component')),
        'project': issue.get('project'),
        'subProject': issue.get('subProject'),
        'line': issue.get('line') or text_range.get('startLine'),
        'hash': issue.get('hash'),
        'textRange': f"{text_range.get('startLine')}:{text_range.get('startOffset')}-{text_range.get('endLine')}:{text_range.get('endOffset')}" if text_range else None,
        'message': issue.get('message'),
        'author': issue.get('author'),
        'assignee': issue.get('assignee'),
        'status': issue.get('status'),
        'resolution': issue.get('resolution'),
        'type': issue.get('type'),
        'tags': tags_str,
        'creationDate': issue.get('creationDate'),
        'updateDate': issue.get('updateDate'),
        'closeDate': issue.get('closeDate'),
        'effort': issue.get('effort'),
        'debt': issue.get('debt'),
        'transitions': ', '.join(issue.get('transitions', [])) if issue.get('transitions') else None,
        'actions': ', '.join(issue.get('actions', [])) if issue.get('actions') else None,
        'comments': len(issue.get('comments', [])),
        'flows': flow_steps
    }


def write_chunk_to_csv(csv_file, issue_rows, mode='a'):
    """Append or write a chunk of issues to CSV."""
    if not issue_rows:
        return
    df_chunk = pd.DataFrame(issue_rows)
    header = (mode == 'w' or not os.path.exists(csv_file))
    df_chunk.to_csv(csv_file, mode=mode, header=header, index=False, encoding='utf-8')


def _read_csv_chunks(csv_file, chunk_size=50000):
    chunks = []
    for chunk in pd.read_csv(csv_file, chunksize=chunk_size, low_memory=False):
        chunks.append(chunk)
    return pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame()


def _cleanup_intermediate_csv(csv_file, xlsx_file, keep_csv):
    if keep_csv or not os.path.exists(csv_file) or str(csv_file) == str(xlsx_file):
        return
    try:
        os.remove(csv_file)
        logger.info(f"🗑️ Removed intermediate CSV file: {csv_file}")
    except OSError as err:
        logger.warning(f"Could not remove intermediate CSV: {err}")


def convert_csv_to_excel(csv_file, xlsx_file, keep_csv=False):
    """Convert CSV file to Excel format in chunks to avoid memory bottlenecks."""
    logger.info("🔄 Converting CSV to Excel format...")
    try:
        df = _read_csv_chunks(csv_file)
        df.to_excel(xlsx_file, index=False, engine='openpyxl')
        logger.info(f"✅ Excel file created: {xlsx_file}")
        _cleanup_intermediate_csv(csv_file, xlsx_file, keep_csv)
    except Exception as e:
        logger.error(f"⚠️ Warning: Could not convert to Excel: {e}")
        logger.info(f"💡 CSV file is still available at: {csv_file}")


def _load_data_file(data_file):
    if str(data_file).endswith('.csv'):
        return pd.read_csv(data_file, low_memory=False)
    return pd.read_excel(data_file, engine='openpyxl')


def _build_breakdown_section(df, column_name, title):
    if column_name not in df.columns:
        return []
    lines = ["\n" + "-" * 70, title, "-" * 70]
    for key, count in df[column_name].value_counts().items():
        pct = (count / len(df)) * 100
        lines.append(f"  {key:<18} {count:>8,} ({pct:>5.1f}%)")
    return lines


def _build_rules_section(df):
    if 'rule' not in df.columns:
        return []
    lines = ["\n" + "-" * 70, "TOP 10 RULES TRIGGERED", "-" * 70]
    for i, (rule, count) in enumerate(df['rule'].value_counts().head(10).items(), 1):
        lines.append(f"  {i:>2}. {rule[:50]:<50} {count:>6,}")
    return lines


def _build_dates_section(df):
    if 'creationDate' not in df.columns or not df['creationDate'].dropna().any():
        return []
    try:
        s = pd.to_datetime(df['creationDate'], errors='coerce').dropna()
        if not s.empty:
            return ["\n" + "-" * 70, "CREATION DATE RANGE", "-" * 70, f"  Earliest: {s.min()}", f"  Latest:   {s.max()}"]
    except Exception:
        pass
    return []


def generate_summary_report(data_file, output_txt_file):
    """Generate an executive summary report from exported issue data."""
    try:
        df = _load_data_file(data_file)
        if df.empty:
            logger.info("ℹ️ No data available for summary report.")
            return

        lines = [
            "=" * 70, "SONARQUBE EXPORT AUDIT SUMMARY REPORT", "=" * 70,
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Source File: {data_file}",
            f"Total Open Issues Exported: {len(df):,}"
        ]
        lines.extend(_build_breakdown_section(df, 'severity', 'ISSUES BY SEVERITY'))
        lines.extend(_build_breakdown_section(df, 'type', 'ISSUES BY TYPE'))
        lines.extend(_build_breakdown_section(df, 'status', 'ISSUES BY STATUS'))
        lines.extend(_build_rules_section(df))
        lines.extend(_build_dates_section(df))
        lines.append("\n" + "=" * 70)

        report_text = "\n".join(lines)
        print(f"\n{report_text}\n")
        with open(output_txt_file, 'w', encoding='utf-8') as f:
            f.write(report_text)
        logger.info(f"📄 Summary audit report saved to: {output_txt_file}")
    except Exception as e:
        logger.error(f"Could not generate summary report: {e}")


def get_last_export_info(project_key):
    """Retrieve metadata about the last export for incremental export mode."""
    safe_key = project_key.replace(":", "-").replace("/", "-").replace("_", "-")
    state_file = LOGS_DIR / f'.last-export-{safe_key}.json'
    if state_file.is_file():
        try:
            with open(state_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return None


def save_export_info(project_key, export_datetime, issue_count):
    """Persist export metadata to disk for future incremental runs."""
    safe_key = project_key.replace(":", "-").replace("/", "-").replace("_", "-")
    state_file = LOGS_DIR / f'.last-export-{safe_key}.json'
    try:
        data = {
            'project_key': project_key,
            'last_export_date': export_datetime.strftime('%Y-%m-%d'),
            'last_export_timestamp': export_datetime.isoformat(),
            'exported_issues_count': issue_count
        }
        with open(state_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.warning(f"Could not save incremental export info: {e}")


def parse_arguments():
    """Configure and parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Export SonarQube open issues to Excel or CSV.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('-p', '--project', default=os.getenv('SONAR_PROJECT_KEY'), help="SonarQube project key")
    parser.add_argument('-u', '--url', default=os.getenv('SONAR_URL', 'https://sonarcloud.io/api/issues/search'), help="SonarQube base search URL")
    parser.add_argument('-t', '--token', default=os.getenv('SONAR_TOKEN'), help="SonarQube User Token")
    parser.add_argument('-o', '--output', help="Output file path")
    parser.add_argument('-f', '--format', choices=['xlsx', 'csv'], default='xlsx', help="Export format")
    parser.add_argument('--statuses', default='OPEN,CONFIRMED,REOPENED', help="Comma-separated statuses")
    parser.add_argument('--all-statuses', action='store_true', help="Export all issues regardless of status")
    parser.add_argument('--severities', help="Filter by severity")
    parser.add_argument('--types', help="Filter by issue type")
    parser.add_argument('--start-date', help="Issues created on/after YYYY-MM-DD")
    parser.add_argument('--end-date', help="Issues created on/before YYYY-MM-DD")
    parser.add_argument('--incremental', action='store_true', help="Export only issues created since last export")
    parser.add_argument('--chunk-size', type=int, default=1000, help="Flush to disk every N issues")
    parser.add_argument('--page-size', type=int, default=500, help="SonarQube API page size")
    parser.add_argument('--summary', action='store_true', default=True, help="Generate summary audit report")
    parser.add_argument('--no-summary', dest='summary', action='store_false', help="Skip summary audit report")
    parser.add_argument('--keep-csv', action='store_true', help="Keep intermediate CSV when exporting to Excel")
    return parser.parse_args()


def _resolve_paths(args):
    if args.output:
        p = Path(args.output)
        target = p if (p.is_absolute() or len(p.parts) > 1) else (REPORTS_DIR / p.name)
    else:
        target = DEFAULT_OUTPUT_XLSX if args.format == 'xlsx' else DEFAULT_OUTPUT_CSV

    target = target.with_suffix(f".{args.format}")
    csv_file = target.with_suffix('.intermediate.csv') if args.format == 'xlsx' else target
    return target, csv_file


def _build_params(project_key, args):
    params = {'componentKeys': project_key, 'ps': min(args.page_size, 500)}
    if not args.all_statuses:
        params['resolved'] = 'false'
    if args.statuses:
        params['statuses'] = args.statuses
    if args.severities:
        params['severities'] = args.severities
    if args.types:
        params['types'] = args.types
    return params


def _probe_total_count(session, sonar_url, headers, base_params, args, project_key):
    probe_params = dict(base_params)
    probe_params['ps'] = 1
    probe_params['p'] = 1
    if args.start_date:
        probe_params['createdAfter'] = args.start_date
    if args.end_date:
        probe_params['createdBefore'] = args.end_date

    try:
        resp = session.get(sonar_url, headers=headers, params=probe_params, timeout=30)  # NOSONAR
        if resp.status_code == 200:
            return resp.json().get('total', 0)
        logger.error(f"❌ Probe request failed: HTTP {resp.status_code}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Failed to reach SonarQube API at {sonar_url}: {e}")
        sys.exit(1)


def _paginate_direct(session, sonar_url, headers, base_params, args, total_available, csv_file, pbar):
    page, total_count, buffer, mode = 1, 0, [], 'w'
    while True:
        p = dict(base_params)
        p['p'] = page
        if args.start_date:
            p['createdAfter'] = args.start_date
        if args.end_date:
            p['createdBefore'] = args.end_date

        try:
            resp = session.get(sonar_url, headers=headers, params=p, timeout=30)  # NOSONAR
            if resp.status_code != 200:
                break
            raw_issues = resp.json().get('issues', [])
            if not raw_issues:
                break

            items = [flatten_issue(i) for i in raw_issues]
            buffer.extend(items)
            total_count += len(items)

            if pbar:
                pbar.update(len(items))
            if len(buffer) >= args.chunk_size:
                write_chunk_to_csv(csv_file, buffer, mode=mode)
                buffer, mode = [], 'a'
            if len(raw_issues) < base_params['ps'] or total_count >= total_available:
                break
            page += 1
        except Exception:
            break

    if buffer:
        write_chunk_to_csv(csv_file, buffer, mode=mode)
    return total_count


def _paginate_by_date(session, sonar_url, headers, base_params, args, csv_file, pbar):
    start_dt = datetime.strptime(args.start_date or '2000-01-01', '%Y-%m-%d')
    end_dt = datetime.strptime(args.end_date or datetime.now().strftime('%Y-%m-%d'), '%Y-%m-%d')
    delta = timedelta(days=30)
    curr_start, total_count, buffer, mode = start_dt, 0, [], 'w'

    while curr_start < end_dt:
        curr_end = min(curr_start + delta, end_dt)
        p = dict(base_params)
        p['createdAfter'] = curr_start.strftime('%Y-%m-%d')
        p['createdBefore'] = curr_end.strftime('%Y-%m-%d')
        p['p'] = 1

        while True:
            try:
                resp = session.get(sonar_url, headers=headers, params=p, timeout=30)  # NOSONAR
                if resp.status_code != 200:
                    break
                raw = resp.json().get('issues', [])
                if raw:
                    items = [flatten_issue(i) for i in raw]
                    buffer.extend(items)
                    total_count += len(items)
                    if pbar:
                        pbar.update(len(items))

                if len(buffer) >= args.chunk_size:
                    write_chunk_to_csv(csv_file, buffer, mode=mode)
                    buffer, mode = [], 'a'
                if len(raw) < p['ps']:
                    break
                p['p'] += 1
            except Exception:
                break
        curr_start = curr_end

    if buffer:
        write_chunk_to_csv(csv_file, buffer, mode=mode)
    return total_count


def _finalize_export(csv_file, final_file, args, project_key, total_count):
    if total_count > 0:
        logger.info(f"\n🎉 Issue retrieval complete! Total open issues exported: {total_count:,}")
        if args.format == 'xlsx':
            convert_csv_to_excel(csv_file, final_file, keep_csv=args.keep_csv)
        logger.info(f"✅ Final report ready at: {final_file}")

        if args.summary:
            summary_txt = LOGS_DIR / f'sonar-audit-summary-{datetime.now().strftime("%Y%m%d-%H%M%S")}.txt'
            generate_summary_report(final_file, summary_txt)
        save_export_info(project_key, datetime.now(), total_count)
    else:
        logger.info("ℹ️ No open issues matched the specified filters.")
        empty_df = pd.DataFrame([flatten_issue({})]).iloc[0:0]
        if args.format == 'xlsx':
            empty_df.to_excel(final_file, index=False, engine='openpyxl')
        else:
            empty_df.to_csv(final_file, index=False, encoding='utf-8')


def _apply_incremental(project_key, args):
    if args.incremental:
        last_info = get_last_export_info(project_key)
        if last_info and 'last_export_date' in last_info:
            args.start_date = last_info['last_export_date']


def _run_pagination(session, sonar_url, headers, base_params, args, total_available, csv_file, pbar):
    if total_available <= 10000 and not (args.start_date and args.end_date):
        return _paginate_direct(session, sonar_url, headers, base_params, args, total_available, csv_file, pbar)
    return _paginate_by_date(session, sonar_url, headers, base_params, args, csv_file, pbar)


def main():
    args = parse_arguments()
    project_key, sonar_url, token = args.project, args.url, args.token

    if not project_key or not token:
        logger.error("❌ Missing required configuration: SONAR_PROJECT_KEY or SONAR_TOKEN")
        sys.exit(1)

    final_file, csv_file = _resolve_paths(args)
    headers = {
        'Authorization': f'Basic {base64.b64encode(f"{token}:".encode()).decode()}',
        'Accept': 'application/json'
    }
    session = create_session_with_retries()
    base_params = _build_params(project_key, args)
    _apply_incremental(project_key, args)

    total_available = _probe_total_count(session, sonar_url, headers, base_params, args, project_key)

    logger.info("=" * 70)
    logger.info(f"🚀 Starting SonarQube Open Issues Export: {project_key} ({total_available:,} issues)")
    logger.info("=" * 70)

    pbar = tqdm(total=total_available, desc="Exporting open issues", unit=" issues") if TQDM_AVAILABLE else None
    total_count = _run_pagination(session, sonar_url, headers, base_params, args, total_available, csv_file, pbar)

    if pbar:
        pbar.close()

    _finalize_export(csv_file, final_file, args, project_key, total_count)


if __name__ == '__main__':
    main()
