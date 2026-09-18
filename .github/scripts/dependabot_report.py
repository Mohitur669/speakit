#!/usr/bin/env python3
# Destination: .github/scripts/dependabot_report.py
"""
Dependabot alert report generator.

Pulls every Dependabot alert for a repository through the REST API and emits:

  <out>/alerts.json                  full, unmodified API payload (agent ground truth)
  <out>/agent-queue.json             severity-ordered work queue for the local agent
  <out>/agent/alert-<n>-<pkg>.md     one self-contained fix brief per alert
  <out>/report.md                    human-readable report
  <out>/report.html                  styled report (GitHub-like)
  <out>/report.pdf                   print rendering of report.html
  <out>/summary.md                   short digest for $GITHUB_STEP_SUMMARY

Every field the GitHub security UI shows is carried through: severity, CVSS v3/v4
vectors, EPSS, CWEs, identifiers (GHSA/CVE), affected version ranges, first patched
version, manifest path, dependency scope, the full advisory body (Summary / Impact /
Details / PoC, including its images), references and the alert timeline.

Usage:
    GITHUB_TOKEN=... python dependabot_report.py --repo Mohitur669/speakit

    --state       open (default) | fixed | dismissed | auto_dismissed | all
    --min-severity  low (default) | medium | high | critical
    --out         output directory (default: reports/dependabot)
    --no-pdf      skip PDF rendering
    --fail-on     exit 1 if any alert at/above this severity survives filtering
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path
from urllib.parse import urlparse

import requests

API_ROOT = os.environ.get("GITHUB_API_URL", "https://api.github.com")
SEVERITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "moderate": 2, "low": 3}
SEVERITY_COLOR = {
    "critical": "#82071e",
    "high": "#bc4c00",
    "medium": "#9a6700",
    "moderate": "#9a6700",
    "low": "#57606a",
}

# Hosts we will try to inline into the PDF. GitHub's private-user-images links are
# signed with a short-lived JWT, so they are attempted but expected to fail once the
# signature has expired; the report then keeps the original URL as a labelled link.
IMAGE_HOSTS = {
    "user-images.githubusercontent.com",
    "private-user-images.githubusercontent.com",
    "raw.githubusercontent.com",
    "github.com",
    "camo.githubusercontent.com",
}

UPGRADE_HINTS = {
    "npm": {
        "direct": 'npm install {name}@^{version}',
        "transitive": (
            "Transitive dependency — bump the parent package, or pin it:\n"
            '  package.json  "overrides": {{ "{name}": "^{version}" }}      (npm)\n'
            '  package.json  "resolutions": {{ "{name}": "^{version}" }}    (yarn / pnpm)\n'
            "then re-lock with `npm install` / `pnpm install`."
        ),
    },
    "maven": {
        "direct": "Set <version>{version}</version> for {name} in pom.xml",
        "transitive": (
            "Transitive dependency — pin via <dependencyManagement> in the parent pom, "
            "or bump the BOM/starter that pulls in {name}. Verify with "
            "`mvn dependency:tree -Dincludes={name}`."
        ),
    },
    "pip": {
        "direct": "{name}>={version}   # requirements.txt / pyproject.toml",
        "transitive": "Transitive dependency — bump the parent, or add an explicit `{name}>={version}` pin.",
    },
    "gradle": {
        "direct": "implementation '{name}:{version}'",
        "transitive": "Transitive dependency — use a resolutionStrategy force or a platform() constraint for {name}:{version}.",
    },
    "nuget": {"direct": "dotnet add package {name} --version {version}", "transitive": "Add an explicit top-level reference to {name} {version}."},
    "composer": {"direct": "composer require {name}:^{version}", "transitive": "Bump the parent package or add {name}:^{version} explicitly."},
    "rubygems": {"direct": "gem '{name}', '>= {version}'", "transitive": "Bump the parent gem or add an explicit constraint for {name}."},
    "go": {"direct": "go get {name}@v{version}", "transitive": "go get {name}@v{version}  # adds an explicit require/replace"},
    "rust": {"direct": "cargo update -p {name} --precise {version}", "transitive": "cargo update -p {name} --precise {version}"},
    "actions": {"direct": "Pin the action to {version} (or its commit SHA) in the workflow file.", "transitive": "Pin the action to {version} in the workflow file."},
}


# --------------------------------------------------------------------------- fetch


def fetch_alerts(session: requests.Session, repo: str, state: str) -> list[dict]:
    url = f"{API_ROOT}/repos/{repo}/dependabot/alerts"
    params = {"per_page": 100, "sort": "created", "direction": "desc"}
    if state != "all":
        params["state"] = state

    alerts: list[dict] = []
    while url:
        resp = session.get(url, params=params, timeout=45)
        params = None  # subsequent pages carry their own query string
        if resp.status_code == 403:
            sys.exit(
                "403 from the Dependabot alerts API.\n"
                "The token needs `vulnerability-alerts: read` (GITHUB_TOKEN) or a PAT with\n"
                "the `security_events` scope / fine-grained `Dependabot alerts: read`.\n"
                f"Response: {resp.text[:400]}"
            )
        if resp.status_code == 404:
            sys.exit(f"404 for {repo}. Either the repo path is wrong or Dependabot alerts are disabled.")
        resp.raise_for_status()
        page = resp.json()
        alerts.extend(page)
        url = resp.links.get("next", {}).get("url")
    return alerts


# ---------------------------------------------------------------------- normalise


def version_key(version: str | None) -> tuple:
    """Rough semver ordering, good enough to pick the highest patched version."""
    if not version:
        return ((-1, 0),)
    parts = re.split(r"[.\-+]", str(version))
    key: list = []
    for part in parts:
        key.append((0, int(part)) if part.isdigit() else (1, part))
    return tuple(key)


def normalise(alert: dict) -> dict:
    adv = alert.get("security_advisory") or {}
    vuln = alert.get("security_vulnerability") or {}
    dep = alert.get("dependency") or {}
    pkg = vuln.get("package") or dep.get("package") or {}
    cvss = adv.get("cvss") or {}
    sev_map = adv.get("cvss_severities") or {}
    v4 = sev_map.get("cvss_v4") or {}
    v3 = sev_map.get("cvss_v3") or {}
    epss = adv.get("epss") or {}
    patched = (vuln.get("first_patched_version") or {}).get("identifier")

    ids = adv.get("identifiers") or []
    cve = next((i["value"] for i in ids if i.get("type") == "CVE"), adv.get("cve_id"))

    return {
        "number": alert.get("number"),
        "state": alert.get("state"),
        "html_url": alert.get("html_url"),
        "package": pkg.get("name"),
        "ecosystem": (pkg.get("ecosystem") or "").lower(),
        "manifest": dep.get("manifest_path"),
        "scope": dep.get("scope"),
        "relationship": dep.get("relationship"),
        "severity": (vuln.get("severity") or adv.get("severity") or "low").lower(),
        "summary": adv.get("summary") or "(no summary)",
        "description": adv.get("description") or "",
        "ghsa_id": adv.get("ghsa_id"),
        "cve_id": cve,
        "identifiers": ids,
        "vulnerable_range": vuln.get("vulnerable_version_range"),
        "first_patched": patched,
        "cvss_score": v4.get("score") or cvss.get("score"),
        "cvss_vector": v4.get("vector_string") or cvss.get("vector_string"),
        "cvss_v3_score": v3.get("score"),
        "cvss_v3_vector": v3.get("vector_string"),
        "epss_percentage": epss.get("percentage"),
        "epss_percentile": epss.get("percentile"),
        "cwes": adv.get("cwes") or [],
        "references": [r.get("url") for r in (adv.get("references") or []) if r.get("url")],
        "published_at": adv.get("published_at"),
        "advisory_updated_at": adv.get("updated_at"),
        "withdrawn_at": adv.get("withdrawn_at"),
        "created_at": alert.get("created_at"),
        "updated_at": alert.get("updated_at"),
        "fixed_at": alert.get("fixed_at"),
        "dismissed_at": alert.get("dismissed_at"),
        "dismissed_reason": alert.get("dismissed_reason"),
        "dismissed_comment": alert.get("dismissed_comment"),
        "auto_dismissed_at": alert.get("auto_dismissed_at"),
        "all_affected_ranges": [
            {
                "package": (v.get("package") or {}).get("name"),
                "severity": v.get("severity"),
                "vulnerable_version_range": v.get("vulnerable_version_range"),
                "first_patched_version": (v.get("first_patched_version") or {}).get("identifier"),
            }
            for v in (adv.get("vulnerabilities") or [])
        ],
    }


def sev_rank(alert: dict) -> int:
    return SEVERITY_ORDER.get(alert["severity"], 9)


def group_upgrades(alerts: list[dict]) -> list[dict]:
    """Reproduce the UI's 'Upgrade X to fix N alerts' block, per package + manifest."""
    groups: dict[tuple, dict] = {}
    for a in alerts:
        key = (a["ecosystem"], a["package"], a["manifest"])
        g = groups.setdefault(
            key,
            {
                "ecosystem": a["ecosystem"],
                "package": a["package"],
                "manifest": a["manifest"],
                "alerts": [],
                "target_version": None,
                "worst_severity": "low",
            },
        )
        g["alerts"].append(a)
        if a["first_patched"] and version_key(a["first_patched"]) > version_key(g["target_version"]):
            g["target_version"] = a["first_patched"]
        if sev_rank(a) < SEVERITY_ORDER.get(g["worst_severity"], 9):
            g["worst_severity"] = a["severity"]
    ordered = sorted(
        groups.values(),
        key=lambda g: (SEVERITY_ORDER.get(g["worst_severity"], 9), -len(g["alerts"]), g["package"] or ""),
    )
    return ordered


