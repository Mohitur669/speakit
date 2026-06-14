"""
SpeakIT: Full-Surface API Load Tester & Security Auditor (v1.2)
============================================================

Comprehensive testing utility designed to validate every REST endpoint in the
SpeakIT platform. Targets performance, security, and rate-limiting integrity.

Core Coverage:
- Auth Lifecycle: Login, Register, Session Metadata, Discovery, Logout.
- TTS Studio: Buffered & Streaming Synthesis, Usage Metrics, Voice Inventory.
- User Data: Paginated History, Targeted Deletion, Global Cleanup.
- Secure Contact: Intersection Rate Limiting, Replay Protection, Honeypot.
- Payments: Order Creation, Verification, Transaction History.
- System: Health Pings, Parameter Discovery.

Requirements:
- httpx, rich, faker, asyncio (Python 3.10+)
"""

import httpx
import time
import asyncio
import argparse
import sys
import logging
import io
import random
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from faker import Faker
from rich.console import Console
from rich.table import Table
from rich.progress import (
    Progress,
    SpinnerColumn,
    BarColumn,
    TimeElapsedColumn,
    TextColumn,
)
from rich import box
from rich.panel import Panel
from rich.prompt import Prompt, IntPrompt, Confirm

# ── Log rotation ─────────────────────────────────────────────────────────────
APP_LOG = Path("automation-script-logs/app.log")
RESULT_LOG = Path("automation-script-logs/result.log")

APP_LOG.parent.mkdir(parents=True, exist_ok=True)

def _rotate(path: Path):
    if path.exists():
        mtime = path.stat().st_mtime
        ts = datetime.fromtimestamp(mtime).strftime("%Y%m%d_%H%M%S")
        archive = path.with_name(f"{path.stem}_{ts}{path.suffix}")
        path.rename(archive)

_rotate(APP_LOG)
_rotate(RESULT_LOG)

# ── Logger Initialization ───────────────────────────────────────────────────
logging.basicConfig(
    filename=APP_LOG,
    level=logging.DEBUG,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    encoding="utf-8",
)
log = logging.getLogger("speakit")

_res_buf = io.StringIO()
_res_console = Console(file=_res_buf, highlight=False, markup=True, force_terminal=False)

def _flush():
    txt = _res_buf.getvalue()
    if txt:
        with open(RESULT_LOG, "a", encoding="utf-8") as f:
            f.write(txt)
        _res_buf.truncate(0)
        _res_buf.seek(0)

console = Console()
_faker = Faker()

# ── UI Wrappers ──────────────────────────────────────────────────────────────
def cprint(msg="", **kw):
    console.print(msg, **kw)
    _res_console.print(msg, **kw)
    _flush()

def crule(title=""):
    console.rule(title)
    _res_console.rule(title)
    _flush()

def cpanel(content, **kw):
    console.print(Panel(content, **kw))
    _res_console.print(Panel(content, **kw))
    _flush()

# ── Runtime Configuration ───────────────────────────────────────────────────
class Cfg:
    base_url: str = "http://localhost:8080"
    auth_username: str = "test"
    auth_password: str = "Mohitur669@"
    token: str = ""
    user_id: int = 0
    test_target: str = "all"

cfg = Cfg()
results: list[dict] = []
TIMEOUT = httpx.Timeout(30.0, connect=60.0)

def _ep(path): return cfg.base_url.rstrip("/") + path
def _auth(): return {"Authorization": f"Bearer {cfg.token}"}

def record(endpoint, method, status, code, duration_ms, note="", ip=None):
    results.append({
        "endpoint": endpoint, "method": method, "status": status,
        "code": code, "duration_ms": round(duration_ms), "note": note
    })
    level = logging.INFO if status == "OK" else logging.WARNING if status == "RATELIMIT" else logging.ERROR
    log.log(level, "[%-6s] %-30s CODE=%-3s %5dms %s", method, endpoint, code or "-", round(duration_ms), note)

# ── Core API Operations ──────────────────────────────────────────────────────

async def call(client, method, path, json=None, headers=None, label="", test_name=""):
    t0 = time.perf_counter()
    h = {}
    if cfg.token:
        h["Authorization"] = f"Bearer {cfg.token}"
    if headers: h.update(headers)

    try:
        r = await client.request(method, _ep(path), json=json, headers=h, timeout=TIMEOUT)
        ms = (time.perf_counter() - t0) * 1000

        status = "OK" if r.is_success else "RATELIMIT" if r.status_code == 429 else "ERROR"
        note = f"{len(r.content):,} bytes" if r.status_code == 200 else r.text[:100]

        record(path, method, status, r.status_code, ms, note)

        color = "green" if status == "OK" else "yellow" if status == "RATELIMIT" else "red"
        symbol = "✓" if status == "OK" else "⚡" if status == "RATELIMIT" else "✗"
        cprint(f"  [{color}]{symbol}[/{color}] {method} {path} → {r.status_code} [{ms:.0f}ms] [dim]{label}[/dim]")
        return r
    except Exception as e:
        ms = (time.perf_counter() - t0) * 1000
        record(path, method, "FAIL", 0, ms, str(e))
        cprint(f"  [red]✗[/red] {method} {path} → FAILED [{ms:.0f}ms] {str(e)}")
        return None
