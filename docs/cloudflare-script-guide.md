# Cloudflare Logpush & Security Audit Commands Guide

Comprehensive guide, command references, and architecture documentation for consolidating Cloudflare Account-scoped Logpush logs from Cloudflare R2 and executing industry-grade threat scoring and IP blocking decisions.

---

## 1. Bucket Permission Requirements: Is Write Access Needed?

> [!IMPORTANT]
> **Write access to Cloudflare R2 is NEVER required.**
> To fetch, stream, filter, and consolidate log files, the credentials only require **Read-Only / Object Read** permissions (`r2:ListBucket` and `r2:GetObject`). 
> 
> Write (`r2:PutObject`) or Delete (`r2:DeleteObject`) permissions are only needed if you are writing data back to R2. All consolidation files (`cloudflare_requests_log.jsonl` and `cloudflare_requests_log.csv`) and security reports (`reports/`) are generated **locally on disk** in `scripts/cloudflare-scan/data/` and `scripts/cloudflare-scan/reports/`.

---

## 2. Environment Setup

Always activate the local Conda environment before executing scripts:

```bash
conda activate localpython
cd /Users/mohitur/Desktop/git-projects/speakit/scripts/cloudflare-scan
```

### Credentials & Configuration
The scripts automatically read credentials from `backend/.env`:
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID` (or `R2_LOGS_ACCESS_KEY_ID`)
- `R2_SECRET_ACCESS_KEY` (or `R2_LOGS_SECRET_ACCESS_KEY`)
- `R2_BUCKET_NAME` (or pass `--bucket <name>`)

---

## 3. Logpush Fetcher (`logpush-fetcher.py`)

`logpush-fetcher.py` connects to Cloudflare R2 via S3-compatible API, inspects `.log.gz` timestamps (e.g., `20261014T004530Z_20261014T004530Z_36f426b1.log.gz`), streams and decompresses the archives on the fly, and merges all records into a single consolidated JSONL and CSV file.

### Default Output Files
- **JSONL:** `scripts/cloudflare-scan/data/cloudflare_requests_log.jsonl`
- **CSV:** `scripts/cloudflare-scan/data/cloudflare_requests_log.csv`

---

### Command Recipes

#### A. Standard Run (Last 30 Days)
Consolidates all batches from the last 30 days and generates both `.jsonl` and `.csv`:
```bash
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --days 30
```

#### B. Quick Convert Existing JSONL to CSV (No R2 Download)
If you already ran the fetcher and want to regenerate `cloudflare_requests_log.csv` in milliseconds without touching R2:
```bash
python logpush-fetcher.py --convert-only
```
Or specify a custom file:
```bash
python logpush-fetcher.py --convert-only data/cloudflare_requests_log.jsonl
```

#### C. Custom Time Windows
Retrieve logs for a different number of days:
```bash
# Last 7 days:
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --days 7

# Last 60 days:
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --days 60