def upgrade_hint(group: dict) -> str:
    eco = group["ecosystem"]
    hints = UPGRADE_HINTS.get(eco, {"direct": "Upgrade {name} to {version}.", "transitive": "Upgrade the parent of {name} to reach {version}."})
    name = group["package"] or "the package"
    version = group["target_version"] or "the patched release"
    relationship = (group["alerts"][0].get("relationship") or "").lower()
    kind = "direct" if relationship == "direct" else "transitive"
    text = hints[kind].format(name=name, version=version)
    if relationship not in ("direct", "transitive"):
        text += "\n(Relationship not reported by the API — check the manifest to confirm whether this is a direct dependency.)"
    return text


# ------------------------------------------------------------------------ images


def inline_images(body: str, session: requests.Session) -> str:
    """Best-effort: embed remote images as data URIs so the PDF is self-contained."""
    pattern = re.compile(r"!\[([^\]]*)\]\((https?://[^\s)]+)\)|\[image\]\((https?://[^\s)]+)\)")

    def repl(m: re.Match) -> str:
        alt = m.group(1) or "screenshot"
        url = m.group(2) or m.group(3)
        host = urlparse(url).netloc
        if host not in IMAGE_HOSTS:
            return f"[{alt} (external image)]({url})"
        try:
            r = session.get(url, timeout=20)
            ctype = r.headers.get("content-type", "")
            if r.ok and ctype.startswith("image/") and len(r.content) < 4_000_000:
                b64 = base64.b64encode(r.content).decode()
                return f"![{alt}](data:{ctype};base64,{b64})"
        except requests.RequestException:
            pass
        return f"[{alt} — image not embedded (GitHub signed URL expired); open in the alert page]({url})"

    return pattern.sub(repl, body)


