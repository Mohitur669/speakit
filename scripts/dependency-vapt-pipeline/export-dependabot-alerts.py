#!/usr/bin/env python3
import json
import subprocess
import csv
import os
import sys
from collections import Counter

REPO = "Mohitur669/speakit"
OUTPUT_DIR = "reports"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "dependabot-alerts.csv")

def get_alerts():
    print(f"Fetching alerts from {REPO} via GitHub CLI...")
    try:
        result = subprocess.run(
            ["gh", "api", "--paginate", f"/repos/{REPO}/dependabot/alerts"],
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
        key=lambda x: severity_weight(x.get("security_advisory", {}).get("severity", "")),
        reverse=True
    )

    closed_counts = Counter()

    # Process and write CSV
    with open(OUTPUT_FILE, mode='w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Write main alerts table
        writer.writerow(["Alert_ID", "Package", "Severity", "State", "Raised_Time", "Closed_Time"])
        
        for alert in alerts:
            alert_id = alert.get("number")
            package = alert.get("security_vulnerability", {}).get("package", {}).get("name", "Unknown")
            severity = alert.get("security_advisory", {}).get("severity", "unknown")
            state = alert.get("state", "unknown")
            raised = alert.get("created_at", "")
            
            closed = alert.get("fixed_at") or alert.get("dismissed_at") or "Still Open"
            
            writer.writerow([alert_id, package, severity, state, raised, closed])
            
            # Tally closed alerts by severity
            if state in ["fixed", "dismissed"]:
                closed_counts[severity.lower()] += 1

        # Write Summary Section at the bottom of the same CSV
        writer.writerow([])
        writer.writerow([])
        writer.writerow(["--- SUMMARY: CLOSED ALERTS BY SEVERITY ---", "", "", "", "", ""])
        writer.writerow(["Severity", "Total Closed", "", "", "", ""])
        
        for sev in ["critical", "high", "medium", "low"]:
            writer.writerow([sev.capitalize(), closed_counts[sev], "", "", "", ""])

    print(f"✅ Successfully exported alerts and summary to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
