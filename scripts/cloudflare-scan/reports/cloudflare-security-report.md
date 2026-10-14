# Cloudflare Consolidated Threat & Security Audit Report

> **Analyzed Log Source:** `cloudflare_requests_log.csv`  
> **Report Generated:** `2026-10-14 23:15:09 +0530`  
> **Threat Engine:** Enterprise SOC / WAF Decision Framework (v2.5)

---

## 1. Executive Threat Summary

| Metric | Value | SOC / Risk Interpretation |
|---|---:|---|
| **Total Requests Analyzed** | **240** | Total HTTP/HTTPS transactions inspected |
| **Unique Source IPs / Subnets** | **73** | Distinct origin clients observed |
| **Sensitive Probe Requests** | **88** | Probes against configuration, credentials, or admin endpoints |
| **Edge 2xx Sensitive Exposures** | **0** | Sensitive paths answering with success (investigate immediately) |
| **Recommended IPs to BLOCK** | **4** | High-confidence malicious intent / zero-tolerance targets |
| **Recommended IPs to CHALLENGE** | **1** | Suspicious reconnaissance / anomalous velocity |
| **IPs on WATCH List** | **0** | Low-level anomalies (monitor in Security Analytics) |

---

## 2. Cloudflare Mitigation & WAF Custom Rules (Ready to Deploy)

Deploy these rules directly in the Cloudflare Dashboard under **Security > WAF > Custom Rules** or **Security > WAF > Tools (IP Access Rules)**.

### A. WAF Custom Rule: Immediate BLOCK
- **Rule Action:** `Block`
- **Rule Description:** `Auto-Mitigation: High Malicious Threat Probes & Credential Scanners`
```cloudflare
(ip.src in {2a0c:b641:b0:a1a1::/64 46.151.182.148 185.218.86.21 2a06:98c0:3600::/64})
```

### B. WAF Custom Rule: MANAGED CHALLENGE
- **Rule Action:** `Managed Challenge`
- **Rule Description:** `Auto-Mitigation: Suspicious Reconnaissance & Fuzzing Crawlers`
```cloudflare
(ip.src in {34.71.174.127})
```

### C. Cloudflare IP Access List Import Format
For bulk import via **Manage Account > Configurations > Lists** (IP Lists):
```csv
# ip,comment
2a0c:b641:b0:a1a1::/64,[BLOCK_CREDENTIAL_PROBING] score=130 35 high-severity credential/exploit paths probed; 38 distinct probe paths (broad surface attack); perimeter scan across 3 hostnames
46.151.182.148,[BLOCK_MALICIOUS_THREAT] score=95 high-severity credential/exploit path probed; 4 distinct probe paths; spoofed future browser signature (Chrome 148+); 100% error responses (probe storm)
185.218.86.21,[BLOCK_MALICIOUS_THREAT] score=75 high-severity credential/exploit path probed; 2 probe path(s); cross-domain scan across 2 hostnames; security research scanner probing endpoints
2a06:98c0:3600::/64,[BLOCK_MALICIOUS_THREAT] score=70 1 probe path(s); Cloudflare ML WAF high attack confidence (score 0); 100% error responses (probe storm)
34.71.174.127,[CHALLENGE_SUSPICIOUS_PROBE] score=50 14 distinct probe paths; 94% error responses (probe storm)
```

### D. Pure IP / CIDR Block & Challenge Lists
<details>
<summary><b>Click to expand pure IP lists (one per line)</b></summary>

**BLOCK IPs:**
```text
2a0c:b641:b0:a1a1::/64
46.151.182.148
185.218.86.21
2a06:98c0:3600::/64
```

**CHALLENGE IPs:**
```text
34.71.174.127
```
</details>

---

## 3. Actionable Threat Decision Matrix

| Action | Decision Code | Confidence | IP / CIDR | Risk Score | Probes (High / Total) | Origin ASN |
|---|---|---|---|---:|---:|---|
| 🔴 **BLOCK** | `BLOCK_CREDENTIAL_PROBING` | **HIGH** | `2a0c:b641:b0:a1a1::/64` | 130 | 35 / 38 | `AS215599` |
| 🔴 **BLOCK** | `BLOCK_MALICIOUS_THREAT` | **HIGH** | `46.151.182.148` | 95 | 1 / 4 | `AS403005` |
| 🔴 **BLOCK** | `BLOCK_MALICIOUS_THREAT` | **MEDIUM** | `185.218.86.21` | 75 | 1 / 2 | `AS218785` |
| 🔴 **BLOCK** | `BLOCK_MALICIOUS_THREAT` | **MEDIUM** | `2a06:98c0:3600::/64` | 70 | 0 / 1 | `AS204997` |
| 🟡 **CHALLENGE** | `CHALLENGE_SUSPICIOUS_PROBE` | **MEDIUM** | `34.71.174.127` | 50 | 0 / 14 | `AS396982` |