# ---------------------------------------------------------------------- rendering


def md_to_html(text: str) -> str:
    try:
        import markdown as md_lib

        return md_lib.markdown(
            text,
            extensions=["fenced_code", "tables", "sane_lists", "nl2br", "attr_list"],
        )
    except ImportError:  # degrade to escaped preformatted text
        return f"<pre>{escape(text)}</pre>"


def badge(severity: str) -> str:
    color = SEVERITY_COLOR.get(severity, "#57606a")
    return f'<span class="badge" style="background:{color}">{escape(severity.upper())}</span>'


def fmt_date(value: str | None) -> str:
    if not value:
        return "—"
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M UTC")
    except ValueError:
        return value


def alert_detail_md(a: dict, repo: str) -> str:
    """Full alert detail, mirroring the GitHub alert page."""
    lines = [
        f"### {a['summary']} #{a['number']}",
        "",
        f"**{a['state'].title()}** on **{a['package']}** ({a['ecosystem']}) • `{a['manifest']}`",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Severity | {a['severity'].upper()} |",
        f"| Affected versions | `{a['vulnerable_range'] or '—'}` |",
        f"| Patched version | `{a['first_patched'] or 'no patch available'}` |",
        f"| GHSA | {a['ghsa_id'] or '—'} |",
        f"| CVE | {a['cve_id'] or '—'} |",
        f"| CVSS | {a['cvss_score'] if a['cvss_score'] is not None else '—'} `{a['cvss_vector'] or ''}` |",
    ]
    if a["cvss_v3_score"] is not None and a["cvss_v3_vector"] != a["cvss_vector"]:
        lines.append(f"| CVSS v3 | {a['cvss_v3_score']} `{a['cvss_v3_vector'] or ''}` |")
    if a["epss_percentage"] is not None:
        lines.append(f"| EPSS | {a['epss_percentage']} (percentile {a['epss_percentile']}) |")
    if a["cwes"]:
        cwes = ", ".join(f"{c.get('cwe_id')} {c.get('name')}" for c in a["cwes"])
        lines.append(f"| Weaknesses | {cwes} |")
    lines += [
        f"| Dependency scope | {a['scope'] or '—'} |",
        f"| Relationship | {a['relationship'] or '—'} |",
        f"| Alert opened | {fmt_date(a['created_at'])} |",
        f"| Advisory published | {fmt_date(a['published_at'])} |",
        f"| Alert URL | {a['html_url']} |",
    ]
    if a["dismissed_at"]:
        lines.append(f"| Dismissed | {fmt_date(a['dismissed_at'])} — {a['dismissed_reason']} {a['dismissed_comment'] or ''} |")
    if a["fixed_at"]:
        lines.append(f"| Fixed | {fmt_date(a['fixed_at'])} |")
    lines += ["", a["description"] or "_No advisory body provided._", ""]

    if len(a["all_affected_ranges"]) > 1:
        lines += ["#### All packages covered by this advisory", "", "| Package | Severity | Affected | Patched |", "| --- | --- | --- | --- |"]
        for v in a["all_affected_ranges"]:
            lines.append(
                f"| {v['package']} | {(v['severity'] or '').upper()} | `{v['vulnerable_version_range']}` | `{v['first_patched_version'] or '—'}` |"
            )
        lines.append("")

    if a["references"]:
        lines += ["#### References", ""] + [f"- {url}" for url in a["references"]] + [""]
    return "\n".join(lines)