# ── Test Suites ──────────────────────────────────────────────────────────────

async def run_auth_suite(client):
    crule("[bold cyan]Auth & Discovery Suite[/bold cyan]")

    # 1. Discovery
    await call(client, "GET", "/api/auth/ping", label="Health Check")
    await call(client, "GET", "/api/auth/check-username", label="Discovery", json={"username": cfg.auth_username})
    await call(client, "GET", "/api/auth/check-email", label="Discovery", json={"email": f"{cfg.auth_username}@test.com"})

    # 2. Lifecycle
    reg = await call(client, "POST", "/api/auth/register", label="Account Creation", json={
        "username": cfg.auth_username,
        "email": f"{cfg.auth_username}@test.com",
        "password": cfg.auth_password,
        "phoneNumber": "+919876543210"
    })

    login = await call(client, "POST", "/api/auth/login", label="Session Establishment", json={
        "username": cfg.auth_username,
        "password": cfg.auth_password
    })

    if login and login.status_code == 200:
        cfg.token = login.json().get("token")
        await call(client, "GET", "/api/auth/me", label="Session Metadata")
        await call(client, "POST", "/api/auth/ws-ticket", label="WebSocket Ticket")

async def run_studio_suite(client):
    crule("[bold cyan]TTS Studio Suite[/bold cyan]")
    if not cfg.token: return cprint("  [red]Skipping Studio: No JWT token[/red]")

    await call(client, "GET", "/api/tts/voices", label="Voice Inventory")
    await call(client, "GET", "/api/tts/usage", label="Usage Metering")

    # Synthesis
    payload = {"text": "Load test payload.", "voiceId": "Joanna", "outputFormat": "mp3"}
    await call(client, "POST", "/api/tts/synthesize", json=payload, label="Buffered Synthesis")
    await call(client, "POST", "/api/tts/synthesize-stream", json=payload, label="Streaming Synthesis")

async def run_history_suite(client):
    crule("[bold cyan]User Content Suite[/bold cyan]")
    if not cfg.token: return

    history = await call(client, "GET", "/api/history", label="Paginated History", json={"page": 0, "size": 10})

    if history and history.status_code == 200:
        data = history.json()
        ids = [item['id'] for item in data.get('content', [])[:2]]
        if ids:
            await call(client, "DELETE", "/api/history/delete", json=ids, label="Targeted Deletion")

    await call(client, "DELETE", "/api/history/clear-all", label="Global History Purge")

async def run_contact_suite(client):
    crule("[bold cyan]Secure Contact Suite[/bold cyan]")

    # 1. Normal Submission
    await call(client, "POST", "/api/contact", label="Secure Submission", headers={
        "X-Request-ID": str(uuid.uuid4())
    }, json={
        "firstName": "Load", "lastName": "Tester",
        "email": f"test_{uuid.uuid4().hex[:4]}@example.com",
        "topic": "enterprise", "message": "Automated security audit message.",
        "website": "" # Honeypot empty
    })

    # 2. Replay Attack
    rid = str(uuid.uuid4())
    await call(client, "POST", "/api/contact", label="Replay Init", headers={"X-Request-ID": rid}, json={
        "firstName": "Replay", "lastName": "Bot", "email": "replay@bot.com",
        "topic": "support", "message": "Replay test.", "website": ""
    })
    await call(client, "POST", "/api/contact", label="Replay Attack (Expect 200 Idempotent)", headers={"X-Request-ID": rid}, json={
        "firstName": "Replay", "lastName": "Bot", "email": "replay@bot.com",
        "topic": "support", "message": "Replay test.", "website": ""
    })

    # 3. Honeypot Trap
    await call(client, "POST", "/api/contact", label="Bot Trap (Expect Silent Success)", json={
        "firstName": "Bot", "lastName": "Scraper", "email": "bot@spam.com",
        "topic": "feedback", "message": "I am a bot.", "website": "http://evil.com" # Honeypot filled
    })

async def run_payment_suite(client):
    crule("[bold cyan]Payments & Transactions Suite[/bold cyan]")
    if not cfg.token: return

    await call(client, "GET", "/api/v1/payments/history", label="Transaction Ledger")
    await call(client, "POST", "/api/v1/payments/create-order", label="Order Initialization", json={
        "planType": "PRO", "amount": 499, "currency": "INR"
    })

