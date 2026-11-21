#!/usr/bin/env python3
"""
Cloudflare Security / Exposure Auditor  (v2)

What it does
------------
1. Streams a Cloudflare HTTP-requests CSV and finds sensitive-path probes
   (.env, .git, backups, actuator, wp-*, ...) that got an edge 2xx.
2. Scores every client IP (IPv6 grouped by /64) for abusive behaviour and
   suggests which to BLOCK, which to MANAGED-CHALLENGE, and which to WATCH.
3. Optionally verifies suspicious 2xx URLs live (read-only GET, no exploit
   payloads, no redirects followed, public hostnames only).
4. Writes ready-to-use Cloudflare artifacts:
     blocklist_ips.txt            one IP/CIDR per line (BLOCK tier)
     challenge_ips.txt            one IP/CIDR per line (CHALLENGE tier)
     cloudflare_list_import.csv   "ip,comment" - dashboard list CSV upload
     waf_rules.txt                `ip.src in {...}` expressions (<4096 chars each)
     ip_suggestions.csv / .json   full scoring + reasons for review
     cloudflare-security-report.md / .json   exposure report
5. Optionally pushes the BLOCK tier into a Cloudflare IP List via API
   (dry-run unless --apply is given).

Safety / production notes
-------------------------
- Suggestions are NOT auto-applied. Review first. Use a Cloudflare IP List +
  one WAF rule, so you can remove entries instantly.
- Non-public IPs, your allow-listed IPs/CIDRs/ASNs, and reverse-DNS-verified
  Googlebot/Bingbot/Applebot are never suggested.
- Rate alone never earns a BLOCK (only CHALLENGE); BLOCK needs scanner intent
  (probe paths, scanner UA, or a fake search-engine bot).
- Live checks: GET only, redirects NOT followed, hostname must resolve to
  public IPs, body read capped, TLS verification on, rate-limited.
- The API token is read from the environment only and never logged.

Usage
-----
python3 cloudflare_security_auditor.py logs.csv
python3 cloudflare_security_auditor.py logs.csv --allow-ip 203.0.113.7 --allow-ip-file office_ips.txt
python3 cloudflare_security_auditor.py logs.csv --live --allow-suffix mohitur.com
python3 cloudflare_security_auditor.py logs.csv --push-list            # dry run
python3 cloudflare_security_auditor.py logs.csv --push-list --apply    # really push

Env for --push-list:
  CF_API_TOKEN   token with "Account > Account Filter Lists > Edit"
  CF_ACCOUNT_ID  your account id
  CF_LIST_ID     id of an existing IP list (Manage Account > Configurations > Lists)

Dependency:  python3 -m pip install requests
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import html
import ipaddress
import json
import logging
import os
import re
import socket
import sys
import time
from collections import Counter
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, Iterator, List, Optional, Set, Tuple
from urllib.parse import urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

log = logging.getLogger("cf-auditor")

# --------------------------------------------------------------------------
# Patterns
# --------------------------------------------------------------------------

# Zero-tolerance high-severity weaponized / credential targets (direct malicious intent)
HIGH_RISK_PATH_PATTERNS = [
    r"(^|/)\.env(?:[.\-_]|\b|$)",
    r"(^|/)\.git(?:/|$)",
    r"(^|/)\.aws(?:/|$)",
    r"(^|/)\.ssh(?:/|$)",
    r"(^|/)(?:service-account|credentials?|secrets?)\.json$",
    r"(^|/)(?:wp-config\.php|wp-config\.php~|\.env\.backup|\.env\.old|\.env\.orig|\.env\.php)",
    r"(^|/)actuator/(?:env|heapdump|threaddump|configprops)",
    r"(^|/)(?:phpinfo|server-status|server-info)",
    r"(^|/)(?:database|dump|backup)[^/]*\.(?:sql|tar|gz|zip|bak)",
    r"(^|/)(?:eval-stdin|setup\.cgi|boaform|HNAP1|shell)",
    r"(^|/)(?:id_rsa|id_ed25519)",
    r"(^|/)wp-json/gravitysmtp/",
]

SENSITIVE_PATH_PATTERNS = [
    r"(^|/)\.env(?:\b|[.\-_])",
    r"(^|/)\.git(?:/|$)",
    r"(^|/)\.svn(?:/|$)",
    r"(^|/)\.hg(?:/|$)",
    r"(^|/)\.ssh(?:/|$)",
    r"(^|/)aws(?:\.env|/credentials|/config)(?:/|$)",
    r"(^|/)\.aws(?:/|$)",
    r"(^|/)(?:credentials?|secrets?|secret[_\-]?(?:key|token|config))(?:\.[a-z0-9._-]+)?$",
    r"(^|/)(?:database|db)[._-]?(?:dump|backup)?\.sql$",
    r"(^|/)(?:backup|dump|database)[^/]*\.(?:zip|tar|tgz|gz|7z|bak|sql)$",
    r"(^|/)(?:docker-compose|compose)\.(?:ya?ml)$",
    r"(^|/)(?:id_rsa|id_ed25519|known_hosts)$",
    r"(^|/)(?:npmrc|pypirc|netrc)$",
    r"(^|/)(?:phpinfo|server-status|server-info)$",
    r"(^|/)(?:actuator/(?:env|heapdump|threaddump|configprops)|_profiler|telescope/requests)",
    r"(^|/)(?:wp-config\.php|wp-login\.php|xmlrpc\.php|wp-json(?:/|$))",
    r"(^|/)(?:api/.env|api/config|api/credentials|api/secrets)",
    r"(^|/)(?:\.vscode/sftp\.json|\.circleci/|\.github/workflows/)",
    r"(^|/)(?:package-lock\.json|yarn\.lock)$",
]

# Extra scanner-only paths: used for IP scoring (not for the 2xx exposure list).
SCANNER_PATH_PATTERNS = [
    r"(^|/)(?:wp-admin|wp-content/plugins|wp-includes)(?:/|$)",
    r"(^|/)(?:phpmyadmin|pma|myadmin|adminer)(?:\.php)?(?:/|$)",
    r"(^|/)cgi-bin(?:/|$)",
    r"(^|/)vendor/phpunit",
    r"(^|/)(?:boaform|HNAP1|setup\.cgi|shell|eval-stdin\.php|console)(?:/|$)",
    r"(^|/)\.DS_Store$",
    r"(^|/)(?:config\.json|config\.php|settings\.py|web\.config|appsettings\.json)$",
    r"(^|/)(?:solr|jenkins|manager/html|struts|owa|ecp)(?:/|$)",
    r"(^|/)actuator(?:/|$)",
    r"\.(?:php|asp|aspx|jsp|cgi)$",
    r"(\.\./|%2e%2e|%00)",
]

SENSITIVE_TOKENS = (
    ".env", ".git", ".svn", ".ssh", "credentials", "secret", "backup",
    "database", "dump", "id_rsa", "id_ed25519", "docker-compose",
    "wp-config", "phpinfo", "server-status", "actuator/env",
    "_profiler", "sftp.json",
)

_HIGH_RISK_RE = [re.compile(p, re.I) for p in HIGH_RISK_PATH_PATTERNS]
_SENSITIVE_RE = [re.compile(p) for p in SENSITIVE_PATH_PATTERNS]
_SCANNER_RE = [re.compile(p, re.I) for p in SCANNER_PATH_PATTERNS]

SCANNER_UA_RE = re.compile(
    r"(sqlmap|nikto|nmap|masscan|zgrab|nuclei|gobuster|dirbuster|dirb|wpscan|"
    r"acunetix|nessus|openvas|burp|havij|fimap|jaeles|httpx|feroxbuster|ffuf|"
    r"censys|netsystemsresearch|l9explore|l9tcpid|libwww-perl|masscan)",
    re.I,
)

RESEARCH_UA_RE = re.compile(
    r"(securityresearch|palo alto networks|cortex-xpanse|shodan|censys|shadowserver|netcraft)",
    re.I,
)

# Detect future/impossible browser signatures (common in malicious automated fuzzers)
FAKE_BROWSER_UA_RE = re.compile(
    r"Chrome/14[5-9]\.|Chrome/1[5-9][0-9]\.",
    re.I,
)

# Known legitimate webhook providers (guarantees zero false positives on production webhooks)
KNOWN_WEBHOOK_RULES = [
    (re.compile(r"^GitHub-Hookshot/", re.I), "36459", "GitHub Webhook"),
    (re.compile(r"^Stripe/", re.I), "", "Stripe Webhook"),
    (re.compile(r"^PayPal/", re.I), "", "PayPal Webhook"),
    (re.compile(r"^Razorpay/", re.I), "", "Razorpay Webhook"),
]

# Search-engine bots we can verify by reverse+forward DNS.
BOT_CLAIMS = {
    "googlebot": (".googlebot.com", ".google.com"),
    "bingbot": (".search.msn.com",),
    "applebot": (".applebot.apple.com",),
}

MITIGATED_ACTIONS = {
    "block", "challenge", "managed_challenge", "js_challenge",
    "jschallenge", "legacy_captcha", "challenge_solved_fail",
}

SECRET_PATTERNS: List[Tuple[str, re.Pattern[str]]] = [
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("AWS secret key", re.compile(r"(?i)\baws_secret_access_key\s*=\s*[^\s]+")),
    ("Private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b")),
    ("GitLab token", re.compile(r"\bglpat-[A-Za-z0-9\-_]{15,}\b")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z\-_]{20,}\b")),
    ("JWT", re.compile(r"\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b")),
    ("Database URL", re.compile(r"(?i)\b(?:postgres(?:ql)?|mysql|mariadb|mongodb(?:\+srv)?|redis)://[^\s\"']+")),
    ("Generic secret assignment", re.compile(
        r"(?i)\b(?:password|passwd|secret|secret_key|api_key|access_token|client_secret|private_key)\b"
        r"\s*[:=]\s*[\"']?[^\"'\s]{8,}"
    )),
]

SQL_MARKERS = ("CREATE TABLE", "INSERT INTO", "CREATE DATABASE", "DROP TABLE")
CREDENTIAL_MARKERS = (
    "DATABASE_URL", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    "SECRET_KEY", "JWT_SECRET", "API_KEY", "PRIVATE_KEY",
)
FALLBACK_MARKERS = (
    "<!doctype html", "<html", "<head", "<body", 'id="root"', 'id="app"',
    "__next_data__", "window.__", "vite", "webpackjsonp", "ng-version", "reactroot",
)
CLOUDFLARE_CHALLENGE_MARKERS = (
    "just a moment...", "cf-chl-", "challenge-platform", "enable javascript and cookies",
)

DEFAULT_BROWSER_UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/140.0 Safari/537.36"
)
DEFAULT_CRAWLER_UA = "Mozilla/5.0 (compatible; SecurityExposureAudit/2.0)"

SUSPECT_METHODS = {"GET", "HEAD"}
MAX_BODY_INSPECTION = 1_500_000
DEFAULT_TIMEOUT = 12
MAX_PROBE_PATHS_TRACKED = 500

# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------


def normalize_path(path: str) -> str:
    path = (path or "/").strip()
    return path if path.startswith("/") else "/" + path


def safe_host(host: str) -> str:
    return (host or "").strip().lower().rstrip(".")


def sanitize_ua(ua: str) -> str:
    ua = re.sub(r"[^\x20-\x7e]", "", ua or "")[:200]
    return ua or DEFAULT_BROWSER_UA


def get_val(row: Dict[str, str], *keys: str, default: str = "") -> str:
    """Case-tolerant / multi-alias dictionary lookup for Cloudflare CSVs."""
    for k in keys:
        if k in row and row[k] is not None:
            v = str(row[k]).strip()
            if v != "":
                return v
    return default


def url_from_row(row: Dict[str, str]) -> Optional[str]:
    host = safe_host(get_val(row, "ClientRequestHost", "clientRequestHTTPHost", "EdgeRequestHost", "host"))
    path = normalize_path(get_val(row, "ClientRequestPath", "clientRequestPath", "ClientRequestURI", "path", default="/"))
    scheme = get_val(row, "ClientRequestScheme", "clientRequestScheme", "scheme", default="https").strip().lower()
    if not host:
        return None
    if scheme not in {"http", "https"}:
        scheme = "https"
    return f"{scheme}://{host}{path}"


def is_public_hostname(host: str) -> bool:
    """Hostname only (no IP literal / port / userinfo) and resolves to public IPs."""
    if not host or "/" in host or "@" in host or ":" in host:
        return False
    if re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", host):
        return False
    try:
        infos = socket.getaddrinfo(host, None)
    except socket.gaierror:
        return False
    for info in infos:
        try:
            if not ipaddress.ip_address(info[4][0]).is_global:
                return False
        except ValueError:
            return False
    return bool(infos)


def path_is_sensitive(path: str) -> bool:
    p = path.lower()
    return any(t in p for t in SENSITIVE_TOKENS) or any(r.search(p) for r in _SENSITIVE_RE)


def path_is_high_risk(path: str) -> bool:
    """Zero-tolerance weaponized exploit or credential target detection."""
    p = path.lower()
    return any(r.search(p) for r in _HIGH_RISK_RE)


def path_is_probe(path: str) -> bool:
    p = path.lower()
    return path_is_high_risk(p) or path_is_sensitive(p) or any(r.search(p) for r in _SCANNER_RE)


def csv_status(row: Dict[str, str], *field_names: str) -> Optional[int]:
    """Parse integer HTTP status code checking primary and fallback column aliases."""
    for name in field_names:
        val = row.get(name)
        if val is not None and str(val).strip() != "":
            try:
                return int(str(val).strip())
            except (ValueError, TypeError):
                continue
    return None


def iter_rows(log_path: Path) -> Iterator[Dict[str, Any]]:
    """Stream rows from CSV, JSONL, or gzip archives transparently without fitting large logs into memory."""
    csv.field_size_limit(min(sys.maxsize, 2**31 - 1))
    is_gz = log_path.name.endswith(".gz")
    opener = gzip.open if is_gz else open
    mode = "rt" if is_gz else "r"

    with opener(log_path, mode, encoding="utf-8-sig", errors="replace") as f:
        # Check first non-empty line to auto-detect JSONL vs CSV
        pos = f.tell() if hasattr(f, "tell") else None
        first_line = ""
        while True:
            first_line = f.readline()
            if first_line == "" or first_line.strip() != "":
                break

        if not first_line:
            return

        stripped = first_line.strip()
        # JSONL format check
        if stripped.startswith("{") and stripped.endswith("}"):
            try:
                first_obj = json.loads(stripped)
                if isinstance(first_obj, dict):
                    yield first_obj
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                yield json.loads(line)
                            except Exception:
                                continue
                    return
            except Exception:
                pass

        # CSV format fallback: reset to beginning and stream via DictReader
        if hasattr(f, "seek"):
            f.seek(0)
        else:
            # Reopen if stream couldn't seek
            with opener(log_path, mode, encoding="utf-8-sig", errors="replace") as f_csv:
                yield from csv.DictReader(f_csv)
            return

        yield from csv.DictReader(f)


def parse_ip(value: str) -> Optional[ipaddress._BaseAddress]:
    try:
        return ipaddress.ip_address((value or "").strip())
    except ValueError:
        return None


def ip_key(ip: ipaddress._BaseAddress) -> str:
    """IPv4 as-is; IPv6 grouped by /64 (attackers rotate inside a /64)."""
    if ip.version == 6:
        return str(ipaddress.ip_network(f"{ip}/64", strict=False))
    return str(ip)


def redact_excerpt(text: str, limit: int = 240) -> str:
    text = re.sub(r"(?i)(password|passwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)"
                  r"\s*[:=]\s*[\"']?[^\"'\s,;]+", r"\1=[REDACTED]", text)
    text = re.sub(r"\bAKIA[0-9A-Z]{16}\b", "AKIA[REDACTED]", text)
    text = re.sub(r"(?i)aws_secret_access_key\s*=\s*[^\s]+", "aws_secret_access_key=[REDACTED]", text)
    text = re.sub(r"-----BEGIN .*?PRIVATE KEY-----.*?-----END .*?PRIVATE KEY-----",
                  "[PRIVATE KEY REDACTED]", text, flags=re.S)
    return re.sub(r"\s+", " ", text).strip()[:limit]


# --------------------------------------------------------------------------
# Per-IP scoring
# --------------------------------------------------------------------------


@dataclass
class IPStats:
    key: str
    ip: str  # representative address (used for rDNS)
    asn: str = ""
    asn_name: str = ""
    requests: int = 0
    errors: int = 0
    mitigated: int = 0
    sensitive: int = 0
    sensitive_2xx: int = 0
    scanner_ua: bool = False
    research_ua: bool = False
    fake_ua: bool = False
    empty_ua: bool = False
    is_known_webhook: bool = False
    webhook_name: str = ""
    bot_claim: str = ""
    first_seen: str = ""
    last_seen: str = ""
    high_risk_probes: Set[str] = field(default_factory=set)
    probe_paths: Set[str] = field(default_factory=set)
    hosts_probed: Set[str] = field(default_factory=set)
    waf_attack_scores: List[int] = field(default_factory=list)
    waf_rce_scores: List[int] = field(default_factory=list)
    waf_sqli_scores: List[int] = field(default_factory=list)
    waf_xss_scores: List[int] = field(default_factory=list)
    user_agents: Counter = field(default_factory=Counter)
    minute_counts: Counter = field(default_factory=Counter)

    @property
    def peak_per_min(self) -> int:
        return max(self.minute_counts.values()) if self.minute_counts else 0

    @property
    def min_waf_score(self) -> Optional[int]:
        return min(self.waf_attack_scores) if self.waf_attack_scores else None


@dataclass
class IPSuggestion:
    ip: str
    tier: str  # BLOCK, CHALLENGE, WATCH
    decision: str  # Industry-standard decision code (e.g. BLOCK_CREDENTIAL_PROBING)
    confidence: str  # HIGH, MEDIUM, LOW
    risk_category: str  # CREDENTIAL_ACCESS, VULNERABILITY_RECON, EXPLOIT_ATTEMPT, RATE_ABUSE, etc.
    score: int
    requests: int
    peak_per_min: int
    probe_paths: int
    high_risk_probes: int
    hosts_probed: int
    sensitive_2xx: int
    error_ratio: float
    mitigated_ratio: float
    waf_min_score: str
    asn: str
    asn_name: str
    first_seen: str
    last_seen: str
    reasons: str
    recommended_action: str
    sample_user_agent: str
    note: str = ""


@dataclass
class Thresholds:
    block: int = 70
    challenge: int = 40
    watch: int = 25
    rate: int = 120
    min_requests: int = 5


def score_ip(
    s: IPStats, th: Thresholds, bot_status: str
) -> Tuple[int, List[str], str, str, str, str, str]:
    """
    Industry-grade multi-vector risk evaluation matching enterprise SOC / WAF decision engines.
    Returns:
      (score, reasons, tier, decision, confidence, risk_category, recommended_action)
    """
    score = 0
    reasons: List[str] = []
    has_malicious_intent = False
    risk_category = "RECONNAISSANCE"

    # 1. Zero-tolerance High-Risk Credential & Weaponized Probes
    num_high_risk = len(s.high_risk_probes)
    if num_high_risk >= 5:
        score += 65
        reasons.append(f"{num_high_risk} high-severity credential/exploit paths probed")
        has_malicious_intent = True
        risk_category = "CREDENTIAL_ACCESS"
    elif num_high_risk >= 2:
        score += 45
        reasons.append(f"{num_high_risk} high-severity credential/exploit paths probed")
        has_malicious_intent = True
        risk_category = "CREDENTIAL_ACCESS"
    elif num_high_risk == 1:
        score += 30
        reasons.append("high-severity credential/exploit path probed")
        has_malicious_intent = True
        risk_category = "CREDENTIAL_ACCESS"

    # 2. Distinct Probe Paths (Broad Scanner Fingerprint)
    d = len(s.probe_paths)
    if d >= 20:
        score += 40
        reasons.append(f"{d} distinct probe paths (broad surface attack)")
        has_malicious_intent = True
    elif d >= 10:
        score += 30
        reasons.append(f"{d} distinct probe paths")
        has_malicious_intent = True
    elif d >= 3:
        score += 20
        reasons.append(f"{d} distinct probe paths")
        has_malicious_intent = True
    elif d >= 1:
        score += 10
        reasons.append(f"{d} probe path(s)")

    # 3. Multi-Host Perimeter Scan (Horizontal Reconnaissance across domains/subdomains)
    if len(s.hosts_probed) >= 3:
        score += 25
        reasons.append(f"perimeter scan across {len(s.hosts_probed)} hostnames")
        has_malicious_intent = True
    elif len(s.hosts_probed) == 2:
        score += 15
        reasons.append("cross-domain scan across 2 hostnames")

    # 4. Sensitive Paths Answering 2xx
    if s.sensitive_2xx:
        score += 15
        reasons.append(f"{s.sensitive_2xx} sensitive path(s) answered 2xx")

    # 5. User-Agent Fingerprint & Anomalies
    if s.scanner_ua:
        score += 40
        reasons.append("known offensive scanner user-agent")
        has_malicious_intent = True
        if risk_category == "RECONNAISSANCE":
            risk_category = "AUTOMATED_SCANNER"
    elif s.fake_ua:
        score += 25
        reasons.append("spoofed future browser signature (Chrome 148+)")
        has_malicious_intent = True
        if risk_category == "RECONNAISSANCE":
            risk_category = "SPOOFED_BOT"
    elif s.research_ua:
        score += 20
        reasons.append("security research scanner probing endpoints")
        if risk_category == "RECONNAISSANCE":
            risk_category = "RESEARCH_SCANNER"
    elif s.empty_ua:
        score += 10
        reasons.append("empty user-agent")

    # 6. Spoofed Search Engine Bot
    if bot_status == "fake":
        score += 50
        reasons.append("spoofed search engine crawler (failed rDNS/fDNS validation)")
        has_malicious_intent = True
        risk_category = "SPOOFED_BOT"

    # 7. Cloudflare Native ML WAF Threat Scores
    min_waf = s.min_waf_score
    if min_waf is not None:
        if min_waf <= 20:
            score += 40
            reasons.append(f"Cloudflare ML WAF high attack confidence (score {min_waf})")
            has_malicious_intent = True
            risk_category = "EXPLOIT_ATTEMPT"
        elif min_waf <= 50:
            score += 20
            reasons.append(f"Cloudflare ML WAF elevated threat score ({min_waf})")

    # 8. Error Storm (4xx/5xx probing density)
    if s.requests >= 10 and (s.errors / s.requests) >= 0.8:
        score += 20
        reasons.append(f"{s.errors / s.requests:.0%} error responses (probe storm)")

    # 9. Request Rate Anomalies
    peak = s.peak_per_min
    if peak >= th.rate * 2.5:
        score += 45
        reasons.append(f"peak rate spike of {peak} req/min")
        if not has_malicious_intent:
            risk_category = "RATE_ABUSE"
    elif peak >= th.rate:
        score += 30
        reasons.append(f"peak rate of {peak} req/min")
        if not has_malicious_intent:
            risk_category = "RATE_ABUSE"

    # 10. Prior Cloudflare Mitigation Ratio
    if s.requests and (s.mitigated / s.requests) >= 0.5:
        score += 15
        reasons.append("previously mitigated by Cloudflare edge")

    # Enterprise Production Decision Matrix:
    # BLOCK:
    # - Score >= th.block WITH malicious intent (credential access, weaponized paths, offensive tools, fake bots), OR
    # - >= 3 distinct high-risk credential/exploit paths probed (zero-tolerance block), OR
    # - Fake search engine bot
    if (score >= th.block and has_malicious_intent) or num_high_risk >= 3 or bot_status == "fake":
        tier = "BLOCK"
        confidence = "HIGH" if (score >= 80 or num_high_risk >= 3 or bot_status == "fake") else "MEDIUM"
        if num_high_risk >= 2:
            decision = "BLOCK_CREDENTIAL_PROBING"
        elif s.scanner_ua:
            decision = "BLOCK_OFFENSIVE_SCANNER"
        elif bot_status == "fake":
            decision = "BLOCK_SPOOFED_BOT"
        elif d >= 5:
            decision = "BLOCK_VULNERABILITY_SCAN"
        else:
            decision = "BLOCK_MALICIOUS_THREAT"
        action = "Add to Cloudflare IP Access Rules (Action: Block) or WAF Custom Rule"

    elif score >= th.challenge or (score >= th.block and not has_malicious_intent) or num_high_risk >= 1 or d >= 2:
        tier = "CHALLENGE"
        confidence = "HIGH" if score >= 55 else "MEDIUM"
        if not has_malicious_intent and peak >= th.rate:
            decision = "CHALLENGE_RATE_ANOMALY"
        elif s.research_ua:
            decision = "CHALLENGE_RESEARCH_SCANNER"
        elif s.fake_ua:
            decision = "CHALLENGE_SPOOFED_BROWSER"
        elif len(s.hosts_probed) >= 2:
            decision = "CHALLENGE_PERIMETER_RECON"
        else:
            decision = "CHALLENGE_SUSPICIOUS_PROBE"
        action = "Add to Cloudflare WAF Custom Rule (Action: Managed Challenge)"

    elif score >= th.watch:
        tier = "WATCH"
        confidence = "LOW"
        decision = "WATCH_PROBE_ANOMALY"
        action = "Monitor in Cloudflare Security Analytics / Logpush"
    else:
        tier = "ALLOW"
        confidence = "LOW"
        decision = "ALLOW_BENIGN"
        action = "No action required"

    return score, reasons, tier, decision, confidence, risk_category, action


class Analyzer:
    """Single streaming pass: global counters, exposure list and per-IP stats."""

    def __init__(self) -> None:
        self.total = 0
        self.hosts: Counter = Counter()
        self.paths: Counter = Counter()
        self.statuses: Counter = Counter()
        self.methods: Counter = Counter()
        self.actions: Counter = Counter()
        self.ips: Counter = Counter()
        self.asns: Counter = Counter()
        self.sensitive_request_count = 0
        self.suspicious_2xx: List[Dict[str, str]] = []
        self.suspicious_counter: Counter = Counter()
        self.ip_stats: Dict[str, IPStats] = {}
        self.skipped_non_public = 0

    def consume(self, row: Dict[str, str]) -> None:
        self.total += 1
        ip_raw = get_val(row, "ClientIP", "clientIP", "ClientRequestIP", "EdgeClientIP", "ip")
        asn = get_val(row, "ClientASN", "clientAsn", "ClientRequestASN", "asn")
        asn_name = get_val(row, "ClientASNDescription", "clientASNDescription", "asn_name")
        host = safe_host(get_val(row, "ClientRequestHost", "clientRequestHTTPHost", "EdgeRequestHost", "host"))
        path = normalize_path(get_val(row, "ClientRequestPath", "clientRequestPath", "ClientRequestURI", "path", default="/"))
        method = get_val(row, "ClientRequestMethod", "clientRequestHTTPMethodName", "method").upper()
        edge = csv_status(row, "EdgeResponseStatus", "edgeResponseStatus", "status")
        action = get_val(row, "SecurityAction", "securityAction", "SecurityActions").strip().lower()
        ua = get_val(row, "ClientRequestUserAgent", "userAgent", "ClientUserAgent", "user_agent")
        dt = get_val(row, "EdgeStartTimestamp", "datetime", "EdgeEndTimestamp", "timestamp")

        if ip_raw:
            self.ips[ip_raw] += 1
        if asn:
            self.asns[asn] += 1
        if host:
            self.hosts[host] += 1
        self.paths[path] += 1
        if edge is not None:
            self.statuses[str(edge)] += 1
        if method:
            self.methods[method] += 1
        if action:
            self.actions[action] += 1

        sensitive = path_is_sensitive(path)
        probe = sensitive or path_is_probe(path)
        is_2xx = edge is not None and 200 <= edge <= 299

        if sensitive:
            self.sensitive_request_count += 1
        if sensitive and is_2xx:
            self.suspicious_counter[(host, path)] += 1
            if len(self.suspicious_2xx) < 5000:
                self.suspicious_2xx.append({
                    "datetime": dt, "clientIP": ip_raw, "clientAsn": asn,
                    "clientASNDescription": asn_name, "host": host, "method": method,
                    "path": path, "edgeResponseStatus": str(edge or ""),
                    "originResponseStatus": get_val(row, "OriginResponseStatus", "originResponseStatus"),
                    "securityAction": action,
                    "userAgent": ua,
                })

        # ---- per-IP stats
        ip = parse_ip(ip_raw)
        if ip is None:
            return
        if not ip.is_global:
            self.skipped_non_public += 1
            return
        key = ip_key(ip)
        s = self.ip_stats.get(key)
        if s is None:
            s = self.ip_stats[key] = IPStats(key=key, ip=str(ip), asn=asn, asn_name=asn_name)
        s.requests += 1
        if edge is not None and edge >= 400:
            s.errors += 1
        if action in MITIGATED_ACTIONS:
            s.mitigated += 1
        if probe:
            if len(s.probe_paths) < MAX_PROBE_PATHS_TRACKED:
                s.probe_paths.add(path)
            s.hosts_probed.add(host)
        if path_is_high_risk(path):
            if len(s.high_risk_probes) < MAX_PROBE_PATHS_TRACKED:
                s.high_risk_probes.add(path)
        if sensitive and is_2xx:
            s.sensitive_2xx += 1

        # Check known legitimate webhooks to prevent false-positive blocks
        for pat, asn_target, desc in KNOWN_WEBHOOK_RULES:
            if pat.search(ua) or (asn_target and asn == asn_target and "webhook" in path.lower()):
                s.is_known_webhook = True
                s.webhook_name = desc
                break

        # Cloudflare ML WAF scores
        waf_atk = csv_status(row, "WAFAttackScore", "wafAttackScore")
        if waf_atk is not None:
            s.waf_attack_scores.append(waf_atk)
        waf_rce = csv_status(row, "WAFRCEAttackScore", "wafRCEAttackScore")
        if waf_rce is not None:
            s.waf_rce_scores.append(waf_rce)
        waf_sqli = csv_status(row, "WAFSQLiAttackScore", "wafSQLiAttackScore")
        if waf_sqli is not None:
            s.waf_sqli_scores.append(waf_sqli)
        waf_xss = csv_status(row, "WAFXSSAttackScore", "wafXSSAttackScore")
        if waf_xss is not None:
            s.waf_xss_scores.append(waf_xss)

        if not ua.strip():
            s.empty_ua = True
        else:
            if SCANNER_UA_RE.search(ua):
                s.scanner_ua = True
            if RESEARCH_UA_RE.search(ua):
                s.research_ua = True
            if FAKE_BROWSER_UA_RE.search(ua):
                s.fake_ua = True
            low = ua.lower()
            for bot in BOT_CLAIMS:
                if bot in low:
                    s.bot_claim = bot
            if len(s.user_agents) < 20:
                s.user_agents[ua[:160]] += 1
        if dt:
            s.minute_counts[dt[:16]] += 1
            if not s.first_seen or dt < s.first_seen:
                s.first_seen = dt
            if dt > s.last_seen:
                s.last_seen = dt

    def summary(self) -> Dict[str, object]:
        top_suspicious = [
            {"host": h, "path": p, "count": c}
            for (h, p), c in self.suspicious_counter.most_common(100)
        ]
        return {
            "total_requests": self.total,
            "unique_ips": len(self.ips),
            "unique_asns": len(self.asns),
            "unique_hosts": len(self.hosts),
            "unique_paths": len(self.paths),
            "top_ips": self.ips.most_common(30),
            "top_asns": self.asns.most_common(30),
            "top_hosts": self.hosts.most_common(30),
            "top_paths": self.paths.most_common(50),
            "status_counts": self.statuses,
            "method_counts": self.methods,
            "security_actions": self.actions,
            "sensitive_request_count": self.sensitive_request_count,
            "sensitive_2xx_count": len(self.suspicious_2xx),
            "suspicious_2xx": self.suspicious_2xx,
            "top_suspicious": top_suspicious,
            "non_public_ips_ignored": self.skipped_non_public,
        }


# --------------------------------------------------------------------------
# Allow-lists and bot verification
# --------------------------------------------------------------------------


def load_allowlist(ips: List[str], files: List[Path]) -> List[ipaddress._BaseNetwork]:
    nets: List[ipaddress._BaseNetwork] = []
    entries = list(ips)
    for f in files:
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                entries.append(line)
    for e in entries:
        try:
            nets.append(ipaddress.ip_network(e, strict=False))
        except ValueError:
            log.warning("Ignoring invalid allow-list entry: %r", e)
    return nets


def in_allowlist(ip_str: str, nets: List[ipaddress._BaseNetwork]) -> bool:
    ip = parse_ip(ip_str)
    return bool(ip) and any(ip in n for n in nets if n.version == ip.version)


def verify_search_bot(ip: str, bot: str) -> bool:
    """Reverse DNS must end with the bot's domain AND forward-resolve back to the IP."""
    suffixes = BOT_CLAIMS.get(bot)
    if not suffixes:
        return False
    try:
        host = socket.gethostbyaddr(ip)[0].lower().rstrip(".")
        if not host.endswith(suffixes):
            return False
        forward = {ai[4][0] for ai in socket.getaddrinfo(host, None)}
        return ipaddress.ip_address(ip) in {ipaddress.ip_address(x) for x in forward}
    except (socket.herror, socket.gaierror, socket.timeout, OSError, ValueError):
        return False


