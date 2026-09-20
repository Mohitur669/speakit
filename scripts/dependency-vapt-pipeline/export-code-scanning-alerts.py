#!/usr/bin/env python3
import json
import subprocess
import csv
import os
import sys
from collections import Counter

REPO = "Mohitur669/speakit"
OUTPUT_DIR = "reports/alerts"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "code-scanning-alerts.csv")

def get_alerts():
    print(f"Fetching Code Scanning alerts from {REPO} via GitHub CLI...")
    try:
        result = subprocess.run(
            ["gh", "api", "--paginate", f"/repos/{REPO}/code-scanning/alerts"],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching alerts: {e.stderr}")
        sys.exit(1)

def severity_weight(severity):
    weights = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    return weights.get(severity.lower(), 0)

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    alerts = get_alerts()

    # Sort alerts by severity (descending)
    alerts.sort(
        key=lambda x: severity_weight(
            x.get("rule", {}).get("security_severity_level")
            or x.get("rule", {}).get("severity", "")
        ),
        reverse=True
    )

    closed_counts = Counter()

    with open(OUTPUT_FILE, mode='w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(["Alert_ID", "Rule_ID", "Severity", "State", "Path", "Start_Line", "End_Line", "Message", "Raised_Time", "Closed_Time", "Alert_URL"])

        for alert in alerts:
            alert_id = alert.get("number")
            rule = alert.get("rule", {})
            rule_id = rule.get("id", "Unknown")
            sec_level = rule.get("security_severity_level") or rule.get("severity", "unknown")
            state = alert.get("state", "unknown")
            raised = alert.get("created_at", "")
            closed = alert.get("fixed_at") or alert.get("dismissed_at") or "Still Open"
            inst = alert.get("most_recent_instance", {})
            loc = inst.get("location", {})
            path = loc.get("path", "")
            start_line = loc.get("start_line", "")
            end_line = loc.get("end_line", "")
            msg = inst.get("message", {}).get("text", "")
            url = alert.get("html_url", "")

            writer.writerow([alert_id, rule_id, sec_level, state, path, start_line, end_line, msg, raised, closed, url])

            if state in ["fixed", "dismissed"]:
                closed_counts[sec_level.lower()] += 1

        writer.writerow([])
        writer.writerow([])
        writer.writerow(["--- SUMMARY: CLOSED ALERTS BY SEVERITY ---", "", "", "", "", "", "", "", "", "", ""])
        writer.writerow(["Severity", "Total Closed", "", "", "", "", "", "", "", "", ""])

        for sev in ["critical", "high", "medium", "low"]:
            writer.writerow([sev.capitalize(), closed_counts[sev], "", "", "", "", "", "", "", "", ""])

    print(f"[OK] Successfully exported Code Scanning alerts to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
