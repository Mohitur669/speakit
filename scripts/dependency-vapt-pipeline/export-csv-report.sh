#!/usr/bin/env bash
set -e

REPO="Mohitur669/speakit"
OUTPUT_FILE="vapt-alerts-report.csv"

echo "Exporting Dependabot alerts to $OUTPUT_FILE..."

# Write the CSV headers
echo "Alert_ID,Package,Severity,State,Raised_Time,Closed_Time" > "$OUTPUT_FILE"

# Fetch all paginated alerts, sort by severity (Critical -> High -> Medium -> Low), and convert to CSV
gh api --paginate "/repos/$REPO/dependabot/alerts" | jq -r '
  sort_by(
    if .security_advisory.severity == "critical" then 4
    elif .security_advisory.severity == "high" then 3
    elif .security_advisory.severity == "medium" then 2
    elif .security_advisory.severity == "low" then 1
    else 0 end
  ) | reverse |
  .[] | [
    .number,
    .security_vulnerability.package.name,
    .security_advisory.severity,
    .state,
    .created_at,
    (.fixed_at // .dismissed_at // "Still Open")
  ] | @csv
' >> "$OUTPUT_FILE"

echo "✅ Done! Exported to $OUTPUT_FILE"