def build_suggestions(
    stats: Dict[str, IPStats],
    th: Thresholds,
    allow_nets: List[ipaddress._BaseNetwork],
    allow_asns: Set[str],
    verify_bots: bool,
    max_block: int,
) -> List[IPSuggestion]:
    socket.setdefaulttimeout(3)
    out: List[IPSuggestion] = []

    for s in stats.values():
        if s.requests < th.min_requests:
            continue
        if s.is_known_webhook:
            # Never suggest blocking verified webhooks (e.g. GitHub Hookshot)
            continue
        if in_allowlist(s.ip, allow_nets) or str(s.asn) in allow_asns:
            continue

        bot_status = ""
        if s.bot_claim in BOT_CLAIMS:
            if verify_bots:
                bot_status = "verified" if verify_search_bot(s.ip, s.bot_claim) else "fake"
            else:
                bot_status = ""
            if bot_status == "verified":
                continue  # genuine Googlebot/Bingbot/Applebot: never suggest

        score, reasons, tier, decision, confidence, risk_category, action = score_ip(s, th, bot_status)
        if tier not in {"BLOCK", "CHALLENGE", "WATCH"}:
            continue

        note = ""
        if tier == "BLOCK" and s.requests and s.mitigated / s.requests >= 0.95:
            note = "Already ~fully mitigated by Cloudflare edge; blocking reduces origin load & log noise."

        waf_display = str(s.min_waf_score) if s.min_waf_score is not None else "N/A"

        out.append(IPSuggestion(
            ip=s.key,
            tier=tier,
            decision=decision,
            confidence=confidence,
            risk_category=risk_category,
            score=score,
            requests=s.requests,
            peak_per_min=s.peak_per_min,
            probe_paths=len(s.probe_paths),
            high_risk_probes=len(s.high_risk_probes),
            hosts_probed=len(s.hosts_probed),
            sensitive_2xx=s.sensitive_2xx,
            error_ratio=round(s.errors / s.requests, 3),
            mitigated_ratio=round(s.mitigated / s.requests, 3),
            waf_min_score=waf_display,
            asn=str(s.asn),
            asn_name=s.asn_name,
            first_seen=s.first_seen,
            last_seen=s.last_seen,
            reasons="; ".join(reasons),
            recommended_action=action,
            sample_user_agent=(s.user_agents.most_common(1)[0][0] if s.user_agents else ""),
            note=note,
        ))

    order = {"BLOCK": 0, "CHALLENGE": 1, "WATCH": 2}
    out.sort(key=lambda x: (order[x.tier], -x.score, -x.requests))

    # Cap the BLOCK tier (Cloudflare list size limits); overflow becomes CHALLENGE.
    blocked = 0
    for sug in out:
        if sug.tier == "BLOCK":
            blocked += 1
            if blocked > max_block:
                sug.tier = "CHALLENGE"
                sug.note = "Over --max-block cap; demoted to challenge."
    return out


