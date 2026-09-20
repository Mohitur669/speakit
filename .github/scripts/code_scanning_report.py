#!/usr/bin/env python3
# Destination: .github/scripts/code_scanning_report.py
"""
GitHub Code Scanning (CodeQL) alert report generator.

Pulls every Code Scanning alert for a repository through the REST API and emits:

  <out>/alerts.json                  full, unmodified API payload
  <out>/agent-queue.json             severity-ordered work queue for the local agent
  <out>/agent/alert-<n>-<slug>.md    one self-contained fix brief per alert
  <out>/report.md                    human-readable report with code context
  <out>/report.html                  styled report (GitHub-like)
  <out>/report.pdf                   print rendering of report.html
  <out>/summary.md                   short digest for $GITHUB_STEP_SUMMARY
  reports/alerts/code-scanning-alerts.csv  CSV report with summary metrics
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path

import requests

API_ROOT = os.environ.get("GITHUB_API_URL", "https://api.github.com")

SEVERITY_ORDER = {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 3,
    "warning": 2,
    "error": 1,
    "note": 3,
}

SEVERITY_COLOR = {
    "critical": "#82071e",
    "high": "#bc4c00",
    "medium": "#9a6700",
    "low": "#57606a",
}


def normalize_severity(alert: dict) -> str:
    rule = alert.get("rule", {}) or {}
    sec_level = rule.get("security_severity_level")
    if sec_level:
        return sec_level.lower()
    sev = rule.get("severity") or alert.get("severity") or "low"
    sev = sev.lower()
    if sev == "error":
        return "high"
    if sev == "warning":
        return "medium"
    if sev == "note":
        return "low"
    return sev if sev in SEVERITY_ORDER else "low"


def sev_rank(alert: dict) -> int:
    return SEVERITY_ORDER.get(alert["severity"], 9)


def fetch_alerts(session: requests.Session, repo: str, state: str) -> list[dict]:
    url = f"{API_ROOT}/repos/{repo}/code-scanning/alerts"
    params = {"per_page": 100, "sort": "created", "direction": "desc"}
    if state != "all":
        params["state"] = state

    alerts: list[dict] = []
    while url:
        resp = session.get(url, params=params, timeout=45)
        params = None  # subsequent pages carry their own query string
        if resp.status_code == 403:
            sys.exit(
                "403 from the Code Scanning alerts API.\n"
                "The token needs `security_events: read` scope or fine-grained PAT with\n"
                "`Code scanning alerts: Read-only` permissions.\n"
                f"Response: {resp.text[:400]}"
            )
        if resp.status_code == 404:
            sys.exit(f"404 for {repo}. Either the repo path is wrong or Code Scanning is disabled.")
        resp.raise_for_status()
        page = resp.json()
        alerts.extend(page)
        url = resp.links.get("next", {}).get("url")
    return alerts


def extract_cwes(tags: list[str]) -> list[str]:
    cwes = []
    for tag in tags:
        m = re.search(r"cwe[-/](cwe-\d+)", tag, re.IGNORECASE)
        if m:
            cwes.append(m.group(1).upper())
    return sorted(set(cwes))


def normalise(alert: dict) -> dict:
    rule = alert.get("rule") or {}
    inst = alert.get("most_recent_instance") or {}
    loc = inst.get("location") or {}
    tags = rule.get("tags") or []
    cwes = extract_cwes(tags)
    tool = alert.get("tool") or {}

    return {
        "number": alert.get("number"),
        "state": alert.get("state") or "open",
        "html_url": alert.get("html_url"),
        "created_at": alert.get("created_at"),
        "updated_at": alert.get("updated_at"),
        "fixed_at": alert.get("fixed_at"),
        "dismissed_at": alert.get("dismissed_at"),
        "dismissed_reason": alert.get("dismissed_reason"),
        "dismissed_comment": alert.get("dismissed_comment"),
        "tool_name": tool.get("name") or "CodeQL",
        "tool_version": tool.get("version") or "",
        "rule_id": rule.get("id") or "unknown",
        "rule_name": rule.get("name") or rule.get("id") or "Code Scanning Alert",
        "rule_description": rule.get("description") or "",
        "rule_full_description": rule.get("full_description") or "",
        "rule_help": rule.get("help") or "",
        "severity": normalize_severity(alert),
        "tags": tags,
        "cwes": cwes,
        "path": loc.get("path") or "",
        "start_line": loc.get("start_line"),
        "end_line": loc.get("end_line"),
        "start_column": loc.get("start_column"),
        "end_column": loc.get("end_column"),
        "message": (inst.get("message") or {}).get("text") or "",
        "commit_sha": inst.get("commit_sha") or "",
        "ref": inst.get("ref") or "",
        "category": inst.get("category") or "",
    }


def get_code_snippet(path_str: str, start_line: int | None, end_line: int | None, context: int = 3) -> str | None:
    if not path_str or start_line is None:
        return None
    p = Path(path_str)
    if not p.is_file():
        return None

    try:
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        total = len(lines)
        s = max(1, start_line - context)
        e = min(total, (end_line or start_line) + context)

        snippet_lines = []
        for line_no in range(s, e + 1):
            marker = ">" if (line_no >= start_line and line_no <= (end_line or start_line)) else " "
            snippet_lines.append(f"{marker} {line_no:4d} | {lines[line_no - 1]}")
        return "\n".join(snippet_lines)
    except Exception:
        return None


def md_to_html(text: str) -> str:
    try:
        import markdown as md_lib

        return md_lib.markdown(
            text,
            extensions=["fenced_code", "tables", "sane_lists", "nl2br", "attr_list"],
        )
    except ImportError:
        return f"<pre>{escape(text)}</pre>"


def fmt_date(value: str | None) -> str:
    if not value:
        return "—"
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M UTC")
    except ValueError:
        return value


CSS = """
@page { size: A4; margin: 16mm 14mm 18mm 14mm;
        @bottom-center { content: counter(page) " / " counter(pages); font-size: 9pt; color: #57606a; } }
body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; font-size: 10.5pt;
       line-height: 1.55; color: #1f2328; }
h1 { font-size: 20pt; border-bottom: 2px solid #d1d9e0; padding-bottom: 6px; }
h2 { font-size: 15pt; border-bottom: 1px solid #d1d9e0; padding-bottom: 4px; margin-top: 26px; }
h3 { font-size: 12.5pt; margin-top: 20px; page-break-after: avoid; }
h4 { font-size: 11pt; margin-top: 14px; page-break-after: avoid; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; font-size: 9.5pt; }
th, td { border: 1px solid #d1d9e0; padding: 5px 8px; text-align: left; vertical-align: top;
         word-break: break-word; }
th { background: #f6f8fa; font-weight: 600; }
code { background: #f6f8fa; border-radius: 4px; padding: 1px 4px; font-size: 9pt;
       font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; word-break: break-all; }
pre { background: #f6f8fa; border: 1px solid #d1d9e0; border-radius: 6px; padding: 10px;
      font-size: 8.5pt; white-space: pre-wrap; word-break: break-word; page-break-inside: avoid; }
pre code { background: none; padding: 0; }
a { color: #0969da; text-decoration: none; word-break: break-all; }
hr { border: 0; border-top: 1px solid #d1d9e0; margin: 22px 0; }
.badge { color: #fff; border-radius: 999px; padding: 1px 8px; font-size: 8.5pt; font-weight: 600; }
.meta { color: #57606a; font-size: 9.5pt; }
blockquote { border-left: 3px solid #d1d9e0; margin: 8px 0; padding-left: 10px; color: #57606a; }
"""


def build_html(repo: str, body_md: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Code Scanning (CodeQL) security report — {escape(repo)}</title>
<style>{CSS}</style></head>
<body>{md_to_html(body_md)}</body></html>"""


def write_pdf(html: str, path: Path) -> bool:
    try:
        from weasyprint import HTML  # type: ignore

        HTML(string=html, base_url=".").write_pdf(str(path))
        return True
    except Exception as exc:
        print(f"PDF rendering skipped: {exc}", file=sys.stderr)
        return False


def alert_detail_md(a: dict) -> str:
    lines = [
        f"### {a['rule_description'] or a['rule_name']} (#{a['number']})",
        "",
        f"**{a['state'].title()}** • Rule: `{a['rule_id']}` • Tool: **{a['tool_name']} {a['tool_version']}**",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Severity | {a['severity'].upper()} |",
        f"| File | `{a['path']}` |",
        f"| Line | {a['start_line'] or '—'} |",
        f"| Weaknesses (CWE) | {', '.join(a['cwes']) if a['cwes'] else '—'} |",
        f"| Message | {a['message']} |",
        f"| Alert opened | {fmt_date(a['created_at'])} |",
        f"| Alert URL | {a['html_url']} |",
    ]
    if a["dismissed_at"]:
        lines.append(f"| Dismissed | {fmt_date(a['dismissed_at'])} — {a['dismissed_reason']} {a['dismissed_comment'] or ''} |")
    if a["fixed_at"]:
        lines.append(f"| Fixed | {fmt_date(a['fixed_at'])} |")

    lines.append("")
    if a["rule_full_description"] and a["rule_full_description"] != a["rule_description"]:
        lines += [f"**Description**: {a['rule_full_description']}", ""]

    # Include code snippet if available
    snippet = get_code_snippet(a["path"], a["start_line"], a["end_line"])
    if snippet:
        lines += [
            "#### Code snippet",
            "```",
            snippet,
            "```",
            "",
        ]

    # Include rule help (recommendation / examples / references)
    if a["rule_help"]:
        lines += [
            "#### Recommendation & Explanation",
            "",
            a["rule_help"],
            "",
        ]

    return "\n".join(lines)


def build_markdown(repo: str, alerts: list[dict], state: str) -> str:
    counts = {s: sum(1 for a in alerts if a["severity"] == s) for s in ("critical", "high", "medium", "low")}
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    out = [
        f"# Code Scanning (CodeQL) security report — {repo}",
        "",
        f"Generated {generated} • state filter: `{state}` • {len(alerts)} alert(s)",
        "",
        "| Critical | High | Medium | Low |",
        "| --- | --- | --- | --- |",
        f"| {counts['critical']} | {counts['high']} | {counts['medium']} | {counts['low']} |",
        "",
        "## Summary of Findings",
        "",
        "| # | Severity | Rule | Message | Location |",
        "| --- | --- | --- | --- | --- |",
    ]

    for a in alerts:
        loc = f"`{a['path']}:{a['start_line']}`" if a["path"] and a["start_line"] else "`—`"
        out.append(
            f"| [#{a['number']}]({a['html_url']}) | {a['severity'].upper()} | `{a['rule_id']}` | "
            f"{a['rule_description'] or a['message']} | {loc} |"
        )

    out += ["", "---", "", "## Alert Details", ""]
    for a in alerts:
        out.append(alert_detail_md(a))
        out.append("---")
        out.append("")

    return "\n".join(out)


def agent_brief(a: dict, repo: str) -> str:
    snippet = get_code_snippet(a["path"], a["start_line"], a["end_line"])
    snippet_block = f"```\n{snippet}\n```" if snippet else "_Code snippet unavailable or file not found locally._"

    return f"""# Fix task — Code Scanning alert #{a['number']}: {a['rule_description'] or a['rule_name']}

Repository: `{repo}`
Alert URL: {a['html_url']}
Rule: `{a['rule_id']}`
Severity: {a['severity'].upper()}
CWEs: {', '.join(a['cwes']) if a['cwes'] else 'none'}

## Target Location
- File: `{a['path']}`
- Line: {a['start_line']} to {a['end_line']} (Column {a['start_column']} to {a['end_column']})
- Finding: {a['message']}

## Vulnerable Code
{snippet_block}

## Remediation Guidelines & CodeQL Help
{a['rule_help'] or a['rule_full_description'] or 'No additional help provided.'}

## Constraints
- Modify only the vulnerable code and direct dependencies necessary to mitigate this finding.
- Do not make stylistic or sweeping changes unrelated to this alert.
- Ensure the project builds and all existing tests pass after the fix.
"""


def export_csv(alerts: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    closed_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0}

    with open(path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Alert_ID", "Rule_ID", "Severity", "State", "Path", "Start_Line", "End_Line", "Message", "Raised_Time", "Closed_Time", "Alert_URL"])

        for a in alerts:
            alert_id = a["number"]
            rule_id = a["rule_id"]
            sev = a["severity"]
            state = a["state"]
            file_path = a["path"]
            start_line = a["start_line"] or ""
            end_line = a["end_line"] or ""
            msg = a["message"]
            raised = a["created_at"] or ""
            closed = a["fixed_at"] or a["dismissed_at"] or "Still Open"
            url = a["html_url"]

            writer.writerow([alert_id, rule_id, sev, state, file_path, start_line, end_line, msg, raised, closed, url])

            if state in ["fixed", "dismissed"]:
                closed_counts[sev] = closed_counts.get(sev, 0) + 1

        writer.writerow([])
        writer.writerow([])
        writer.writerow(["--- SUMMARY: CLOSED ALERTS BY SEVERITY ---", "", "", "", "", "", "", "", "", "", ""])
        writer.writerow(["Severity", "Total Closed", "", "", "", "", "", "", "", "", ""])
        for sev in ["critical", "high", "medium", "low"]:
            writer.writerow([sev.capitalize(), closed_counts.get(sev, 0), "", "", "", "", "", "", "", "", ""])


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate a Code Scanning (CodeQL) alert report.")
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"), help="owner/name")
    ap.add_argument("--state", default="open", choices=["open", "closed", "dismissed", "fixed", "all"])
    ap.add_argument("--min-severity", default="low", choices=["low", "medium", "high", "critical"])
    ap.add_argument("--out", default="reports/code-scanning")
    ap.add_argument("--no-pdf", action="store_true")
    ap.add_argument("--fail-on", default=None, choices=["low", "medium", "high", "critical"])
    args = ap.parse_args()

    if not args.repo:
        sys.exit("--repo owner/name is required (or set GITHUB_REPOSITORY)")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        sys.exit("Set GITHUB_TOKEN to a token that can read Code Scanning alerts.")

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "code-scanning-report-generator",
        }
    )

    raw = fetch_alerts(session, args.repo, args.state)
    cutoff = SEVERITY_ORDER[args.min_severity]
    alerts = [a for a in (normalise(x) for x in raw) if sev_rank(a) <= cutoff]
    alerts.sort(key=lambda a: (sev_rank(a), a["number"]))

    out = Path(args.out)
    (out / "agent").mkdir(parents=True, exist_ok=True)

    (out / "alerts.json").write_text(json.dumps(raw, indent=2), encoding="utf-8")

    queue = [
        {
            "order": i,
            "alert_number": a["number"],
            "severity": a["severity"],
            "rule_id": a["rule_id"],
            "path": a["path"],
            "start_line": a["start_line"],
            "end_line": a["end_line"],
            "message": a["message"],
            "cwes": a["cwes"],
            "brief": f"agent/alert-{a['number']}-{re.sub(r'[^A-Za-z0-9._-]', '_', a['rule_id'])}.md",
            "alert_url": a["html_url"],
        }
        for i, a in enumerate(alerts, 1)
    ]
    (out / "agent-queue.json").write_text(json.dumps(queue, indent=2), encoding="utf-8")

    for a in alerts:
        slug = re.sub(r"[^A-Za-z0-9._-]", "_", a["rule_id"])
        (out / "agent" / f"alert-{a['number']}-{slug}.md").write_text(
            agent_brief(a, args.repo), encoding="utf-8"
        )

    body_md = build_markdown(args.repo, alerts, args.state)
    (out / "report.md").write_text(body_md, encoding="utf-8")

    html = build_html(args.repo, body_md)
    (out / "report.html").write_text(html, encoding="utf-8")
    if not args.no_pdf:
        write_pdf(html, out / "report.pdf")

    counts = {s: sum(1 for a in alerts if a["severity"] == s) for s in ("critical", "high", "medium", "low")}
    summary = [
        f"## Code Scanning (CodeQL) report — {args.repo}",
        "",
        f"{len(alerts)} alert(s) • critical {counts['critical']} · high {counts['high']} · "
        f"medium {counts['medium']} · low {counts['low']}",
        "",
        "| # | Severity | Rule | Location | Finding |",
        "| --- | --- | --- | --- | --- |",
    ]
    for a in alerts:
        loc = f"`{a['path']}:{a['start_line']}`" if a["path"] and a["start_line"] else "`—`"
        summary.append(
            f"| [#{a['number']}]({a['html_url']}) | {a['severity'].upper()} | `{a['rule_id']}` | "
            f"{loc} | {a['rule_description'] or a['message']} |"
        )
    (out / "summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")

    # Export CSV to reports/alerts/code-scanning-alerts.csv as well
    export_csv(alerts, Path("reports/alerts/code-scanning-alerts.csv"))

    print(f"{len(alerts)} Code Scanning alert(s) written to {out}/ and reports/alerts/code-scanning-alerts.csv")
    for a in alerts:
        print(f"  {a['severity'].upper():8} #{a['number']} {a['rule_id']} in {a['path']}:{a['start_line']}")

    if args.fail_on:
        threshold = SEVERITY_ORDER[args.fail_on]
        breaching = [a for a in alerts if sev_rank(a) <= threshold]
        if breaching:
            print(f"::error::{len(breaching)} alert(s) at or above {args.fail_on}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