> 💡 **Detailed Threat Profiles**: For complete evidence trails, targeted endpoints, and sample User-Agents for each actor, see [Section 4: Threat Actor Profiles](#4-threat-actor-profiles--targeted-endpoints) below.

---

## 4. Threat Actor Profiles & Targeted Endpoints

### 🔴 **BLOCK** `2a0c:b641:b0:a1a1::/64` — BLOCK_CREDENTIAL_PROBING
- **Risk Category:** `CREDENTIAL_ACCESS` | **Confidence:** `HIGH` | **Risk Score:** `130`
- **Origin ASN:** `AS215599 `
- **Traffic Velocity:** `102` total requests (Peak: `100` req/min) | **Error Rate:** `57.8%`
- **Activity Window:** `2026-10-13T20:54:34Z` to `2026-10-13T20:56:38Z`
- **Cloudflare ML Attack Score:** `56`
- **Representative User-Agent:** `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36`
- **Primary Threat Reasons:** 35 high-severity credential/exploit paths probed; 38 distinct probe paths (broad surface attack); perimeter scan across 3 hostnames
- **Enforcement Recommendation:** **Add to Cloudflare IP Access Rules (Action: Block) or WAF Custom Rule**

### 🔴 **BLOCK** `46.151.182.148` — BLOCK_MALICIOUS_THREAT
- **Risk Category:** `CREDENTIAL_ACCESS` | **Confidence:** `HIGH` | **Risk Score:** `95`
- **Origin ASN:** `AS403005 `
- **Traffic Velocity:** `10` total requests (Peak: `10` req/min) | **Error Rate:** `100.0%`
- **Activity Window:** `2026-10-13T21:09:42Z` to `2026-10-13T21:09:43Z`
- **Cloudflare ML Attack Score:** `78`
- **Representative User-Agent:** `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36`
- **Primary Threat Reasons:** high-severity credential/exploit path probed; 4 distinct probe paths; spoofed future browser signature (Chrome 148+); 100% error responses (probe storm)
- **Enforcement Recommendation:** **Add to Cloudflare IP Access Rules (Action: Block) or WAF Custom Rule**

### 🔴 **BLOCK** `185.218.86.21` — BLOCK_MALICIOUS_THREAT
- **Risk Category:** `CREDENTIAL_ACCESS` | **Confidence:** `MEDIUM` | **Risk Score:** `75`
- **Origin ASN:** `AS218785 `
- **Traffic Velocity:** `6` total requests (Peak: `4` req/min) | **Error Rate:** `33.3%`
- **Activity Window:** `2026-10-14T01:55:59Z` to `2026-10-14T11:29:32Z`
- **Cloudflare ML Attack Score:** `87`
- **Representative User-Agent:** `Mozilla/5.0 (compatible; SecurityResearch/1.0; )`
- **Primary Threat Reasons:** high-severity credential/exploit path probed; 2 probe path(s); cross-domain scan across 2 hostnames; security research scanner probing endpoints
- **Enforcement Recommendation:** **Add to Cloudflare IP Access Rules (Action: Block) or WAF Custom Rule**

### 🔴 **BLOCK** `2a06:98c0:3600::/64` — BLOCK_MALICIOUS_THREAT
- **Risk Category:** `EXPLOIT_ATTEMPT` | **Confidence:** `MEDIUM` | **Risk Score:** `70`
- **Origin ASN:** `AS204997 `
- **Traffic Velocity:** `11` total requests (Peak: `1` req/min) | **Error Rate:** `100.0%`
- **Activity Window:** `2026-10-13T21:21:12Z` to `2026-10-14T15:46:29Z`
- **Cloudflare ML Attack Score:** `0`
- **Representative User-Agent:** `http://mohitur.com/wp-admin/install.php?step=1`
- **Primary Threat Reasons:** 1 probe path(s); Cloudflare ML WAF high attack confidence (score 0); 100% error responses (probe storm)
- **Enforcement Recommendation:** **Add to Cloudflare IP Access Rules (Action: Block) or WAF Custom Rule**

### 🟡 **CHALLENGE** `34.71.174.127` — CHALLENGE_SUSPICIOUS_PROBE
- **Risk Category:** `RECONNAISSANCE` | **Confidence:** `MEDIUM` | **Risk Score:** `50`
- **Origin ASN:** `AS396982 `
- **Traffic Velocity:** `16` total requests (Peak: `16` req/min) | **Error Rate:** `93.8%`
- **Activity Window:** `2026-10-14T08:41:13Z` to `2026-10-14T08:41:18Z`
- **Cloudflare ML Attack Score:** `86`
- **Representative User-Agent:** `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36`
- **Primary Threat Reasons:** 14 distinct probe paths; 94% error responses (probe storm)
- **Enforcement Recommendation:** **Add to Cloudflare WAF Custom Rule (Action: Managed Challenge)**

---

## 5. Sensitive Endpoints Returning Edge 2xx (Exposure Audit)

> [!NOTE]
> **Zero Sensitive Exposures**: No sensitive configuration files, credentials, or administrative paths returned an Edge 2xx response in this dataset.

---

## 7. Perimeter Traffic & Reconnaissance Intelligence

### A. HTTP Status Code Distribution
| Status Code | Response Count | Percentage |
|---:|---:|---:|
| `200` | 20 | 8.3% |
| `301` | 71 | 29.6% |
| `302` | 8 | 3.3% |
| `401` | 23 | 9.6% |
| `403` | 33 | 13.8% |
| `404` | 65 | 27.1% |
| `503` | 3 | 1.2% |
| `522` | 4 | 1.7% |
| `530` | 13 | 5.4% |

### B. Top Target Hostnames

| Hostname | Request Count | Share |
|---|---:|---:|
| `cdn-speakit-avatar.mohitur.com:443` | 48 | 20.0% |
| `cdn-speakit-avatar.mohitur.com:80` | 48 | 20.0% |
| `speakit-prod-api.mohitur.com` | 24 | 10.0% |
| `editor.mohitur.com` | 16 | 6.7% |
| `cdn-public-document.mohitur.com` | 15 | 6.2% |
| `cdn-speakit-avatar.mohitur.com` | 15 | 6.2% |
| `portfolio.mohitur.com` | 14 | 5.8% |
| `coolify.mohitur.com` | 13 | 5.4% |
| `mohitur.com` | 11 | 4.6% |
| `speakit-dev.mohitur.com` | 11 | 4.6% |

### C. Top Client Autonomous Systems (ASNs)

| ASN | Request Count | Share |
|---|---:|---:|
| `215599` | 102 | 42.5% |
| `396982` | 63 | 26.2% |
| `16509` | 11 | 4.6% |
| `403005` | 10 | 4.2% |
| `204997` | 9 | 3.8% |
| `218785` | 6 | 2.5% |
| `36459` | 5 | 2.1% |
| `36352` | 5 | 2.1% |
| `8075` | 5 | 2.1% |
| `15169` | 4 | 1.7% |

### D. Top Source IP Addresses

| Client IP | Request Count | Share |
|---|---:|---:|
| `2a0c:b641:b0:a1a1:21c4::1` | 102 | 42.5% |
| `34.71.174.127` | 16 | 6.7% |
| `216.73.216.94` | 11 | 4.6% |
| `2a06:98c0:3600::103` | 11 | 4.6% |
| `46.151.182.148` | 10 | 4.2% |
| `185.218.86.21` | 6 | 2.5% |
| `107.172.58.36` | 5 | 2.1% |
| `2409:40e0:38:b1d1:8000::` | 4 | 1.7% |
| `205.210.31.161` | 2 | 0.8% |
| `45.139.104.172` | 2 | 0.8% |
| `147.185.132.118` | 2 | 0.8% |
| `170.64.198.90` | 2 | 0.8% |
| `51.8.102.221` | 2 | 0.8% |
| `68.183.232.153` | 2 | 0.8% |
| `198.235.24.179` | 2 | 0.8% |

---

## 8. Enterprise Hardening & Remediation Checklist

- [ ] **Deploy WAF Custom Rule**: Add the BLOCK expression from Section 2 to Cloudflare WAF Custom Rules.
- [ ] **Deploy Managed Challenge Rule**: Add the CHALLENGE expression to challenge anomalous probe networks.
- [ ] **Origin Lock (Authenticated Origin Pulls / Tunnel)**: Ensure origins reject direct IP hits and only accept traffic from Cloudflare IPs.
- [ ] **Origin 404 Hardening**: Ensure sensitive files (`.env`, `.git`, `.aws`, backups) return hard 404/403 at origin rather than routing to `index.html` (SPA fallback).
- [ ] **Enable Cloudflare Bot Fight Mode**: Suppress automated zero-day bot probes at the edge.
- [ ] **Schedule Recurring Audit**: Run `logpush-fetcher.py` and `log-security-auditor.py` weekly to refresh threat intelligence.
