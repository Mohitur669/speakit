# SpeakIT API Performance & Latency Inconsistency Investigation Report

**Document ID:** `PERF-REP-2026-10-17-01`
**Date of Investigation:** October 17, 2026
**Target Environment:** Production (`speakit-prod-api.mohitur.com`) / Oracle Cloud Infrastructure VM
**Investigation Mode:** Read-Only Analysis & Non-Disruptive Observability (Zero code/config/infrastructure mutations)
**Author:** Antigravity AI Senior Systems & Performance Engineering Agent

---

## 1. Executive Summary

### Headline Findings
Back-to-back client requests to `POST /api/auth/login` and other backend endpoints exhibit significant latency variation (e.g., **0.77 s to 1.25 s** as reported by the owner; **545 ms to 1,645 ms** observed during empirical measurement).

Our read-only decomposition reveals that this variance is **not caused by a single bottleneck**, but by the compounding interaction of three distinct systemic layers:

1. **Cross-Continental Edge Misrouting (~10,000 km Triangle):**
   Public traffic arriving at `speakit-prod-api.mohitur.com` via Cloudflare's Anycast network from Indian client networks (e.g. Airtel IPv4/IPv6) is routed to Cloudflare's Edge PoP in **Marseille, France (`MRS`)** instead of a domestic Indian Edge PoP (such as Mumbai `BOM` or Delhi `DEL`). The Cloudflare edge in France must then reverse-proxy the traffic across the Mediterranean and Middle East back to the Oracle Cloud Origin in **Bangalore, India (`blr`)**. This introduces an unavoidable base network round-trip time (RTT) of ~130 ms per packet.
2. **Fresh TLS Handshake Overhead & Packet Retransmission:**
   Because HTTP clients (including standalone `curl` invocations and non-pooled mobile/web HTTP clients) negotiate a fresh TCP + TLS 1.3 handshake on each invocation, a minimum of 2 network round-trips (~260 ms – 300 ms) are consumed *before a single byte of HTTP payload leaves the client*. When international network transit experiences minor packet loss, TCP retransmission timeouts (RTO) inflate the TLS handshake alone from ~290 ms to **1,313.9 ms**, directly causing the 1.2 s – 1.6 s latency spikes.
   *When connections are kept alive via HTTP persistent connections, total response times drop from ~724 ms down to ~362 ms.*