def build_markdown(repo: str, alerts: list[dict], groups: list[dict], state: str) -> str:
    counts = {s: sum(1 for a in alerts if a["severity"] == s) for s in ("critical", "high", "medium", "low")}
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    out = [
        f"# Dependabot security report — {repo}",
        "",
        f"Generated {generated} • state filter: `{state}` • {len(alerts)} alert(s)",
        "",
        "| Critical | High | Medium | Low |",
        "| --- | --- | --- | --- |",
        f"| {counts['critical']} | {counts['high']} | {counts['medium']} | {counts['low']} |",
        "",
        "## Remediation plan",
        "",
        "Ordered by severity, then by how many alerts each upgrade closes.",
        "",
    ]

    for i, g in enumerate(groups, 1):
        out += [
            f"### {i}. Upgrade `{g['package']}` to `{g['target_version'] or 'n/a'}` — closes {len(g['alerts'])} alert(s)",
            "",
            f"- Manifest: `{g['manifest']}`",
            f"- Ecosystem: {g['ecosystem']}",
            f"- Worst severity: {g['worst_severity'].upper()}",
            f"- Alerts: {', '.join('#' + str(a['number']) for a in g['alerts'])}",
            "",
            "```",
            upgrade_hint(g),
            "```",
            "",
        ]

    out += ["---", "", "## Alert details", ""]
    for a in sorted(alerts, key=lambda x: (sev_rank(x), x["number"])):
        out.append(alert_detail_md(a, repo))
        out.append("---")
        out.append("")
    return "\n".join(out)


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
img { max-width: 100%; border: 1px solid #d1d9e0; border-radius: 6px; margin: 8px 0; }
a { color: #0969da; text-decoration: none; word-break: break-all; }
hr { border: 0; border-top: 1px solid #d1d9e0; margin: 22px 0; }
.badge { color: #fff; border-radius: 999px; padding: 1px 8px; font-size: 8.5pt; font-weight: 600; }
.meta { color: #57606a; font-size: 9.5pt; }
blockquote { border-left: 3px solid #d1d9e0; margin: 8px 0; padding-left: 10px; color: #57606a; }
"""


def build_html(repo: str, body_md: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Dependabot security report — {escape(repo)}</title>
<style>{CSS}</style></head>
<body>{md_to_html(body_md)}</body></html>"""


def write_pdf(html: str, path: Path) -> bool:
    try:
        from weasyprint import HTML  # type: ignore

        HTML(string=html, base_url=".").write_pdf(str(path))
        return True
    except Exception as exc:  # noqa: BLE001 - PDF is a nice-to-have, never fatal
        print(f"PDF rendering skipped: {exc}", file=sys.stderr)
        return False


# ------------------------------------------------------------------- agent output


def agent_brief(a: dict, group: dict, repo: str) -> str:
    return f"""# Fix task — alert #{a['number']}: {a['summary']}

Repository: `{repo}`
Alert: {a['html_url']}

## Target
- Package: `{a['package']}` ({a['ecosystem']})
- Manifest: `{a['manifest']}`
- Currently matched range: `{a['vulnerable_range']}`
- Minimum safe version: `{a['first_patched'] or 'NO PATCH AVAILABLE'}`
- Version to move to (covers every open alert on this package): `{group['target_version'] or 'n/a'}`
- Severity: {a['severity'].upper()} | CVSS {a['cvss_score']} | EPSS {a['epss_percentage']}
- Scope: {a['scope']} | Relationship: {a['relationship']}

## How to apply
```
{upgrade_hint(group)}
```

## Constraints
- Change only what this fix requires. No refactors, no formatting sweeps, no unrelated bumps.
- If the upgrade forces a breaking API change, stop and write the required migration
  steps into the task log instead of guessing.
- Keep the lockfile and the manifest in sync; commit both.
- If no patched version exists, do not invent one — record the mitigation
  (config change, dependency removal, or dismissal rationale) instead.

## Acceptance criteria
- [ ] Manifest and lockfile pin `{a['package']}` at or above `{group['target_version'] or a['first_patched']}`
- [ ] Install/resolve step succeeds from a clean state
- [ ] Build passes
- [ ] Test suite passes
- [ ] No new dependency alert introduced by the bump

## Advisory (verbatim)

{a['description'] or '_No advisory body provided._'}

## References
{chr(10).join('- ' + r for r in a['references']) or '- none'}
"""


# -------------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate a Dependabot alert report.")
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"), help="owner/name")
    ap.add_argument("--state", default="open", choices=["open", "fixed", "dismissed", "auto_dismissed", "all"])
    ap.add_argument("--min-severity", default="low", choices=["low", "medium", "high", "critical"])
    ap.add_argument("--out", default="reports/dependabot")
    ap.add_argument("--no-pdf", action="store_true")
    ap.add_argument("--no-images", action="store_true", help="do not attempt to embed advisory screenshots")
    ap.add_argument("--fail-on", default=None, choices=["low", "medium", "high", "critical"])
    args = ap.parse_args()

    if not args.repo:
        sys.exit("--repo owner/name is required (or set GITHUB_REPOSITORY)")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        sys.exit("Set GITHUB_TOKEN to a token that can read Dependabot alerts.")

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "dependabot-report-generator",
        }
    )

    raw = fetch_alerts(session, args.repo, args.state)
    cutoff = SEVERITY_ORDER[args.min_severity]
    alerts = [a for a in (normalise(x) for x in raw) if sev_rank(a) <= cutoff]
    alerts.sort(key=lambda a: (sev_rank(a), a["number"]))

    if not args.no_images:
        for a in alerts:
            a["description"] = inline_images(a["description"], session)

    groups = group_upgrades(alerts)
    group_for = {a["number"]: g for g in groups for a in g["alerts"]}

    out = Path(args.out)
    (out / "agent").mkdir(parents=True, exist_ok=True)

    (out / "alerts.json").write_text(json.dumps(raw, indent=2), encoding="utf-8")

    queue = [
        {
            "order": i,
            "alert_number": a["number"],
            "severity": a["severity"],
            "package": a["package"],
            "ecosystem": a["ecosystem"],
            "manifest": a["manifest"],
            "current_range": a["vulnerable_range"],
            "target_version": group_for[a["number"]]["target_version"],
            "closes_alerts": [x["number"] for x in group_for[a["number"]]["alerts"]],
            "ghsa_id": a["ghsa_id"],
            "cve_id": a["cve_id"],
            "brief": f"agent/alert-{a['number']}-{re.sub(r'[^A-Za-z0-9._-]', '_', a['package'] or 'pkg')}.md",
            "alert_url": a["html_url"],
        }
        for i, a in enumerate(alerts, 1)
    ]
    (out / "agent-queue.json").write_text(json.dumps(queue, indent=2), encoding="utf-8")

    for a in alerts:
        slug = re.sub(r"[^A-Za-z0-9._-]", "_", a["package"] or "pkg")
        (out / "agent" / f"alert-{a['number']}-{slug}.md").write_text(
            agent_brief(a, group_for[a["number"]], args.repo), encoding="utf-8"
        )

    body_md = build_markdown(args.repo, alerts, groups, args.state)
    (out / "report.md").write_text(body_md, encoding="utf-8")

    html = build_html(args.repo, body_md)
    (out / "report.html").write_text(html, encoding="utf-8")
    if not args.no_pdf:
        write_pdf(html, out / "report.pdf")

    counts = {s: sum(1 for a in alerts if a["severity"] == s) for s in ("critical", "high", "medium", "low")}
    summary = [
        f"## Dependabot report — {args.repo}",
        "",
        f"{len(alerts)} alert(s) • critical {counts['critical']} · high {counts['high']} · "
        f"medium {counts['medium']} · low {counts['low']}",
        "",
        "| # | Severity | Package | Upgrade to | Manifest |",
        "| --- | --- | --- | --- | --- |",
    ]
    for a in alerts:
        summary.append(
            f"| [#{a['number']}]({a['html_url']}) | {a['severity'].upper()} | `{a['package']}` | "
            f"`{group_for[a['number']]['target_version'] or 'n/a'}` | `{a['manifest']}` |"
        )
    (out / "summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")

    print(f"{len(alerts)} alert(s) written to {out}/")
    for g in groups:
        print(f"  {g['worst_severity'].upper():8} {g['package']} -> {g['target_version']} ({len(g['alerts'])} alerts)")

    if args.fail_on:
        threshold = SEVERITY_ORDER[args.fail_on]
        breaching = [a for a in alerts if sev_rank(a) <= threshold]
        if breaching:
            print(f"::error::{len(breaching)} alert(s) at or above {args.fail_on}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