# Last 24 hours:
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --days 1
```

#### D. Filtering by Subfolder / Prefix
If your Logpush writes to a specific prefix inside the bucket:
```bash
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --prefix account-logs/ --days 30
```

#### E. Test Run with Batch Limit
Download and consolidate only the first 5 log batches to verify schema or connectivity:
```bash
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --limit 5
```

#### F. JSONL Only (Skip CSV Generation)
If you only need JSONL and want to skip CSV conversion:
```bash
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --no-csv
```

#### G. Save Raw `.log.gz` Archives to Disk
To preserve raw compressed `.log.gz` batch files in `data/raw_logs/`:
```bash
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --save-raw
```

#### H. Custom Output Path
Direct the consolidated output to a custom location:
```bash
python logpush-fetcher.py --output data/custom_export.jsonl
```

---

## 4. Security & Exposure Auditor (`log-security-auditor.py`)

`log-security-auditor.py` inspects Cloudflare logs, classifies traffic, scores threats using an **enterprise production-grade decision engine**, and outputs ready-to-deploy Cloudflare WAF rules, IP Access lists, and executive Markdown reports.

### Multi-Format Input Support
The auditor accepts any log format seamlessly:
- **Automatic detection**: Running `python log-security-auditor.py` without arguments automatically discovers `data/cloudflare_requests_log.csv` or `data/cloudflare_requests_log.jsonl`.
- **Direct JSONL Ingestion**: Streams `.jsonl` directly without requiring CSV conversion (`python log-security-auditor.py data/cloudflare_requests_log.jsonl`).
- **Direct CSV Ingestion**: Streams `.csv` with case-tolerant PascalCase and camelCase column mapping (`python log-security-auditor.py data/cloudflare_requests_log.csv`).
- **Gzip Archives**: Reads `.log.gz` directly.

---

### Industry IP Block Decision Engine

Production application security systems cannot rely on naive request counts. The auditor implements a multi-vector decision matrix matching enterprise SOC standards:

#### 1. Zero-Tolerance Malicious Targets (`HIGH_RISK_PATH_PATTERNS`)
Direct attacks on credentials or core infrastructure immediately establish **Malicious Threat Intent**:
- Secrets & Environment: `/.env`, `/.env.*`, `/.aws/`, `/.ssh/`, `service-account.json`, `credentials.json`, `wp-config.php`, `web.config`
- Version Control: `/.git/`, `/.git/HEAD`, `/.svn/`, `/.hg/`
- Shells & Backdoors: `/eval-stdin`, `/setup.cgi`, `/boaform/`, `/shell`, `/cgi-bin/`
- Internal Endpoints: `/actuator/env`, `/actuator/heapdump`, `/phpinfo`, `database.sql`, `dump.sql`
- Weaponized CVE Probes: `/wp-json/gravitysmtp/`, `xmlrpc.php`, `${jndi:`

#### 2. Decision Matrix & Tiers

| Tier | Decision Criteria | Production Action |
|---|---|---|
| **BLOCK** | $\ge 3$ high-risk credential paths probed, OR score $\ge 70$ with confirmed malicious intent, OR known exploit tool, OR fake search bot. | Add to Cloudflare IP Access Rules (`Block`) or WAF Custom Rule. |
| **CHALLENGE** | Score $40 - 69$, OR rate spike ($> 120$ req/min), OR security research crawlers, OR broad reconnaissance ($1-2$ probe paths). | Add to Cloudflare WAF Custom Rule (`Managed Challenge`). |
| **WATCH** | Score $20 - 39$, low-volume anomalies or isolated 404s. | Monitor in Cloudflare Security Analytics. |
| **ALLOW** | Legitimate SaaS webhooks (GitHub, Stripe, PayPal) and DNS-verified crawlers (Googlebot, Bingbot, Applebot). | Exempted from blocking (Zero False-Positive Engine). |

#### 3. Decision Codes & Confidence Levels
Every suggested IP receives an actionable decision tuple:
- **Decision Code**: `BLOCK_CREDENTIAL_PROBING`, `BLOCK_VULNERABILITY_SCAN`, `BLOCK_OFFENSIVE_SCANNER`, `BLOCK_SPOOFED_BOT`, `CHALLENGE_PERIMETER_RECON`, `CHALLENGE_RATE_ANOMALY`, `CHALLENGE_RESEARCH_SCANNER`
- **Confidence**: `HIGH` ($\ge 80$), `MEDIUM` ($50-79$), `LOW` ($< 50$)
- **Risk Category**: `CREDENTIAL_ACCESS`, `VULNERABILITY_RECON`, `EXPLOIT_ATTEMPT`, `RATE_ABUSE`, `SPOOFED_BOT`
- **Evidence Trail**: Detailed list of exact paths probed, hostnames targeted, Cloudflare ML WAF scores, and error ratios.

---

### Command Recipes

#### A. Zero-Argument Run (Auto-Detects Exported Logs)
Automatically finds `data/cloudflare_requests_log.csv` or `.jsonl` and runs the audit:
```bash
python log-security-auditor.py
```

#### B. Audit with Explicit Log File
```bash
# Ingest CSV:
python log-security-auditor.py data/cloudflare_requests_log.csv

# Ingest JSONL directly:
python log-security-auditor.py data/cloudflare_requests_log.jsonl
```

#### C. Audit with IP Allowlisting
Exclude internal IP addresses or office subnets from being suggested for blocks:
```bash
python log-security-auditor.py \
  --allow-ip 203.0.113.15 \
  --allow-ip 198.51.100.0/24 \
  --out reports
```

#### D. Live Exposure Verification (Safe GET)
Safely test whether 2xx responses on sensitive paths are actual exposures or false-positive SPA fallbacks:
```bash
python log-security-auditor.py \
  --live \
  --allow-suffix speakit.today \
  --out reports
```

#### E. Custom Scoring Thresholds
```bash
python log-security-auditor.py \
  --block-threshold 80 \
  --challenge-threshold 50 \
  --rate-threshold 150 \
  --min-requests 3 \
  --out reports
```

---

## 5. End-to-End Workflow

Run the complete pipeline from log collection to security decision:

```bash
# 1. Activate Python environment
conda activate localpython
cd /Users/mohitur/Desktop/git-projects/speakit/scripts/cloudflare-scan

# 2. Consolidate last 30 days of Cloudflare logs into JSONL and CSV
python logpush-fetcher.py --bucket cloudflare-managed-626ecaae --days 30

# 3. Run security audit and block decision engine
python log-security-auditor.py

# 4. View the consolidated security & decision report
cat reports/cloudflare-security-report.md
```

---

## 6. Consolidated Security Report Document

All threat intelligence, decision matrices, copy-paste Cloudflare WAF expressions, IP block/challenge lists, and exposure verification are generated in **a single consolidated markdown document**:

- **Primary Output:** [`reports/cloudflare-security-report.md`](file:///Users/mohitur/Desktop/git-projects/speakit/scripts/cloudflare-scan/reports/cloudflare-security-report.md)

### What is Inside `cloudflare-security-report.md`:
1. **Executive Threat Summary**: Total requests, sensitive probes, unique IPs, counts of IPs to block/challenge.
2. **Cloudflare WAF Custom Rules (Copy-Paste Ready)**: Pre-chunked WAF rule expressions (`(ip.src in { ... })`) for immediate deployment with `Block` and `Managed Challenge`.
3. **Cloudflare IP List Import Format**: Pre-formatted CSV snippet (`ip,comment`) for Cloudflare Account IP Lists.
4. **Pure IP / CIDR Lists**: One-per-line clean IP lists in collapsible code blocks.
5. **Actionable Threat Decision Matrix**: Compact decision table with Action, Decision Code, Confidence, IP, Risk Score, Probes, and Origin ASN.
6. **Threat Actor Profiles**: Deep-dive per offending IP detailing targeted paths, representative User-Agent, velocity, error rate, and Cloudflare ML WAF threat scores.
7. **Sensitive Endpoints Returning Edge 2xx**: Exposure audit of sensitive paths answering 2xx.
8. **Live Verification Findings**: Active probing verification results (when `--live` is used).
9. **Perimeter Intelligence**: HTTP status distribution, top targeted hostnames, top ASNs, top client IPs.
10. **Enterprise Hardening Checklist**: Origin and edge security remediation steps.

> [!TIP]
> If you ever need legacy separate files (`blocklist_ips.txt`, `challenge_ips.txt`, etc.), pass `--split-files`. By default, only the single consolidated document is generated.

---

## 7. CLI Argument Reference Tables

### `logpush-fetcher.py` Reference

| Flag | Type | Default | Description |
|---|---|---|---|
| `--bucket` | String | `.env` `R2_BUCKET_NAME` | R2 bucket name storing Logpush files. |
| `--days` | Integer | `30` | Number of past days to consolidate. |
| `--prefix` | String | `""` (root) | Bucket subfolder/prefix path. |
| `--output` | Path | `data/cloudflare_requests_log.jsonl` | Output JSONL file path. |
| `--to-csv` | Flag | `True` (enabled) | Also exports `data/cloudflare_requests_log.csv`. |
| `--no-csv` | Flag | — | Disables CSV export. |
| `--convert-only` | Path (opt) | `data/cloudflare_requests_log.jsonl` | Converts local JSONL to CSV without contacting R2. |
| `--save-raw` | Flag | `False` | Saves individual `.log.gz` files in `data/raw_logs/`. |
| `--limit` | Integer | `None` | Max number of log batches to process. |
| `--env-file` | Path | `backend/.env` | Path to credentials `.env` file. |

### `log-security-auditor.py` Reference

| Flag | Type | Default | Description |
|---|---|---|---|
| `[log_file]` | Positional (opt) | Auto-detects in `data/` | Path to log file (`.csv`, `.jsonl`, or `.log.gz`). |
| `--out` | Path | `reports` | Output directory for audit reports. |
| `--allow-ip` | String | `[]` | IP or CIDR to whitelist (repeatable). |
| `--allow-asn` | String | `[]` | ASN to whitelist (repeatable). |
| `--block-threshold` | Integer | `70` | Score required to suggest a BLOCK. |
| `--challenge-threshold`| Integer | `40` | Score required to suggest a CHALLENGE. |
| `--live` | Flag | `False` | Safe read-only GET verification for 2xx paths. |
| `--allow-suffix` | String | `[]` | Allowed domain suffixes for live checks. |
| `-v`, `--verbose` | Flag | `False` | Enables verbose debug logging. |
