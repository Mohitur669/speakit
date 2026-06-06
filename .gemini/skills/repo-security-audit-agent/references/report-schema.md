# Validation and Reporting

## Severity Matrix

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Directly exploitable with no auth required, or results in full compromise (RCE, auth bypass, secret exfil) |
| **HIGH** | Exploitable with low effort or with authenticated access; significant data/system impact |
| **MEDIUM** | Requires specific conditions or chaining; moderate impact |
| **LOW** | Defence-in-depth issue; low likelihood or low impact in isolation |

## Risk Score Formula

```
score = min(100, (critical × 25) + (high × 10) + (medium × 3) + (low × 1))
risk_label:
  80-100 → CRITICAL
  50-79  → HIGH
  20-49  → MEDIUM
  1-19   → LOW
  0      → CLEAN
```

## Report Schema (JSON Output)

Output ONLY valid JSON — no preamble, no markdown fences.

```json
{
  "meta": {
    "repo": "https://github.com/<owner>/<repo>",
    "audited_at": "<ISO-8601 timestamp>",
    "files_fetched": <integer>,
    "files_in_tree": <integer>,
    "scope": ["secrets", "injection", "auth", "deps", "config", "exposure", "docker", "cicd"],
    "agent_version": "SecAuditAgent-v1"
  },
  "summary": {
    "critical": <integer>,
    "high": <integer>,
    "medium": <integer>,
    "low": <integer>,
    "total": <integer>,
    "risk_score": "<0-100 integer>",
    "risk_label": "CRITICAL | HIGH | MEDIUM | LOW | CLEAN"
  },
  "findings": [
    {
      "id": "F01",
      "severity": "critical | high | medium | low",
      "category": "<category ID from categories>",
      "title": "<short, specific title — max 10 words>",
      "description": "<2-4 sentences: what the issue is, where it lives, and the exact attack vector an adversary would use>",
      "evidence": {
        "file": "<exact file path>",
        "line_hint": "<variable name, config key, or code snippet — max 120 chars>",
        "additional_locations": ["<other file paths if applicable>"]
      },
      "cvss_estimate": "<e.g. 9.8 / 7.5 / 5.3 / 3.1 — omit if uncertain>",
      "cve": "<CVE-YYYY-NNNNN if applicable, omit otherwise>",
      "attack_scenario": "<1-2 sentence realistic attacker narrative>",
      "remediation": {
        "summary": "<1-sentence fix>",
        "steps": [
          "<step 1>",
          "<step 2>"
        ],
        "code_fix": "<corrected code or config snippet — include only if concrete and helpful>"
      },
      "references": [
        "<OWASP / CWE / CVE / documentation link>"
      ]
    }
  ],
  "positive_signals": [
    "<list anything the repo does RIGHT security-wise>"
  ],
  "recommended_next_steps": [
    "<top 3-5 prioritised actions the team should take, ordered by impact>"
  ]
}
```