def suspicious_asns(sugs: List[IPSuggestion], min_ips: int = 5) -> List[Tuple[str, str, int]]:
    c: Counter = Counter()
    names: Dict[str, str] = {}
    for s in sugs:
        if s.tier in {"BLOCK", "CHALLENGE"}:
            c[s.asn] += 1
            names[s.asn] = s.asn_name
    return [(a, names[a], n) for a, n in c.most_common() if n >= min_ips and a]



# --------------------------------------------------------------------------
# Consolidated Reporting & Cloudflare WAF Formulations
# --------------------------------------------------------------------------


def chunk_expressions(ips: List[str], limit: int = 3500) -> List[str]:
    exprs, cur = [], []
    size = len("(ip.src in {})")
    for ip in ips:
        add = len(ip) + 1
        if cur and size + add > limit:
            exprs.append("(ip.src in {" + " ".join(cur) + "})")
            cur, size = [], len("(ip.src in {})")
        cur.append(ip)
        size += add
    if cur:
        exprs.append("(ip.src in {" + " ".join(cur) + "})")
    return exprs


def suspicious_asns(sugs: List[IPSuggestion], min_ips: int = 5) -> List[Tuple[str, str, int]]:
    c: Counter = Counter()
    names: Dict[str, str] = {}
    for s in sugs:
        if s.tier in {"BLOCK", "CHALLENGE"}:
            c[s.asn] += 1
            names[s.asn] = s.asn_name
    return [(a, names[a], n) for a, n in c.most_common() if n >= min_ips and a]