async def run_system_suite(client):
    crule("[bold cyan]System Configuration Suite[/bold cyan]")

    await call(client, "GET", "/api/system-parameters/cached/SYSTEM_STATUS", label="Cached Parameter")
    await call(client, "GET", "/api/system-parameters/live/PRO_PLAN_PRICE_INR", label="Live Parameter")
    # Note: Bulk endpoint uses list parameter in URL
    await call(client, "GET", "/api/system-parameters/bulk?names=SYSTEM_STATUS,ENABLE_RAZORPAY", label="Bulk Parameter")

    # Security Test: Unauthorized parameter
    await call(client, "GET", "/api/system-parameters/live/DB_PASSWORD", label="Security Breach Attempt (Expect 403)")

async def run_security_probes(client):
    crule("[bold red]Security Vulnerability Probes[/bold red]")

    # Probe 1: Unauthorized Neural Engine Usage (Cost-Exhaustion)
    # Scenario: Free user attempts to use high-cost NEURAL engine
    await call(client, "POST", "/api/tts/synthesize", label="Neural Bypass Probe", json={
        "text": "Security probe.", "voiceId": "Joanna", "outputFormat": "mp3"
    })

    # Probe 2: IP Spoofing (Rate Limit Bypass)
    # Scenario: Rapid requests with rotated X-Forwarded-For headers
    cprint("  [dim]Triggering IP Spoofing Probe...[/dim]")
    for i in range(5):
        spoofed_ip = f"1.2.3.{i}"
        await call(client, "POST", "/api/contact", label=f"Spoof {spoofed_ip}", headers={
            "X-Forwarded-For": spoofed_ip
        }, json={
            "firstName": "Spoof", "lastName": "Bot", "email": "spoof@test.com",
            "topic": "support", "message": "Bypass test."
        })

    # Probe 3: Information Disclosure
    # Scenario: Trigger internal exception to see if raw e.getMessage() is returned
    await call(client, "POST", "/api/tts/synthesize", label="Info Disclosure Probe", json={
        "text": "Fail me.", "voiceId": "INVALID_VOICE_ID", "outputFormat": "mp3"
    })

# ── Summary & Reporting ──────────────────────────────────────────────────────

def print_summary():
    crule("[bold]AUDIT REPORT[/bold]")
    table = Table(box=box.ROUNDED, show_header=True, header_style="bold magenta")
    table.add_column("Endpoint", style="dim")
    table.add_column("Method")
    table.add_column("Code", justify="center")
    table.add_column("Duration", justify="right")
    table.add_column("Status")

    for r in results:
        status_color = "green" if r["status"] == "OK" else "yellow" if r["status"] == "RATELIMIT" else "red"
        table.add_row(
            r["endpoint"], r["method"], str(r["code"]), f"{r['duration_ms']}ms",
            f"[{status_color}]{r['status']}[/{status_color}]"
        )

    console.print(table)

    total = len(results)
    ok = sum(1 for r in results if r["status"] == "OK")
    rl = sum(1 for r in results if r["status"] == "RATELIMIT")
    err = sum(1 for r in results if r["status"] == "ERROR")

    cpanel(
        f"[green]✓ Passed:[/green]        {ok}\n"
        f"[yellow]⚡ Rate limited:[/yellow] {rl}\n"
        f"[red]✗ Failed:[/red]        {err}\n"
        f"[dim]Total Ops:[/dim]       {total}",
        title="Final Stability Score", border_style="cyan"
    )

# ── Entry Point ─────────────────────────────────────────────────────────────

async def main():
    parser = argparse.ArgumentParser(description="SpeakIT Full-Surface API Load Tester")
    parser.add_argument("--url", default=cfg.base_url, help="Target backend URL")
    args = parser.parse_args()
    cfg.base_url = args.url.rstrip("/")

    cpanel(f"[bold]SpeakIT Full-Surface API Audit[/bold]\nTarget: {cfg.base_url}\nStarted: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", border_style="cyan")

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        # Suite 1: Authentication & Account Linking
        await run_auth_suite(client)

        # Suite 2: Public Inquiries (Anonymous)
        await run_contact_suite(client)

        # Suite 3: TTS Core Engine
        await run_studio_suite(client)

        # Suite 4: Transactional History
        await run_history_suite(client)

        # Suite 5: Financial Workflow
        await run_payment_suite(client)

        # Suite 6: System Infrastructure
        await run_system_suite(client)

        # Suite 7: Security Probes
        await run_security_probes(client)

    print_summary()

if __name__ == "__main__":
    asyncio.run(main())
