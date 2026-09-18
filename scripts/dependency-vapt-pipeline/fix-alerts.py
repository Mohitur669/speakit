#!/usr/bin/env python3
"""
Destination: scripts/dependency-vapt-pipeline/fix-alerts.py   (chmod +x)

Walks the Dependabot queue produced by .github/scripts/dependabot_report.py and
hands each alert, one at a time, to a local agent that has the whole codebase in
context. One branch per fix, verification after each, human approval before commit.

Usage:
  ./scripts/dependency-vapt-pipeline/fix-alerts.py                       # interactive, full queue
  ./scripts/dependency-vapt-pipeline/fix-alerts.py --dry-run             # print what would run
  ./scripts/dependency-vapt-pipeline/fix-alerts.py --only 24             # a single alert number
  ./scripts/dependency-vapt-pipeline/fix-alerts.py --from 3 --auto       # resume at #3, no prompts
  ./scripts/dependency-vapt-pipeline/fix-alerts.py --refresh             # regenerate the report first

Environment Variables:
  AGENT_CMD     agent invocation, prompt arrives on stdin   (default: agy)
  VERIFY_CMD    build/test command                          (default: auto-detected)
  REPORT_DIR    where the report lives                      (default: reports/dependabot)
  GITHUB_TOKEN  needed only with --refresh
"""

import sys
import os
import json
import subprocess
import argparse
from datetime import datetime, timezone
import re

def run_cmd(cmd, shell=True, capture=False):
    if capture:
        return subprocess.run(cmd, shell=shell, text=True, capture_output=True)
    return subprocess.run(cmd, shell=shell)

def main():
    parser = argparse.ArgumentParser(description="Iterate over VAPT queue and fix via AI agent.")
    parser.add_argument("--dry-run", action="store_true", help="Print what would run")
    parser.add_argument("--auto", action="store_true", help="Run without prompts")
    parser.add_argument("--from", dest="from_order", type=int, default=1, help="Resume at order N")
    parser.add_argument("--only", type=str, help="Process a single alert number")
    parser.add_argument("--refresh", action="store_true", help="Regenerate the report first")
    
    args = parser.parse_args()

    agent_cmd = os.environ.get("AGENT_CMD", "agy")
    report_dir = os.environ.get("REPORT_DIR", "reports/dependabot")
    queue_file = os.path.join(report_dir, "agent-queue.json")
    log_file = os.path.join(report_dir, "fix-log.md")

    if args.refresh:
        print("Refreshing reports...")
        if run_cmd(f"python .github/scripts/dependabot_report.py --out {report_dir}").returncode != 0:
            print("Failed to refresh reports.")
            sys.exit(1)

    if not os.path.exists(queue_file):
        print(f"No queue at {queue_file}.")
        print("Run with --refresh, or pull the latest CI bundle.")
        sys.exit(1)

    verify_cmd = os.environ.get("VERIFY_CMD")
    if not verify_cmd:
        if os.path.exists("frontend/package.json"):
            verify_cmd = "npm --prefix frontend ci && npm --prefix frontend run build && npm --prefix frontend test -- --watch=false"
        elif os.path.exists("package.json"):
            verify_cmd = "npm ci && npm run build --if-present && npm test --if-present"
        elif os.path.exists("pom.xml"):
            verify_cmd = "./mvnw -B verify"
        elif os.path.exists("build.gradle") or os.path.exists("build.gradle.kts"):
            verify_cmd = "./gradlew build"
        else:
            verify_cmd = "true"

    try:
        base_branch = run_cmd("git rev-parse --abbrev-ref HEAD", capture=True).stdout.strip()
    except Exception:
        base_branch = "master"

    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    with open(log_file, "a", encoding="utf-8") as lf:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        lf.write(f"\n## Run {timestamp} (base: {base_branch})\n\n")

    with open(queue_file, "r", encoding="utf-8") as qf:
        queue = json.load(qf)

    total = len(queue)
    print(f"Queue: {total} alert(s) · agent: {agent_cmd} · verify: {verify_cmd}\n")

    for idx, item in enumerate(queue):
        order = item.get("order", idx + 1)
        num = str(item.get("alert_number"))
        sev = item.get("severity", "unknown").upper()
        pkg = item.get("package", "unknown")
        target = item.get("target_version", "unknown")
        closes_list = item.get("closes_alerts", [])
        closes_str = ", ".join(f"#{c}" for c in closes_list)
        brief_rel = item.get("brief", "")
        brief_path = os.path.join(report_dir, brief_rel)

        if order < args.from_order:
            continue
        if args.only and num != args.only:
            continue

        print("────────────────────────────────────────────────────────")
        print(f"[{order}/{total}] #{num}  {sev}  {pkg} -> {target}  (closes #{closes_str})")
        print(f"brief: {brief_path}")

        slug = re.sub(r'[^A-Za-z0-9._-]', '-', pkg)
        branch = f"fix/dependabot-{num}-{slug}"

        if args.dry_run:
            print(f"  would: git switch -c {branch} && {agent_cmd} < {brief_path} && {verify_cmd}")
            continue

        if not args.auto:
            ans = ""
            while True:
                ans = input("  run this fix? [y]es / [s]kip / [q]uit: ").strip().lower()
                if ans in ['y', 'yes', 's', 'skip', 'q', 'quit']:
                    break
            
            if ans in ['s', 'skip']:
                with open(log_file, "a") as lf:
                    lf.write(f"- skipped #{num} ({pkg})\n")
                continue
            elif ans in ['q', 'quit']:
                print("stopping.")
                sys.exit(0)

        # Try creating a new branch, fallback to checking out existing
        if run_cmd(f"git switch -c {branch} {base_branch} 2>/dev/null").returncode != 0:
            run_cmd(f"git switch {branch}")

        if not os.path.exists(brief_path):
            print(f"  brief file not found: {brief_path}")
            run_cmd(f"git switch {base_branch}")
            continue

        with open(brief_path, "r") as bf:
            res = subprocess.run(agent_cmd, stdin=bf, shell=True)
            if res.returncode != 0:
                print(f"  agent exited non-zero on #{num}")
                with open(log_file, "a") as lf:
                    lf.write(f"- agent failed on #{num}\n")
                run_cmd(f"git switch {base_branch}")
                continue

        print("  verifying...")
        if run_cmd(verify_cmd).returncode == 0:
            verdict = "verified"
        else:
            verdict = "VERIFICATION FAILED"
            print(f"  {verdict} — branch {branch} left in place for manual review.")

        run_cmd("git --no-pager diff --stat")
        
        with open(log_file, "a") as lf:
            lf.write(f"- #{num} {pkg} -> {target} on `{branch}` — {verdict}\n")

        if verdict == "verified":
            commit = 'y'
            if not args.auto:
                commit = input("  commit? [y/N]: ").strip().lower()

            if commit in ['y', 'yes']:
                run_cmd("git add -A")
                commit_msg = f"fix(deps): bump {pkg} to {target}\n\nCloses Dependabot alert(s) #{closes_str}."
                subprocess.run(["git", "commit", "-m", commit_msg])

        run_cmd(f"git switch {base_branch}")

    print(f"\nDone. Log: {log_file}")

if __name__ == "__main__":
    main()