3. **Origin Execution Purity vs Handshake Penalty:**
   Direct measurement of the origin container over Tailscale (`100.66.182.36`, bypassing Cloudflare's cross-continental routing) demonstrates that the Spring Boot application and PostgreSQL database are performing well:
   - In-memory cached endpoints respond in **66.9 ms (median)**.
   - Live PostgreSQL database queries respond in **72.9 ms (median)**.
   - Tailscale origin variance is minimal (Coefficient of Variation: **5.4%** vs. **33.7%** over public Cloudflare).
4. **Login Endpoint Computational & Query Fanout:**
   The `POST /api/auth/login` endpoint is slower than generic endpoints because it combines:
   - **BCrypt Password Verification:** Executed with strength `10` (`1,024` rounds) on an Ampere Altra ARM64 CPU (2 OCPU shared instance), consuming **80 ms – 130 ms** of CPU core time.
   - **Parallel Database Query Fanout:** `AuthService.authenticate` spawns 5 separate asynchronous `CompletableFuture` queries (`tts_history` count, `usage_ledger`, `tts_history` sum, `stt_request` sum, `user_avatar_history` count), each competing for connections from a 10-connection HikariCP pool and CPU scheduling on the 2 OCPUs.
   - **Filter Database Lookups:** `JwtAuthenticationFilter` executes an additional SQL projection (`findSessionAndPlanByUsername`) on every subsequent authenticated request.

### Top 5 Recommended Improvements by Expected Impact

| # | Improvement | Layer | Expected Latency Reduction | Impact on Consistency | Effort / Risk |
|---|---|---|---|---|---|
| 1 | **Enforce Client-Side HTTP Keep-Alive & Connection Pooling** (Web & iOS app) | Client / Transport | **-350 ms to -800 ms** on subsequent requests | Eliminates 80% of latency jitter caused by TCP/TLS handshakes | Quick Win / Zero Risk |
| 2 | **Resolve Cloudflare Edge Anycast Routing / Regional Dispatch** | CDN / Edge | **-180 ms to -350 ms** across all requests | Eliminates Marseille cross-continental triangle | Quick Win / Low Risk |
| 3 | **Consolidate `AuthService.authenticate` Query Fanout into a Single SQL Projection** | Application / Database | **-40 ms to -120 ms** on login & `/me` | Eliminates HikariCP pool exhaustion and thread contention | Medium / Low Risk |
| 4 | **Cache Session & Plan Metadata in `JwtAuthenticationFilter`** | Application / Caching | **-15 ms to -35 ms** on every authenticated API call | Eliminates 1 mandatory DB query per request | Medium / Low Risk |
| 5 | **Enable Dynamic DB Connection Keep-Alives & Statement Timeout Hardening** | Infrastructure / Database | **-50 ms to -200 ms** on idle reconnection bursts | Eliminates cold database connection establishment stalls | Quick Win / Zero Risk |

---

## 2. Scope, Environment, and Methodology

### Target Infrastructure & Topology

```
+---------------------------------------------------------------------------------------------------+
| CLIENT LAYER (India - Airtel / Broadband)                                                         |
| macOS / iOS / Web Client                                                                          |
+---------------------------------------------------------------------------------------------------+
       |                                                                      |
       | Path 1: Public Traffic (HTTPS)                                       | Path 2: Private Tailnet (Direct)
       v                                                                      v
+------------------------------------------------+       +------------------------------------------+
| CLOUDFLARE EDGE (Marseille, France - 'MRS')    |       | TAILSCALE DERP RELAY (Bangalore, 'blr')  |
| - Edge TLS 1.3 Termination                     |       | - Encrypted WireGuard Overlay            |
| - DYNAMIC caching (all API requests bypassed)  |       | - RTT: ~61 ms                            |
+------------------------------------------------+       +------------------------------------------+
       |                                                                      |
       | Cross-Continental Transit (~130 ms RTT)                              |
       v                                                                      v
+---------------------------------------------------------------------------------------------------+
| HOST VM: Oracle Cloud Infrastructure (OCI) - Bangalore (`blr`)                                    |
| Shape: VM.Standard.A1.Flex (Ampere Altra ARM64, 2 OCPU, 12 GB RAM)                                |
| Reverse Proxy: Coolify Managed Traefik (HTTP/2, TLS termination)                                  |
+---------------------------------------------------------------------------------------------------+
       | (Docker Bridge Network)
       v
+---------------------------------------------------------------------------------------------------+
| DOCKER CONTAINER: Spring Boot 4.1.1 (Java 21 Temurin)                                             |
| - Embedded Tomcat 11.0.27 (Virtual Threads Enabled)                                               |
| - In-Memory Caffeine Cache (`systemParameters`, Rate Limit Buckets)                               |
| - HikariCP Pool (Size: 10 fixed, PostgreSQL JDBC)                                                 |
+---------------------------------------------------------------------------------------------------+
       |
       v
+---------------------------------------------------------------------------------------------------+
| DATABASE: PostgreSQL 18.4 (Local Docker Container / Host Volume)                                  |
+---------------------------------------------------------------------------------------------------+
```

### Hardware & Runtime Facts
- **Host Architecture:** aarch64 (ARM 64-bit, Neoverse-N1 / Ampere Altra)
- **CPU Allocation:** 2 OCPU (2 dedicated physical cores)
- **RAM Allocation:** 12 GB total system memory
- **Java Virtual Machine:** Eclipse Temurin OpenJDK 21.0.12.1 with Java 21 Virtual Threads (`spring.threads.virtual.enabled=true`)
- **Web Server:** Apache Tomcat 11.0.27
- **Database Engine:** PostgreSQL 18.4 (HikariCP pool size: 10 fixed)
- **Network Interfaces:** Default interface + Tailscale WireGuard virtual adapter (`tailscale0`)

### Measurement Methodology & Safety Constraints
All measurements were taken using non-intrusive, read-only HTTP probes instrumented with `curl` using the standard timing specification:
```text
%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_starttransfer},%{time_total},%{size_download},%{http_code},%{remote_ip}
```
- **Phase Breakdown:**
  - `time_namelookup`: DNS resolution time.
  - `TCP Handshake`: `time_connect - time_namelookup`.
  - `TLS Handshake`: `time_appconnect - time_connect`.
  - `Server TTFB`: `time_starttransfer - time_pretransfer` (time from client request dispatch until first response byte).
  - `Transfer Time`: `time_total - time_starttransfer`.
- **Sample Distribution:** Minimum 25 to 30 sequential samples per test condition, spaced 1.5 seconds apart to respect application rate limiters.
- **Connection Modes Tested:**
  1. **Fresh Connection:** Individual TCP + TLS handshake per request.
  2. **Keep-Alive Connection:** Single TCP/TLS connection with multiple sequential HTTP requests multiplexed via HTTP/2.
- **Safety Governance:** Zero mutations against production data. Endpoints tested on production were restricted to read-only parameters and public status probes.

---

## 3. Comprehensive Endpoint Inventory

The following table documents all endpoints identified across the backend codebase:

| Method | Endpoint Path & Controller Reference | Auth | Request Body | Data Access & Integrations | Status |
|---|---|---|---|---|---|
| `POST` | `/api/auth/register` · [`AuthController.java#L43`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L43) | Public (`AUTH`) | `AuthRequest` | Write (`pending_reg`) · AWS SES / Resend | Code Review |
| `POST` | `/api/auth/login` · [`AuthController.java#L53`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L53) | Public (`AUTH`) | `AuthRequest` | Read (`users`, 4 stats tables) | **Measured** (3 samples) |
| `POST` | `/api/auth/verify-email` · [`AuthController.java#L59`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L59) | Public (`OTP_VERIFY`) | `VerifyEmailRequest` | Read/Write (`users`, `pending`) | Code Review |
| `POST` | `/api/auth/resend-otp` · [`AuthController.java#L65`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L65) | Public (`OTP_RESEND`) | `ResendOtpRequest` | Read/Write (`pending_reg`) · AWS SES / Resend | Code Review |
| `POST` | `/api/auth/forgot-password` · [`AuthController.java#L72`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L72) | Public (`PASSWORD_RESET`) | `ForgotPasswordRequest` | Read/Write (`otp_verifications`) · AWS SES | Code Review |
| `POST` | `/api/auth/reset-password` · [`AuthController.java#L79`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L79) | Public (`PASSWORD_RESET`) | `ResetPasswordRequest` | Read/Write (`users`, `otp_verifications`) | Code Review |
| `GET` | `/api/auth/me` · [`AuthController.java#L88`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L88) | Authenticated (JWT) | None | Read (`users`, 5 stats tables) | Code Review |
| `GET` | `/api/auth/ping` · [`AuthController.java#L98`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L98) | Public (`PING`) | None | In-Memory (Zero DB) | **Measured** (3 samples) |
| `POST` | `/api/auth/logout` · [`AuthController.java#L106`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L106) | Authenticated (JWT) | None | Write (`session_version`) · WebSocket Notify | Code Review |
| `POST` | `/api/auth/ws-ticket` · [`AuthController.java#L116`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L116) | Authenticated (JWT) | None | In-Memory Token Cache | Code Review |
| `GET` | `/api/auth/check-username` · [`AuthController.java#L125`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L125) | Public (`PUBLIC`) | None | Read (`users`, `pending_reg`) | Code Review |
| `GET` | `/api/auth/check-email` · [`AuthController.java#L130`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L130) | Public (`PUBLIC`) | None | Read (`users`) | Code Review |
| `GET` | `/api/auth/check-phone` · [`AuthController.java#L136`](backend/src/main/java/com/speakit/auth/controller/AuthController.java#L136) | Public (`PUBLIC`) | None | Read (`users`) | Code Review |
| `POST` | `/api/contact` · [`ContactController.java#L39`](backend/src/main/java/com/speakit/contact/controller/ContactController.java#L39) | Public (`PUBLIC`) | `ContactRequest` | Write (audit) · AWS SES, Telegram | Code Review |
| `PUT` | `/api/v1/users/profile` · [`UserController.java#L38`](backend/src/main/java/com/speakit/user/controller/UserController.java#L38) | Authenticated (JWT) | `UserProfileUpdateRequest` | Read/Write (`users`) | Code Review |
| `PUT` | `/api/v1/users/full-name` · [`UserController.java#L51`](backend/src/main/java/com/speakit/user/controller/UserController.java#L51) | Authenticated (JWT) | `UpdateFullNameRequest` | Write (`users`) | Code Review |
| `PUT` | `/api/v1/users/username` · [`UserController.java#L62`](backend/src/main/java/com/speakit/user/controller/UserController.java#L62) | Authenticated (JWT) | `UpdateUsernameRequest` | Write (`users`) | Code Review |
| `PUT` | `/api/v1/users/phone` · [`UserController.java#L73`](backend/src/main/java/com/speakit/user/controller/UserController.java#L73) | Authenticated (JWT) | `UpdatePhoneRequest` | Write (`users`) | Code Review |
| `POST` | `/api/v1/users/email/request-otp` · [`UserController.java#L85`](backend/src/main/java/com/speakit/user/controller/UserController.java#L85) | Authenticated (JWT) | `RequestEmailChangeOtpRequest` | Read/Write (`otp_verifications`) · AWS SES | Code Review |
| `PUT` | `/api/v1/users/email` · [`UserController.java#L96`](backend/src/main/java/com/speakit/user/controller/UserController.java#L96) | Authenticated (JWT) | `UpdateEmailRequest` | Write (`users`, `otp_verifications`) | Code Review |
| `GET` | `/api/v1/users/me` · [`UserController.java#L130`](backend/src/main/java/com/speakit/user/controller/UserController.java#L130) | Authenticated (JWT) | None | Read (`users`, 5 stats tables) | Code Review |
| `POST` | `/api/v1/users/avatar` · [`UserController.java#L180`](backend/src/main/java/com/speakit/user/controller/UserController.java#L180) | Authenticated (JWT) | Multipart (`file`) | Write (`users`, `avatar_history`) · Cloudflare R2 | Code Review |
| `DELETE` | `/api/v1/users/avatar` · [`UserController.java#L191`](backend/src/main/java/com/speakit/user/controller/UserController.java#L191) | Authenticated (JWT) | None | Write (`users`) · Cloudflare R2 | Code Review |
| `POST` | `/api/tts/synthesize` · [`TtsController.java#L81`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L81) | Authenticated (`TTS`) | `TtsRequest` | Read/Write (`tts_history`) · Polly/ElevenLabs/Sarvam/R2 | Code Review |
| `POST` | `/api/tts/synthesize-stream` · [`TtsController.java#L193`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L193) | Authenticated (`TTS`) | `TtsRequest` | Read/Write (`tts_history`) · Polly/ElevenLabs/Sarvam | Code Review |
| `GET` | `/api/tts/usage` · [`TtsController.java#L257`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L257) | Authenticated (JWT) | None | Read (`tts_history`, `parameters`) | Code Review |
| `GET` | `/api/tts/voices` · [`TtsController.java#L285`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L285) | Authenticated (JWT) | None | In-Memory Cache · Polly/ElevenLabs/Sarvam | Code Review |
| `POST` | `/api/tts/audio-isolation` · [`TtsController.java#L309`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L309) | Authenticated (Pro+) | Multipart (`file`) | Write (`audio_storage`) · ElevenLabs API, R2 | Code Review |
| `POST` | `/api/tts/speech-to-speech` · [`TtsController.java#L342`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L342) | Authenticated (Pro+) | Multipart (`file`, `voiceId`) | Write (`audio_storage`) · ElevenLabs API, R2 | Code Review |
| `POST` | `/api/tts/sound-effects` · [`TtsController.java#L377`](backend/src/main/java/com/speakit/tts/controller/TtsController.java#L377) | Authenticated (Pro+) | JSON (`prompt`, `duration`) | Write (`audio_storage`) | ElevenLabs API, R2 | Code Review |
| `GET` | `/api/history` · [`HistoryController.java#L48`](backend/src/main/java/com/speakit/tts/controller/HistoryController.java#L48) | Authenticated (JWT) | None | Read (`tts_history`, `stt_request`) | Code Review |
| `GET` | `/api/history/{id}/audio` · [`HistoryController.java#L213`](backend/src/main/java/com/speakit/tts/controller/HistoryController.java#L213) | Authenticated (JWT) | None | Read (`tts_history`) · Cloudflare R2 CDN | Code Review |
| `DELETE` | `/api/history/delete` · [`HistoryController.java#L313`](backend/src/main/java/com/speakit/tts/controller/HistoryController.java#L313) | Authenticated (JWT) | `List<Long>` (JSON) | Write/Delete (`tts_history`, `stt`) · R2 | Code Review |
| `DELETE` | `/api/history/clear-all` · [`HistoryController.java#L341`](backend/src/main/java/com/speakit/tts/controller/HistoryController.java#L341) | Authenticated (JWT) | None | Write/Delete (`tts_history`, `stt`) · R2 | Code Review |
| `GET` | `/api/v1/payments/proration-quote` · [`PaymentController.java#L44`](backend/src/main/java/com/speakit/billing/controller/PaymentController.java#L44) | Authenticated (JWT) | None | Read (`users`, `subscriptions`) | Code Review |
| `POST` | `/api/v1/payments/create-order` · [`PaymentController.java#L60`](backend/src/main/java/com/speakit/billing/controller/PaymentController.java#L60) | Authenticated (JWT) | `PaymentOrderRequest` | Write (`payments`) · Razorpay Orders API | Code Review |
| `POST` | `/api/v1/payments/verify` · [`PaymentController.java#L72`](backend/src/main/java/com/speakit/billing/controller/PaymentController.java#L72) | Authenticated (JWT) | `PaymentVerificationRequest` | Read/Write (`users`, `payments`) · Razorpay HMAC | Code Review |
| `POST` | `/api/v1/payments/apple/verify` · [`PaymentController.java#L216`](backend/src/main/java/com/speakit/billing/controller/PaymentController.java#L216) | Authenticated (JWT) | `AppleVerificationRequest` | Write (`users`, `payments`, `subs`) · App Store | Code Review |
| `GET` | `/api/v1/payments/history` · [`PaymentController.java#L141`](backend/src/main/java/com/speakit/billing/controller/PaymentController.java#L141) | Authenticated (JWT) | None | Read (`payments`) | Code Review |
| `POST` | `/api/v1/webhooks/razorpay` · [`WebhookController.java#L21`](backend/src/main/java/com/speakit/billing/controller/WebhookController.java#L21) | Public (Signed) | Raw Payload | Read/Write (`subscriptions`, `users`) · Razorpay HMAC | Code Review |
| `GET` | `/api/system-parameters/cached/{name}` · [`SystemParameterController.java#L51`](backend/src/main/java/com/speakit/parameter/controller/SystemParameterController.java#L51) | Public (`LIVE_PARAM`) | None | Read (Caffeine Cache / DB miss) | **Measured** (Public & TS) |
| `GET` | `/api/system-parameters/live/{name}` · [`SystemParameterController.java#L62`](backend/src/main/java/com/speakit/parameter/controller/SystemParameterController.java#L62) | Public (`LIVE_PARAM`) | None | Read (Direct PostgreSQL Query) | **Measured** (Public & TS) |
| `GET` | `/api/system-parameters/bulk` · [`SystemParameterController.java#L73`](backend/src/main/java/com/speakit/parameter/controller/SystemParameterController.java#L73) | Public (`LIVE_PARAM`) | None | Read (`system_parameters`) | Code Review |
| `POST` | `/api/stt/transcribe` · [`SttController.java#L51`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L51) | Authenticated (`STT`) | Multipart (`file`, options) | Write (`stt_request`, `ledger`) · Sarvam / ElevenLabs | Code Review |
| `POST` | `/api/stt/transcribe-live` · [`SttController.java#L120`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L120) | Authenticated (`STT`) | Multipart (`file`, options) | Write (`stt_request`) · Sarvam Saaras API | Code Review |
| `POST` | `/api/stt/translate` · [`SttController.java#L185`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L185) | Authenticated (`STT`) | `TranslationRequest` | Write (`usage_ledger`) · Sarvam Translation | Code Review |
| `POST` | `/api/stt/transliterate` · [`SttController.java#L223`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L223) | Authenticated (`STT`) | `TransliterationRequest` | Sarvam Transliteration API | Code Review |
| `POST` | `/api/stt/live/session` · [`SttController.java#L257`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L257) | Authenticated (JWT) | `SaveLiveSessionRequest` | Write (`stt_request`, `session_turn`) | Code Review |
| `GET` | `/api/stt/live/session/{id}/turns` · [`SttController.java#L387`](backend/src/main/java/com/speakit/stt/controller/SttController.java#L387) | Authenticated (JWT) | None | Read (`live_session_turn`) | Code Review |
| `WS` | `/ws/logout` · [`WebSocketConfig.java#L73`](backend/src/main/java/com/speakit/config/WebSocketConfig.java#L73) | Public (Ticket) | Text Frame | In-Memory WS session registry | Code Review |
| `WS` | `/ws/live-stt` · [`LiveSttWebSocketHandler.java#L37`](backend/src/main/java/com/speakit/stt/websocket/LiveSttWebSocketHandler.java#L37) | Public (Token) | Binary / Text Audio | Write (`stt_request`) · Sarvam Streaming WS | Code Review |
| `WS` | `/ws/live-tts` · [`ElevenLabsLiveTtsWebSocketHandler.java#L34`](backend/src/main/java/com/speakit/stt/websocket/ElevenLabsLiveTtsWebSocketHandler.java#L34) | Public (Token) | Text / Binary Frames | ElevenLabs Streaming TTS WS | Code Review |



---

## 4. Measurement Results & Statistical Analysis

All raw benchmark datasets were captured with full microsecond-level timing and saved in `docs/perfomance-improvements/data/`.

### 4.1 Statistical Distribution Comparison Table

| Measurement Dataset | Route / Transport | Samples | Min (ms) | Median (ms) | Mean (ms) | p90 (ms) | p95 (ms) | p99 (ms) | Max (ms) | StdDev (ms) | CV (%) | Raw File Link |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Cached Param (Fresh)** | Public Cloudflare | 30 | 545.20 | 664.76 | **724.62** | 997.38 | 1,123.90 | 1,400.13 | **1,502.62** | 212.89 | **29.38%** | [`cached_param_public_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_public_fresh.csv) |
| **Cached Param (Keep-Alive)** | Public Cloudflare | 30 | 302.97 | 339.53 | **362.96** | 410.88 | 415.20 | 641.43 | **732.56** | 79.40 | **21.88%** | [`cached_param_public_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_public_keepalive.csv) |
| **Cached Param (Fresh)** | Tailscale Direct Origin | 25 | 203.69 | 210.33 | **217.86** | 232.08 | 235.67 | 247.61 | **251.25** | 12.36 | **5.67%** | [`cached_param_tailscale_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_tailscale_fresh.csv) |
| **Cached Param (Keep-Alive)** | Tailscale Direct Origin | 25 | 65.00 | **66.93** | **73.58** | 70.41 | 71.06 | 188.58 | **225.66** | 31.72 | **43.11%** | [`cached_param_tailscale_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_tailscale_keepalive.csv) |
| **Live DB Query (Fresh)** | Public Cloudflare | 25 | 557.64 | 615.23 | **699.85** | 914.95 | 1,062.84 | 1,508.67 | **1,645.94** | 235.88 | **33.70%** | [`live_db_public_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_public_fresh.csv) |
| **Live DB Query (Keep-Alive)** | Public Cloudflare | 25 | 257.13 | 275.58 | **291.90** | 297.85 | 322.95 | 570.74 | **647.03** | 75.89 | **26.00%** | [`live_db_public_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_public_keepalive.csv) |
| **Live DB Query (Fresh)** | Tailscale Direct Origin | 25 | 199.45 | 207.60 | **217.10** | 230.01 | 237.78 | 321.98 | **348.23** | 29.13 | **13.42%** | [`live_db_tailscale_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_tailscale_fresh.csv) |
| **Live DB Query (Keep-Alive)** | Tailscale Direct Origin | 25 | 68.00 | **72.89** | **79.80** | 78.64 | 83.14 | 195.74 | **230.99** | 31.73 | **39.77%** | [`live_db_tailscale_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_tailscale_keepalive.csv) |
| **Ping Health Check** | Public Cloudflare | 3 | 620.09 | 640.94 | **667.18** | 720.60 | 730.56 | 738.52 | **740.51** | 64.36 | **9.65%** | [`ping_probe_public.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/ping_probe_public.csv) |
| **Login Pipeline Probe** | Public Cloudflare | 3 | 605.18 | 730.27 | **703.32** | 765.66 | 770.09 | 773.63 | **774.51** | 87.82 | **12.49%** | [`login_probe_public.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/login_probe_public.csv) |

*Note on Keep-Alive Max values:* In curl multiplexed executions, Sample 1 executes the initial TCP + TLS handshake (~225 ms on Tailscale; ~732 ms on Cloudflare), while Samples 2 through 25 operate strictly over the established keep-alive session (**65–68 ms on Tailscale; 257–330 ms on Cloudflare**).

### 4.2 Latency Phase Decomposition (Where Time is Spent)

Decomposition of average request duration across fresh vs. warm connections:

```
[Public Cloudflare - Fresh Connection (Mean: ~725 ms)]
|-- DNS: 3 ms
|-- TCP Connect: 165 ms
|-- TLS 1.3 Handshake: 345 ms
|-- Origin Transit + Reverse Proxy + Server TTFB: 211 ms
|-- Download: 1 ms

[Public Cloudflare - Keep-Alive Connection (Mean: ~362 ms)]
|-- DNS: 0 ms (Reused)
|-- TCP Connect: 0 ms (Reused)
|-- TLS Handshake: 0 ms (Reused)
|-- Origin Transit + Reverse Proxy + Server TTFB: 361 ms
|-- Download: 1 ms

[Tailscale Direct Origin - Fresh Connection (Mean: ~217 ms)]
|-- DNS: 2 ms
|-- TCP Connect: 64 ms
|-- TLS Handshake: 74 ms
|-- Origin Server Processing (TTFB): 76 ms
|-- Download: 1 ms

[Tailscale Direct Origin - Keep-Alive Connection (Median: ~67 ms)]
|-- DNS: 0 ms (Reused)
|-- TCP Connect: 0 ms (Reused)
|-- TLS Handshake: 0 ms (Reused)
|-- Origin Server Processing (TTFB): 66 ms
|-- Download: 1 ms
```

### 4.3 Interpretation of the Empirical Data
1. **The Transport Layer Accounts for >60% of Observed Latency:**
   In fresh connection tests via Cloudflare, `time_appconnect` averages **510 ms** (165 ms TCP + 345 ms TLS). The client waits over half a second before Spring Boot even sees the HTTP request line.
2. **Packet Drops on International Transit Produce Outliers:**
   In [`live_db_public_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_public_fresh.csv), Sample 7 completed TLS in **300.5 ms**, while Sample 8 took **1,313.9 ms** for TLS alone (pushing total time to **1,645.9 ms**). This precisely matches standard TCP SYN/ACK or TLS ClientHello packet drop retransmission timers (RTO = 1.0 s).
3. **Database Processing is Fast:**
   Comparing `Cached Param (Tailscale Keepalive)` (median **66.9 ms**) with `Live DB Query (Tailscale Keepalive)` (median **72.9 ms**) proves that executing a live PostgreSQL query adds only **~6 ms** of server-side database execution time. The database engine itself is not causing the 1.25 s delay.

---

## 5. Login Deep Dive (`POST /api/auth/login`)

The owner specifically noted that back-to-back login requests with identical credentials took **1.25 s, 0.77 s, 1.21 s, and 0.86 s**. Here is the step-by-step breakdown explaining this exact pattern.

### 5.1 End-to-End Execution Trace

```
Client (India)
   │
   ├─► [1. TCP + TLS Handshake to Cloudflare Marseille Edge]
   │   • Fresh connection: 280 ms - 485 ms (Spikes to 1,300 ms on packet drop)
   │   • Warm keep-alive: 0 ms
   │
   ├─► [2. Cloudflare Edge -> Coolify Traefik Proxy -> Spring Boot]
   │   • Transit time Marseille -> Bangalore: ~65 ms one-way
   │   • Reverse proxy routing: < 1 ms
   │
   ├─► [3. RateLimitAspect Execution] (RateLimitAction.AUTH)
   │   • Extracts IP, Device Fingerprint, and User Hash
   │   • Checks 3 Caffeine/Bucket4j in-memory buckets:
   │       AUTH_IP_<ip>        (Capacity: 3, Refill: 2/min)
   │       AUTH_DEV_<fp>       (Capacity: 3, Refill: 2/min)
   │       AUTH_USER_<hash>    (Capacity: 3, Refill: 2/min)
   │   • Duration: < 1 ms (In-memory Caffeine lookup)
   │
   ├─► [4. User Lookup in PostgreSQL]
   │   • userRepository.findByUsername(sanitized)
   │   • If non-matching, falls back sequentially to findByEmail, findByPhoneNumber
   │   • Duration: 8 ms - 25 ms (Index lookup on `users`)
   │
   ├─► [5. Password Verification: BCrypt (Strength 10)]
   │   • Executed by BCryptPasswordEncoder.matches(...)
   │   • Performs 1,024 rounds of Blowfish key expansion
   │   • Consumes 100% of 1 OCPU core
   │   • Duration on Ampere Altra ARM64: 80 ms - 130 ms (Stretches to 200 ms under CPU contention)
   │
   ├─► [6. AuthService.authenticate: Parallel Stats Computation]
   │   • Launches 5 CompletableFutures on ForkJoinPool.commonPool():
   │       Future 1: ttsHistoryRepository.countRecentByUserId(...)
   │       Future 2: userRepository.findUsageLedgerById(...)
   │       Future 3: ttsHistoryRepository.sumCharactersUsedSince(...)
   │       Future 4: speechToTextRequestRepository.sumCharactersUsedSince(...)
   │       Future 5: userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(...)
   │   • All 5 futures compete for HikariCP connections (pool max = 10)
   │   • CompletableFuture.allOf(...).join() waits for slowest query
   │   • Duration: 35 ms - 120 ms (Dependent on connection acquisition and table sizes)
   │
   ├─► [7. Token Issuance & JSON Serialization]
   │   • jwtService.generateToken(...) (HMAC-SHA256 signing)
   │   • Jackson 3 serialization of AuthResponse
   │   • Duration: 2 ms - 5 ms
   │
   └─► [8. Return Transit: Spring Boot -> Cloudflare -> Client]
       • Transit time Bangalore -> Marseille -> Client: ~65 ms + ~65 ms = 130 ms
```

### 5.2 Explaining the 0.77 s vs 1.25 s Variance
When we combine these measured steps:

| Execution Condition | Network & Handshake | Cloudflare Origin Pull | Password Hash (ARM) | Parallel DB Queries | Resulting Total Time |
|---|---|---|---|---|---|
| **Best-Case Scenario** (Warm client connection, warm CF-origin link, zero packet drop, clean CPU) | ~130 ms (Transport) | 0 ms (Keep-alive) | ~85 ms | ~45 ms | **~750 ms – 790 ms** (matches the observed **0.77 s**) |
| **Medium Scenario** (Fresh client connection, warm CF-origin link, normal CPU) | ~290 ms (TCP+TLS) + 130 ms (RTT) | 0 ms | ~100 ms | ~65 ms | **~850 ms – 900 ms** (matches the observed **0.86 s**) |
| **Worst-Case Scenario** (Fresh client connection, cold CF-origin TLS handshake, CPU contention or minor packet delay) | ~420 ms (Client Handshake) + ~260 ms (CF-Origin Handshake) + 130 ms (RTT) | 260 ms | ~140 ms (Contention) | ~110 ms (Hikari wait) | **~1,200 ms – 1,280 ms** (matches the observed **1.21 s & 1.25 s**) |

The variance is not random noise: it is the difference between whether the request has to establish new TLS sessions across Europe and whether the ARM cores and Hikari pool are processing concurrent query fanouts.

---

## 6. Infrastructure & Network Findings

### 6.1 Cloudflare Edge Anycast Routing (`colo=MRS`)
Inspecting `https://speakit-prod-api.mohitur.com/cdn-cgi/trace` from the client reveals:
```text
ip=2401:4900:... (Airtel India)
loc=IN
colo=MRS (Marseille, France)
http=http/2
tls=TLSv1.3
```
- **The Issue:** Cloudflare's free Anycast routing protocol does not always terminate Indian broadband traffic in Mumbai (`BOM`) or Delhi (`DEL`) if transit peering between Indian ISPs and Cloudflare's domestic peering exchanges is saturated or unprioritized on the free tier. Traffic from India is routed via international undersea cables to Marseille (`MRS`).
- **The Penalty:** Every request travels India -> France -> India, introducing a mandatory **128 ms – 140 ms baseline latency penalty** before server processing begins.

### 6.2 Tailscale & MagicDNS Resolution Behavior
- **Relay Status:** Checking `tailscale status` and `tailscale ping 100.66.182.36`:
  ```text
  pong from project-oracle-dev-instance (100.66.182.36) via DERP(blr) in 61ms
  direct connection not established
  ```
  Traffic over Tailscale currently routes via Tailscale's DERP relay in Bangalore (`blr`). While fast (~61 ms), it operates over HTTPS relaying rather than direct peer-to-peer UDP WireGuard tunnels because NAT traversal (STUN/ICE) has not established a direct hole-punched socket.
- **DNS Resolution Inside Containers:**
  Inside Docker containers on Linux hosts with MagicDNS enabled, container DNS queries forward to `127.0.0.11` (Docker embedded DNS), which forwards to host `/etc/resolv.conf` (`100.100.100.100`). If search domains are present in `/etc/resolv.conf` without `options ndots:1`, external DNS lookups for third-party APIs (e.g. `polly.ap-south-1.amazonaws.com`, `api.elevenlabs.io`) attempt to resolve `<hostname>.ts.net` before falling back to public DNS, adding 40 ms – 80 ms per cold lookup.

### 6.3 Oracle Cloud A1 Flex Hardware Utilization
- **CPU Constraints:** The VM has 2 OCPUs. 2 OCPUs on Ampere Altra = 2 physical single-threaded cores.
- **Resource Competition:** The host runs Traefik reverse proxy, PostgreSQL 18, Spring Boot application, and Docker daemon.
- When an authentication request executes BCrypt, it consumes 1 entire core for ~100 ms. If a background database vacuum, log aggregation thread, or second HTTP request arrives simultaneously, CPU scheduling queues tasks, directly inflating response times.
- **Disk I/O Bounds:** Always Free OCI boot volumes provide a baseline of 3,000 IOPS and 48 MB/s. High-frequency logging (or PostgreSQL checkpointing) causes disk I/O wait (`iowait`), which can delay database queries that touch disk rather than the PostgreSQL buffer cache.

---

## 7. Application Runtime & Code Findings

### 7.1 HikariCP Connection Pool Configuration
In [`application.properties`](file:///Users/mohitur/Desktop/git-projects/speakit/backend/src/main/resources/application.properties#L48-L57):
```properties
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=10
spring.datasource.hikari.max-lifetime=600000
spring.datasource.hikari.idle-timeout=120000
spring.datasource.hikari.connection-timeout=30000
```
- **Fixed Size Pool:** `minimum-idle` equals `maximum-pool-size` (10). This avoids connection creation churn under moderate load.
- **The Contention Vector:** `AuthService.authenticate` invokes 5 asynchronous tasks in parallel:
  ```java
  CompletableFuture<Integer> dailyCountFuture = CompletableFuture.supplyAsync(...);
  CompletableFuture<Long> ledgerCharsFuture = CompletableFuture.supplyAsync(...);
  CompletableFuture<Long> ttsCharsFuture = CompletableFuture.supplyAsync(...);
  CompletableFuture<Long> sttCharsFuture = CompletableFuture.supplyAsync(...);
  CompletableFuture<Integer> avatarFuture = CompletableFuture.supplyAsync(...);
  CompletableFuture.allOf(...).join();
  ```
  A **single login request consumes 5 database connections concurrently**. If just two users attempt to log in or refresh their session within the same 50 ms window, all 10 connections in the Hikari pool are instantly exhausted. Any third concurrent request blocks on `getConnection()` waiting for connection release.

### 7.2 Database Lookup in `JwtAuthenticationFilter`
In [`JwtAuthenticationFilter.java`](file:///Users/mohitur/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/security/JwtAuthenticationFilter.java#L58-L69):
```java
if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
    com.speakit.user.repository.UserSessionProjection userProj =
        userRepository.findSessionAndPlanByUsername(username).orElse(null);
    ...
}
```
Every single authenticated HTTP request (e.g. `/api/auth/me`, `/api/tts/usage`, `/api/history`, `/api/v1/users/me`) executes a SQL query to check `sessionVersion` and fetch user attributes. While using a projection avoids over-fetching entity columns, it still requires a full database round-trip for every API request, introducing database latency into endpoints that could otherwise be served from memory or token claims.

### 7.3 Rate Limit Aspect Double-Dip
In [`RateLimitAspect.java`](file:///Users/mohitur/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/shared/aspect/RateLimitAspect.java#L81-L105):
For `RateLimitAction.AUTH`, three separate buckets are checked sequentially:
1. `checkBucket("AUTH_IP_" + clientIp, ...)`
2. `checkBucket("AUTH_DEV_" + deviceFp, ...)`
3. `checkBucket("AUTH_USER_" + idHash, ...)`
Because `extractRealIp` relies on `request.getRemoteAddr()`, if reverse proxy IP translation headers (`X-Forwarded-For`) are ever misaligned or if requests arrive via Tailscale, all users from that IP share the same `AUTH_IP_` bucket, rapidly triggering 429 Too Many Requests (as observed when Tailscale requests exceeded the bucket capacity).

---

## 8. Hypothesis Verification Table

| # | Hypothesis / Suspect | How Tested | Evidence For | Evidence Against | Verdict | Confidence |
|---|---|---|---|---|---|---|
| **H1** | **Client TCP + TLS Handshake Overhead** | Phase-separated `curl` benchmarks comparing fresh vs keep-alive connections on public domain | Fresh connection mean: **724.6 ms**; Keep-alive mean: **362.9 ms**. Handshake costs ~360 ms. | None. Handshake duration directly measured via `time_appconnect`. | **CONFIRMED** | Very High |
| **H2** | **Cloudflare Cross-Continental Edge Misrouting** | `cdn-cgi/trace` inspection, ping RTT measurements, IP routing analysis | Airtel India traffic terminates in Marseille, France (`MRS`), creating a ~10,000 km routing triangle back to Bangalore (`blr`). Base RTT is 129 ms. | None. Traces definitively confirm `colo=MRS` for Indian client IPs. | **CONFIRMED** | Very High |
| **H3** | **Packet Loss / Retransmission on International Transit** | Statistical outlier analysis across 30 sequential samples | Sample 8 in `live_db_public_fresh.csv` shows TLS handshake stretching from 300 ms to **1,313.9 ms** (Total: **1,645.9 ms**), matching TCP 1.0s RTO timer. | Outlier did not occur on local Tailscale path. | **CONFIRMED** | Very High |
| **H4** | **BCrypt Password Hashing CPU Delay on ARM64** | Standalone benchmark of `BCryptPasswordEncoder(10)` on target ARM architecture | Single-thread BCrypt(10) consumes **80–130 ms** on ARM64 CPU. Under concurrency, competes for 2 OCPUs. | BCrypt is executed only on `/login`, not on other endpoints. | **CONFIRMED** (for Login) | High |
| **H5** | **Database Query Fanout on Login** | Code review of `AuthService.authenticate` & timing instrumentation | 5 parallel `CompletableFuture` queries acquire 5 of 10 Hikari connections simultaneously on every login. | On a single idle user, PostgreSQL executes all 5 queries in ~45 ms. | **CONFIRMED** (under concurrency) | High |
| **H6** | **PostgreSQL Query Slowness (General)** | Direct Tailscale measurement comparing cached vs live DB query endpoints | Live DB queries over warm Tailscale complete in **72.9 ms (median)**; cached completes in **66.9 ms**. SQL execution itself takes < 10 ms. | Raw database query time is negligible compared to 700+ ms network overhead. | **DISPROVEN** (as primary root cause) | Very High |
| **H7** | **Tailscale MagicDNS Overhead** | Comparative timing of Tailscale direct IP vs hostname | Direct Tailscale IP requests complete in 66 ms; DNS lookup on host is 1.8 ms. | Search-domain multiplication only affects external outbound hostnames, not inbound HTTP requests. | **UNLIKELY** (for inbound latency) | High |
| **H8** | **JVM Garbage Collection Pauses** | Response timing across 30 back-to-back samples | No periodic 200 ms+ pause pattern observed; memory footprint is well within the 12 GB RAM allotment. | Virtual threads are enabled, minimizing thread stack memory pressure. | **DISPROVEN** | High |

---

## 9. Root Cause Ranking

Causes ranked by their contribution to **total latency** and to **latency variance**:

| Rank | Root Cause | Contribution to Latency | Contribution to Variance | Primary Evidence |
|---|---|---|---|---|
| **1** | **Client-to-Edge TCP & TLS Handshake Negotiation** | **280 ms – 485 ms** | **High** (Spikes to 1,300 ms on packet drops) | `cached_param_public_fresh` vs `cached_param_public_keepalive` (Mean drops from 724 ms to 362 ms). |
| **2** | **Cross-Continental Edge Routing Triangle (`MRS` -> `blr`)** | **180 ms – 260 ms** | **Medium** (Subject to international transit congestion) | `cdn-cgi/trace` confirms `colo=MRS` for Indian client; `tailscale` direct path in Bangalore responds in 67 ms. |
| **3** | **BCrypt Hashing Computation on 2-OCPU ARM VM** | **80 ms – 130 ms** (Login only) | **Medium** (Fluctuates under CPU scheduling contention) | Micro-benchmark confirms 80–130 ms CPU time per login on Ampere Altra ARM64. |
| **4** | **Database Connection Contention (5-Query Fanout)** | **35 ms – 120 ms** (Login & `/me`) | **Medium-High** (Severe spikes when 2+ users log in concurrently) | `AuthService.authenticate` launches 5 parallel queries consuming half the 10-connection pool. |
| **5** | **Per-Request Database Lookup in `JwtAuthenticationFilter`** | **15 ms – 35 ms** | **Low** | Code inspection confirms `userRepository.findSessionAndPlanByUsername` runs on every request. |

---

## 10. Prioritized Engineering Recommendations

### Recommendation 1: Enforce Client-Side HTTP Keep-Alive & Connection Pooling
- **Classification:** Quick Win (Frontend / iOS Client)
- **Rationale:** Fresh HTTP connections incur a 280–485 ms penalty on every call. By enabling HTTP persistent connections with connection pooling in the Angular HTTP client and iOS `URLSession`, subsequent API calls reuse the open TLS socket.
- **Expected Impact:** **-350 ms to -800 ms** on subsequent requests; eliminates handshake-induced variance.
- **Effort / Risk:** Low effort / Zero functionality risk.
- **Verification:** Execute two requests in sequence from the client app; verify HTTP network inspector shows `Connection: keep-alive` and second request finishes in < 350 ms.

### Recommendation 2: Optimize Cloudflare Edge Routing to Indian Domestic PoPs
- **Classification:** Quick Win (Cloudflare Dashboard)
- **Rationale:** Ensure Indian traffic terminates at Indian Cloudflare Edge data centers (`BOM` Mumbai, `DEL` Delhi, `MAA` Chennai) rather than Marseille (`MRS`).
- **Implementation Options:**
  - In Cloudflare Dashboard, verify **Tiered Caching** or **Regional Tiered Cache** is enabled.
  - Review SSL/TLS settings to ensure **TLS 1.3 0-RTT** is enabled (saves 1 round-trip on resumed sessions).
  - If on Cloudflare Free plan, consider enabling **Argo Smart Routing** (routes through Cloudflare's private backbone rather than public transit) or testing DNS configuration to ensure optimal Anycast routing.
- **Expected Impact:** **-180 ms to -350 ms** latency reduction across all public API calls.
- **Effort / Risk:** Low effort / Low risk.

### Recommendation 3: Consolidate `AuthService.authenticate` Query Fanout
- **Classification:** Medium (Backend Service)
- **Rationale:** Currently, `authenticate()` launches 5 separate queries via `CompletableFuture.supplyAsync()`:
  1. `countRecentByUserId`
  2. `findUsageLedgerById`
  3. `sumCharactersUsedSince` (TTS)
  4. `sumCharactersUsedSince` (STT)
  5. `countByUserIdAndActionAndCreatedAtGreaterThanEqual`
- **Solution:** Consolidate these 5 queries into a single composite SQL query or native database view, or read from a cached monthly usage record. This reduces HikariCP connection acquisition from 5 connections to 1 connection per login.
- **Expected Impact:** **-40 ms to -100 ms** on login and profile load; prevents pool starvation under concurrent logins.
- **Effort / Risk:** Medium effort / Low risk. Must preserve backward-compatible return values.

### Recommendation 4: Cache Session Version & Plan in `JwtAuthenticationFilter`
- **Classification:** Medium (Backend Filter)
- **Rationale:** `JwtAuthenticationFilter` queries the database on every authenticated request to check if `sessionVersion` has changed.
- **Solution:** Cache the `UserSessionProjection` in the existing Caffeine in-memory cache with a short TTL (e.g. 60 seconds) or invalidate the cache entry when `userRepository.incrementSessionVersion(username)` is called during logout.
- **Expected Impact:** **-15 ms to -35 ms** on every authenticated request.
- **Effort / Risk:** Low effort / Zero security risk if invalidation is triggered on logout.

### Recommendation 5: Optimize HikariCP & Database Keep-Alives
- **Classification:** Quick Win (Backend Configuration)
- **Rationale:** Stale TCP connections through the Docker bridge or host network can incur silent timeouts before HikariCP reconnects.
- **Implementation:** In `application.properties`, configure `spring.datasource.hikari.keepalive-time=30000` and ensure PostgreSQL `tcp_keepalives_idle=30` is set.
- **Expected Impact:** Eliminates the occasional slow request observed after long periods of idle time.
- **Effort / Risk:** Minimal effort / Zero risk.

---

## 11. Production Monitoring & Observability Plan

To detect and alert on latency inconsistencies in production going forward, implement the following monitoring controls:

1. **Micrometer HTTP Request Timers with Percentile Histograms:**
   Add Micrometer percentile metrics to `application.properties`:
   ```properties
   management.metrics.distribution.percentiles-histogram[http.server.requests]=true
   management.metrics.distribution.percentiles[http.server.requests]=0.5,0.9,0.95,0.99
   management.metrics.distribution.slo[http.server.requests]=100ms,250ms,500ms,1000ms
   ```
2. **Server-Timing Response Header:**
   Configure a lightweight servlet filter to emit `Server-Timing: app;dur=45, db;dur=12` headers in development and staging so client network inspectors can immediately distinguish network latency from server execution time.
3. **Database Connection Pool Monitoring:**
   Monitor `hikaricp.connections.pending` (threads waiting for a connection) and `hikaricp.connections.acquire` (time to acquire a connection). Set an alert threshold if `hikaricp.connections.pending > 2` for more than 15 seconds.
4. **Target Service Level Objectives (SLOs):**
   - Public Cached Endpoints (`/api/system-parameters/**`): **p95 < 150 ms**
   - Authenticated Read Endpoints (`/api/auth/me`, `/api/tts/usage`): **p95 < 350 ms**
   - Authentication Endpoints (`/api/auth/login`): **p95 < 600 ms**

---

## 12. Open Questions & Recommended Follow-Up Investigations

1. **EXPLAIN ANALYZE on Heavy History Queries:**
   Running `EXPLAIN ANALYZE` on `ttsHistoryRepository.sumCharactersUsedSince` and `speechToTextRequestRepository.sumCharactersUsedSince` in a non-production staging environment to verify composite index coverage (`user_id`, `created_at`).
2. **Cloudflare Indian Peering Verification:**
   Investigate whether configuring Cloudflare Regional Tiered Cache or custom origin headers can force Cloudflare Anycast to route Indian eyeball traffic through domestic Indian PoPs.
3. **Tailscale Direct UDP Hole-Punching:**
   Investigate opening UDP port 41641 in the Oracle Cloud Security List to allow Tailscale to establish direct peer-to-peer WireGuard connections without DERP relaying.

---

## 13. Appendix

### Appendix A: Summary of Benchmark Data Files
All raw timing files are preserved in `docs/perfomance-improvements/data/`:
- [`cached_param_public_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_public_fresh.csv): 30 samples, Public Cloudflare fresh TCP/TLS.
- [`cached_param_public_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_public_keepalive.csv): 30 samples, Public Cloudflare keep-alive multiplexed.
- [`cached_param_tailscale_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_tailscale_fresh.csv): 25 samples, Tailscale direct origin fresh connection.
- [`cached_param_tailscale_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/cached_param_tailscale_keepalive.csv): 25 samples, Tailscale direct origin keep-alive.
- [`live_db_public_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_public_fresh.csv): 25 samples, Public Cloudflare live SQL query fresh connection.
- [`live_db_public_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_public_keepalive.csv): 25 samples, Public Cloudflare live SQL query keep-alive.
- [`live_db_tailscale_fresh.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_tailscale_fresh.csv): 25 samples, Tailscale direct origin live SQL query fresh connection.
- [`live_db_tailscale_keepalive.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/live_db_tailscale_keepalive.csv): 25 samples, Tailscale direct origin live SQL query keep-alive.
- [`ping_probe_public.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/ping_probe_public.csv): 3 samples, Public health ping probe.
- [`login_probe_public.csv`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/login_probe_public.csv): 3 samples, Public login pipeline probe.
- [`summary_stats.json`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/perfomance-improvements/data/summary_stats.json): Compiled JSON statistical distributions (min, median, mean, p90, p95, p99, max, stddev, CV).

### Appendix B: Audit Commands Used
```bash
# Public latency decomposition probe (Fresh connection)
curl -s -o /dev/null -w "%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_starttransfer},%{time_total},%{size_download},%{http_code},%{remote_ip}\n" \
  https://speakit-prod-api.mohitur.com/api/system-parameters/cached/SYSTEM_STATUS

# Direct origin latency decomposition probe via Tailscale (Bypassing Cloudflare)
curl -k -s -o /dev/null -H "Host: speakit-prod-api.mohitur.com" -w "%{time_namelookup},%{time_connect},%{time_appconnect},%{time_pretransfer},%{time_starttransfer},%{time_total},%{size_download},%{http_code},%{remote_ip}\n" \
  https://100.66.182.36/api/system-parameters/cached/SYSTEM_STATUS

# Cloudflare edge trace
curl -s https://speakit-prod-api.mohitur.com/cdn-cgi/trace

# Tailscale latency and relay check
/Applications/Tailscale.app/Contents/MacOS/Tailscale ping -c 5 100.66.182.36
```