def write_cloudflare_artifacts(out_dir: Path, sugs: List[IPSuggestion], list_name: str) -> None:
    """Optional exporter for legacy split files when --split-files is given."""
    out_dir.mkdir(parents=True, exist_ok=True)
    block = [s for s in sugs if s.tier == "BLOCK"]
    chal = [s for s in sugs if s.tier == "CHALLENGE"]

    (out_dir / "blocklist_ips.txt").write_text("\n".join(s.ip for s in block) + ("\n" if block else ""))
    (out_dir / "challenge_ips.txt").write_text("\n".join(s.ip for s in chal) + ("\n" if chal else ""))

    with (out_dir / "cloudflare_list_import.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        for s in block:
            w.writerow([s.ip, f"[{s.decision}] score={s.score} {s.reasons}"[:250]])

    lines = [
        "## BLOCK",
    ] + (chunk_expressions([s.ip for s in block]) or ["(none)"]) + [
        "", "## MANAGED CHALLENGE",
    ] + (chunk_expressions([s.ip for s in chal]) or ["(none)"])
    (out_dir / "waf_rules.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    if sugs:
        with (out_dir / "ip_suggestions.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(asdict(sugs[0]).keys()))
            w.writeheader()
            for s in sugs:
                w.writerow(asdict(s))


def markdown_report(
    log_path: Path,
    a: Dict[str, object],
    live: List[LiveResult],
    sugs: List[IPSuggestion],
    list_name: str,
) -> str:
    """Generates a complete, single consolidated security & threat audit document."""
    statuses = a["status_counts"]
    tiers = Counter(s.tier for s in sugs)
    block = [s for s in sugs if s.tier == "BLOCK"]
    chal = [s for s in sugs if s.tier == "CHALLENGE"]
    actionable = [s for s in sugs if s.tier in {"BLOCK", "CHALLENGE"}]
    total_reqs = max(1, a["total_requests"])

    L: List[str] = [
        "# Cloudflare Consolidated Threat & Security Audit Report",
        "",
        f"> **Analyzed Log Source:** `{log_path.name}`  ",
        f"> **Report Generated:** `{time.strftime('%Y-%m-%d %H:%M:%S %z')}`  ",
        f"> **Threat Engine:** Enterprise SOC / WAF Decision Framework (v2.5)",
        "",
        "---",
        "",
        "## 1. Executive Threat Summary",
        "",
        "| Metric | Value | SOC / Risk Interpretation |",
        "|---|---:|---|",
        f"| **Total Requests Analyzed** | **{a['total_requests']:,}** | Total HTTP/HTTPS transactions inspected |",
        f"| **Unique Source IPs / Subnets** | **{a['unique_ips']:,}** | Distinct origin clients observed |",
        f"| **Sensitive Probe Requests** | **{a['sensitive_request_count']:,}** | Probes against configuration, credentials, or admin endpoints |",
        f"| **Edge 2xx Sensitive Exposures** | **{a['sensitive_2xx_count']:,}** | Sensitive paths answering with success (investigate immediately) |",
        f"| **Recommended IPs to BLOCK** | **{tiers['BLOCK']}** | High-confidence malicious intent / zero-tolerance targets |",
        f"| **Recommended IPs to CHALLENGE** | **{tiers['CHALLENGE']}** | Suspicious reconnaissance / anomalous velocity |",
        f"| **IPs on WATCH List** | **{tiers['WATCH']}** | Low-level anomalies (monitor in Security Analytics) |",
        "",
        "---",
        "",
        "## 2. Cloudflare Mitigation & WAF Custom Rules (Ready to Deploy)",
        "",
        "Deploy these rules directly in the Cloudflare Dashboard under **Security > WAF > Custom Rules** or **Security > WAF > Tools (IP Access Rules)**.",
        "",
        "### A. WAF Custom Rule: Immediate BLOCK",
        "- **Rule Action:** `Block`",
        "- **Rule Description:** `Auto-Mitigation: High Malicious Threat Probes & Credential Scanners`",
        "```cloudflare",
    ]

    block_ips = [s.ip for s in block]
    if block_ips:
        L += chunk_expressions(block_ips)
    else:
        L += ["# No IPs currently meet BLOCK criteria"]

    L += [
        "```",
        "",
        "### B. WAF Custom Rule: MANAGED CHALLENGE",
        "- **Rule Action:** `Managed Challenge`",
        "- **Rule Description:** `Auto-Mitigation: Suspicious Reconnaissance & Fuzzing Crawlers`",
        "```cloudflare",
    ]

    chal_ips = [s.ip for s in chal]
    if chal_ips:
        L += chunk_expressions(chal_ips)
    else:
        L += ["# No IPs currently meet CHALLENGE criteria"]

    L += [
        "```",
        "",
        "### C. Cloudflare IP Access List Import Format",
        "For bulk import via **Manage Account > Configurations > Lists** (IP Lists):",
        "```csv",
        "# ip,comment",
    ]
    for s in actionable:
        L.append(f"{s.ip},[{s.decision}] score={s.score} {s.reasons}"[:250])
    if not actionable:
        L.append("# No actionable IPs to export")

    L += [
        "```",
        "",
        "### D. Pure IP / CIDR Block & Challenge Lists",
        "<details>",
        "<summary><b>Click to expand pure IP lists (one per line)</b></summary>",
        "",
        "**BLOCK IPs:**",
        "```text",
    ]
    L += [s.ip for s in block] or ["(none)"]
    L += [
        "```",
        "",
        "**CHALLENGE IPs:**",
        "```text",
    ]
    L += [s.ip for s in chal] or ["(none)"]
    L += [
        "```",
        "</details>",
        "",
        "---",
        "",
        "## 3. Actionable Threat Decision Matrix",
        "",
        "| Action | Decision Code | Confidence | IP / CIDR | Risk Score | Probes (High / Total) | Origin ASN |",
        "|---|---|---|---|---:|---:|---|",
    ]

    if actionable:
        for s in actionable:
            badge = "🔴 **BLOCK**" if s.tier == "BLOCK" else "🟡 **CHALLENGE**"
            asn_label = f"AS{s.asn}"
            if s.asn_name.strip():
                asn_label += f" ({html.escape(s.asn_name.strip())[:16]})"
            L.append(
                f"| {badge} | `{s.decision}` | **{s.confidence}** | `{s.ip}` | {s.score} | "
                f"{s.high_risk_probes} / {s.probe_paths} | `{asn_label}` |"
            )
        L += [
            "",
            "> 💡 **Detailed Threat Profiles**: For complete evidence trails, targeted endpoints, and sample User-Agents for each actor, see [Section 4: Threat Actor Profiles](#4-threat-actor-profiles--targeted-endpoints) below.",
        ]
    else:
        L.append("| 🟢 **ALLOW** | `NONE` | - | No offending IPs detected | 0 | 0 / 0 | - |")

    L += [
        "",
        "---",
        "",
        "## 4. Threat Actor Profiles & Targeted Endpoints",
        "",
    ]

    if actionable:
        for s in actionable:
            badge = "🔴 **BLOCK**" if s.tier == "BLOCK" else "🟡 **CHALLENGE**"
            L += [
                f"### {badge} `{s.ip}` — {s.decision}",
                f"- **Risk Category:** `{s.risk_category}` | **Confidence:** `{s.confidence}` | **Risk Score:** `{s.score}`",
                f"- **Origin ASN:** `AS{s.asn} {html.escape(s.asn_name)}`",
                f"- **Traffic Velocity:** `{s.requests}` total requests (Peak: `{s.peak_per_min}` req/min) | **Error Rate:** `{s.error_ratio:.1%}`",
                f"- **Activity Window:** `{s.first_seen}` to `{s.last_seen}`",
                f"- **Cloudflare ML Attack Score:** `{s.waf_min_score}`",
                f"- **Representative User-Agent:** `{html.escape(s.sample_user_agent)}`",
                f"- **Primary Threat Reasons:** {s.reasons}",
                f"- **Enforcement Recommendation:** **{s.recommended_action}**",
                "",
            ]
    else:
        L += ["No threat actors identified.", ""]

    L += [
        "---",
        "",
        "## 5. Sensitive Endpoints Returning Edge 2xx (Exposure Audit)",
        "",
    ]
    s2 = a["suspicious_2xx"]
    if s2:
        L += [
            "> [!WARNING]",
            "> One or more sensitive paths answered with 2xx status codes. Verify whether these endpoints return actual secrets or if an SPA fallback is masking the response.",
            "",
            "| Timestamp | Client IP | ASN | Host | Method | Edge Status | Origin Status | Path |",
            "|---|---|---:|---|---|---:|---:|---|",
        ]
        for r in s2[:100]:
            L.append(
                f"| {r['datetime']} | `{r['clientIP']}` | `{r['clientAsn']}` | `{r['host']}` | "
                f"`{r['method']}` | `{r['edgeResponseStatus']}` | `{r['originResponseStatus']}` | `{r['path']}` |"
            )
        L.append("")
    else:
        L += [
            "> [!NOTE]",
            "> **Zero Sensitive Exposures**: No sensitive configuration files, credentials, or administrative paths returned an Edge 2xx response in this dataset.",
            "",
        ]

    if live:
        L += [
            "---",
            "",
            "## 6. Live Endpoint Verification Results",
            "",
            "| Classification | Status | Host | Path | Content-Type | Size (bytes) | Canary Match | Evidence |",
            "|---|---:|---|---|---|---:|---|---|",
        ]
        for r in live:
            ev = html.escape(r.evidence).replace("|", r"\|")
            L.append(
                f"| `{r.classification}` | `{r.status or ''}` | `{r.host}` | `{r.path}` | "
                f"`{r.content_type}` | {r.content_length or 0} | "
                f"`{'yes' if r.body_matches_canary else 'no'}` | {ev} |"
            )
        L += [
            "",
            "**Classification Guide:**",
            "- `LIKELY_EXPOSED_*`: Sensitive file actually served; remediate origin immediately.",
            "- `LIKELY_FALSE_POSITIVE_FALLBACK`: SPA fallback routing; no secret leaked.",
            "- `NOT_EXPOSED_BY_LIVE_CHECK`: Edge or origin denied request (403/404).",
            "",
        ]

    L += [
        "---",
        "",
        "## 7. Perimeter Traffic & Reconnaissance Intelligence",
        "",
        "### A. HTTP Status Code Distribution",
        "| Status Code | Response Count | Percentage |",
        "|---:|---:|---:|",
    ]
    for st, c in sorted(statuses.items(), key=lambda x: int(x[0])):
        L.append(f"| `{st}` | {c:,} | {c / total_reqs:.1%} |")
    L.append("")

    def kv(title: str, rows, key_name: str) -> None:
        L.extend([f"### {title}", "", f"| {key_name} | Request Count | Share |", "|---|---:|---:|"])
        L.extend(f"| `{k}` | {c:,} | {c / total_reqs:.1%} |" for k, c in rows)
        L.append("")

    kv("B. Top Target Hostnames", a["top_hosts"][:10], "Hostname")
    kv("C. Top Client Autonomous Systems (ASNs)", a["top_asns"][:10], "ASN")
    kv("D. Top Source IP Addresses", a["top_ips"][:15], "Client IP")

    asns = suspicious_asns(sugs)
    if asns:
        L += [
            "### E. High-Abuse Autonomous Systems (ASNs)",
            "The following ASNs generated anomalous probe concentrations. Consider challenging them entirely at the Cloudflare WAF edge:",
            "```cloudflare",
            "(ip.src.asnum in {" + " ".join(a for a, _, _ in asns) + "})",
            "```",
            "",
        ]

    L += [
        "---",
        "",
        "## 8. Enterprise Hardening & Remediation Checklist",
        "",
        "- [ ] **Deploy WAF Custom Rule**: Add the BLOCK expression from Section 2 to Cloudflare WAF Custom Rules.",
        "- [ ] **Deploy Managed Challenge Rule**: Add the CHALLENGE expression to challenge anomalous probe networks.",
        "- [ ] **Origin Lock (Authenticated Origin Pulls / Tunnel)**: Ensure origins reject direct IP hits and only accept traffic from Cloudflare IPs.",
        "- [ ] **Origin 404 Hardening**: Ensure sensitive files (`.env`, `.git`, `.aws`, backups) return hard 404/403 at origin rather than routing to `index.html` (SPA fallback).",
        "- [ ] **Enable Cloudflare Bot Fight Mode**: Suppress automated zero-day bot probes at the edge.",
        "- [ ] **Schedule Recurring Audit**: Run `logpush-fetcher.py` and `log-security-auditor.py` weekly to refresh threat intelligence.",
        "",
    ]

    return "\n".join(L)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main() -> int:
    p = argparse.ArgumentParser(description="Analyze Cloudflare HTTP logs (CSV or JSONL), score threats using industry decision logic, and recommend IPs to block.")
    p.add_argument("log_file", nargs="?", type=Path, default=None, help="Cloudflare log export path (.csv, .jsonl, or .log.gz). Auto-detects data/cloudflare_requests_log.csv or .jsonl by default.")
    p.add_argument("--out", type=Path, default=Path("reports/cloudflare-scan/log-security-auditor/cloudflare-security-report.md"), help="Target path for the consolidated markdown document (default: reports/cloudflare-scan/log-security-auditor/cloudflare-security-report.md).")
    p.add_argument("--split-files", action="store_true", help="Also generate separate legacy files (blocklist_ips.txt, waf_rules.txt, etc.) in addition to the consolidated report.")
    p.add_argument("-v", "--verbose", action="store_true")

    g = p.add_argument_group("IP suggestions")
    g.add_argument("--allow-ip", action="append", default=[], help="IP/CIDR to never suggest (repeatable)")
    g.add_argument("--allow-ip-file", action="append", type=Path, default=[], help="File with IP/CIDR per line")
    g.add_argument("--allow-asn", action="append", default=[], help="ASN number to never suggest (repeatable)")
    g.add_argument("--block-threshold", type=int, default=70)
    g.add_argument("--challenge-threshold", type=int, default=40)
    g.add_argument("--watch-threshold", type=int, default=25)
    g.add_argument("--rate-threshold", type=int, default=120, help="requests/min from one IP considered high (default 120)")
    g.add_argument("--min-requests", type=int, default=5, help="ignore IPs with fewer requests (default 5)")
    g.add_argument("--max-block", type=int, default=500, help="max IPs in BLOCK tier (default 500)")
    g.add_argument("--no-verify-bots", action="store_true", help="skip reverse-DNS check for Googlebot/Bingbot/Applebot")
    g.add_argument("--list-name", default="auditor_blocklist", help="Cloudflare list name used in rule text")
    g.add_argument("--push-list", action="store_true", help="push BLOCK tier to a Cloudflare IP list (needs env vars)")
    g.add_argument("--apply", action="store_true", help="with --push-list: actually perform the API write")

    g = p.add_argument_group("live verification")
    g.add_argument("--live", action="store_true", help="safe live GET checks for suspicious 2xx URLs")
    g.add_argument("--allow-suffix", action="append", default=[], help="only live-check hosts ending with this suffix")
    g.add_argument("--max-checks", type=int, default=100)
    g.add_argument("--delay", type=float, default=0.8)
    g.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    g.add_argument("--include-all-2xx", action="store_true")
    args = p.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S")

    # Resolve input log file (smart auto-detection)
    input_file = args.log_file
    if input_file is None:
        candidates = [
            Path("data/cloudflare_requests_log.csv"),
            Path("data/cloudflare_requests_log.jsonl"),
            Path("data/cloudflare_logs_30_days.csv"),
            Path("data/cloudflare_logs_30_days.jsonl"),
            Path("data/logs.csv"),
        ]
        for c in candidates:
            if c.is_file():
                input_file = c
                break
        if input_file is None:
            log.error("No log file found in data/. Run logpush-fetcher.py first or pass a file path.")
            return 2
        log.info("Auto-detected log input: %s", input_file)
    elif not input_file.exists():
        log.error("Log file not found: %s", input_file)
        return 2

    out_dir = args.out if (args.out.is_dir() or str(args.out).endswith("/")) else args.out.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    suffixes = [s.lstrip(".").lower() for s in args.allow_suffix]
    analyzer = Analyzer()
    candidates: Dict[str, Dict[str, str]] = {}
    cand_cap = max(0, args.max_checks) * 20 or 1

    log.info("Reading %s ...", input_file)
    for row in iter_rows(input_file):
        analyzer.consume(row)
        if not args.live or len(candidates) >= cand_cap:
            continue
        edge = csv_status(row, "EdgeResponseStatus", "edgeResponseStatus", "status")
        method = get_val(row, "ClientRequestMethod", "clientRequestHTTPMethodName", "method").upper()
        host = safe_host(get_val(row, "ClientRequestHost", "clientRequestHTTPHost", "EdgeRequestHost", "host"))
        path = normalize_path(get_val(row, "ClientRequestPath", "clientRequestPath", "ClientRequestURI", "path", default="/"))
        if edge is None or not (200 <= edge <= 299) or method not in SUSPECT_METHODS:
            continue
        if not args.include_all_2xx and not path_is_sensitive(path):
            continue
        if suffixes and not any(host == s or host.endswith("." + s) for s in suffixes):
            continue
        url = url_from_row(row)
        if url:
            candidates.setdefault(url, row)

    if analyzer.total == 0:
        log.error("No rows found in CSV.")
        return 2
    log.info("Parsed %d rows, %d distinct client IPs/networks.", analyzer.total, len(analyzer.ip_stats))

    # ---- IP suggestions
    th = Thresholds(args.block_threshold, args.challenge_threshold, args.watch_threshold,
                    args.rate_threshold, args.min_requests)
    allow_nets = load_allowlist(args.allow_ip, args.allow_ip_file)
    sugs = build_suggestions(analyzer.ip_stats, th, allow_nets, {str(a) for a in args.allow_asn},
                             not args.no_verify_bots, args.max_block)

    # ---- live verification
    live_results: List[LiveResult] = []
    if args.live:
        items = list(candidates.items())[: max(0, args.max_checks)]
        session = build_session()
        canary_cache: Dict[str, Optional[bytes]] = {}
        log.info("Live verification: %d unique URL(s)", len(items))
        for idx, (url, row) in enumerate(items, 1):
            host = safe_host(get_val(row, "ClientRequestHost", "clientRequestHTTPHost", "EdgeRequestHost", "host"))
            if host not in canary_cache:
                canary_body: Optional[bytes] = None
                if is_public_hostname(host):
                    scheme = get_val(row, "ClientRequestScheme", "clientRequestScheme", "scheme", default="https").lower()
                    scheme = scheme if scheme in {"http", "https"} else "https"
                    try:
                        _, canary_body = perform_get(
                            session, f"{scheme}://{host}{make_canary_path(host)}",
                            DEFAULT_CRAWLER_UA, args.timeout)
                    except requests.RequestException:
                        canary_body = None
                    time.sleep(max(0.0, args.delay))
                canary_cache[host] = canary_body
            result = live_check_url(session, row, canary_cache[host], args.timeout)
            live_results.append(result)
            log.info("[%d/%d] %-32s %3s %s%s", idx, len(items), result.classification,
                     result.status or "-", result.host, result.path)
            time.sleep(max(0.0, args.delay))

    # ---- consolidated report generation
    summary = analyzer.summary()
    report_path = args.out
    if report_path.is_dir() or str(report_path).endswith("/"):
        report_path = report_path / "cloudflare-security-report.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)

    report_content = markdown_report(input_file, summary, live_results, sugs, args.list_name)
    report_path.write_text(report_content, encoding="utf-8")
    log.info("Consolidated security report written to %s", report_path)

    # Optional split files
    if args.split_files:
        out_dir = report_path.parent
        write_cloudflare_artifacts(out_dir, sugs, args.list_name)
        log.info("Legacy split files generated in %s", out_dir)

    # Optional API push
    block = [s for s in sugs if s.tier == "BLOCK"]
    if args.push_list:
        push_to_cloudflare_list(block, args.apply)

    tiers = Counter(s.tier for s in sugs)
    print("\n" + "=" * 60)
    print("CLOUDFLARE SECURITY AUDIT & INDUSTRY BLOCK DECISION SUMMARY")
    print("=" * 60)
    print(f"Log input source             : {input_file}")
    print(f"Total requests analyzed      : {summary['total_requests']:,}")
    print(f"Unique source IPs            : {summary['unique_ips']:,}")
    print(f"Sensitive probe requests     : {summary['sensitive_request_count']:,}")
    print(f"Sensitive paths with edge 2xx: {summary['sensitive_2xx_count']:,}")
    print("-" * 60)
    print(f"IPs recommended to BLOCK     : {tiers['BLOCK']}")
    print(f"IPs recommended to CHALLENGE : {tiers['CHALLENGE']}")
    print(f"IPs to WATCH (Monitor)       : {tiers['WATCH']}")
    print("=" * 60)

    # Detailed Industry Decision Table
    actionable = [s for s in sugs if s.tier in {"BLOCK", "CHALLENGE"}]
    if actionable:
        print("\nRECOMMENDED ACTIONABLE DECISIONS:")
        for s in actionable:
            prefix = "[BLOCK]    " if s.tier == "BLOCK" else "[CHALLENGE]"
            print(f"  {prefix} {s.ip:<25} | Decision: {s.decision} (Confidence: {s.confidence}, Score: {s.score})")
            print(f"             Reasons: {s.reasons}")
            print(f"             Action : {s.recommended_action}\n")

    if live_results:
        print("LIVE VERIFICATION:")
        for k, v in Counter(r.classification for r in live_results).most_common():
            print(f"  {k:32s}: {v}")

    print(f"Consolidated Report Document : {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())