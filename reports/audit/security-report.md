# SpeakIT Defensive Security Audit Report

## 1. Executive Summary
SpeakIT is a full-stack SaaS platform designed with several robust security principles in place, including parameterized SQL querying, centralized Spring Security JWT authorization filters, and HTML input sanitization with JSoup. However, the current codebase contains configuration and design flaws that compromise its production integrity. The systemd deployment environment contains folder permission misconfigurations allowing Local Privilege Escalation to root. In addition, in-memory caching maps lack key eviction parameters, posing Denial of Service (DoS) memory leak risks, and outbound integrations with ElevenLabs allow path traversal via unconstrained voice parameters.

---

## 2. Industry Baseline Comparison
As a consumer-facing text-to-speech SaaS application, SpeakIT resembles mainstream platforms like play.ht and ElevenLabs. 
- **Tech Stack Security**: Using Spring Boot 3.5.11 and Java 21 is a highly secure baseline, offering robust memory-safety protections and structured logging with MDC context.
- **Key Divergence**: Mainstream platforms typically rely on expiring caches (like Redis, Caffeine, or Memcached) to handle high-frequency data (like deduplication and rate-limiting keys). Storing rate limits indefinitely in-memory diverges from standard secure operational engineering.

---

## 3. Summary of Findings

| ID | Severity | Title | CWE | OWASP Top 10 | Target | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | **HIGH** | Local Privilege Escalation via Cron Path Ownership | CWE-276 | A05:2021-Security Misconfiguration | [server-initial-setup.sh](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/deployment/scripts/server-initial-setup.sh) | ✅ Remediated |
| **SEC-02** | **MEDIUM** | Indefinite Memory Leak in Rate-Limiting Cache | CWE-770 | A05:2021-Security Misconfiguration | [RateLimitConfig.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/config/RateLimitConfig.java) | ✅ Remediated |
| **SEC-03** | **MEDIUM** | Memory Leak in STT Deduplication Map | CWE-770 | A05:2021-Security Misconfiguration | [SttService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/stt/service/SttService.java) | ✅ Remediated |
| **SEC-04** | **MEDIUM** | Outbound Path Traversal in ElevenLabs TTS Service | CWE-22 | A01:2021-Broken Access Control | [ElevenLabsService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/tts/service/ElevenLabsService.java) | ✅ Remediated |
| **SEC-05** | **LOW** | Payment Signature Verification Timing Attack | CWE-208 | A02:2021-Cryptographic Failures | [RazorpayService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/billing/service/RazorpayService.java) | ✅ Remediated |
| **SEC-06** | **LOW** | Missing Security Headers in Production Deployments | CWE-693 | A05:2021-Security Misconfiguration | [nginx.conf](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/nginx.conf) / [vercel.json](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/vercel.json) | ✅ Remediated |

---

## 4. Detailed Findings

### SEC-01: Local Privilege Escalation via Cron Path Ownership (HIGH)
- **File**: [server-initial-setup.sh](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/deployment/scripts/server-initial-setup.sh#L58-L65)
- **Intended Behavior**: Root-executed cron tasks should live in secure directories where write access is restricted only to root.
- **Root Cause**: The script recursively changes ownership of `/opt/speakit` to the low-privileged `deploy` user while running `/opt/speakit/monitor.sh` under the root crontab.
- **Attack Scenario**: A compromised `deploy` user deletes the `/opt/speakit/monitor.sh` file and replaces it with a script that writes to `/etc/sudoers`. When the root cron runs the script (within 60 seconds), it executes as root and escalates the deploy user to full root access.
- **Remediation**:
  Ensure `/opt/speakit` is owned by `root:root` with permissions `755` so that the `deploy` user cannot replace scripts in that directory. Create a specific subdirectory like `/opt/speakit/backend` owned by `deploy` for deployments.

---

### SEC-02: Indefinite Memory Leak in Rate-Limiting Cache (MEDIUM)
- **File**: [RateLimitAspect.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/shared/aspect/RateLimitAspect.java#L45)
- **Intended Behavior**: Rate-limiting buckets should be stored in a self-expiring cache.
- **Root Cause**: A ConcurrentHashMap `rateLimitBuckets` stores rate-limiting buckets permanently, and never evicts keys.
- **Attack Scenario**: An attacker runs a script that sends requests from rotating IP addresses and device fingerprints. This forces the server to keep adding entries to the map until JVM memory is exhausted, causing an OutOfMemoryError (OOM) and DoS.
- **Remediation**:
  Refactor `RateLimitConfig.java` to define `rateLimitBuckets` using a Caffeine cache with an expiration policy:
  ```java
  @Bean
  public Cache<String, Bucket> rateLimitBuckets() {
      return Caffeine.newBuilder()
              .expireAfterAccess(Duration.ofMinutes(30))
              .maximumSize(100000)
              .build();
  }
  ```

---

### SEC-03: Memory Leak in STT Deduplication Map (MEDIUM)
- **File**: [SttService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/stt/service/SttService.java#L38)
- **Intended Behavior**: Duplicate request fingerprints should expire after the deduplication window (60 seconds).
- **Root Cause**: The Map `messageFingerprints` accumulates hashes for every audio file submitted and never evicts them.
- **Attack Scenario**: Authenticated users upload audio files over a long period. The memory footprint grows continuously until the JVM crashes with an OOM.
- **Remediation**:
  Use Caffeine or Guava cache with `.expireAfterWrite(Duration.ofSeconds(60))` instead of a raw `ConcurrentHashMap`.

---

### SEC-04: Outbound Path Traversal in ElevenLabs TTS Service (MEDIUM)
- **File**: [ElevenLabsService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/tts/service/ElevenLabsService.java#L37)
- **Intended Behavior**: The voice ID parameter should only accept alphanumeric characters.
- **Root Cause**: The user-supplied `voiceId` parameter is directly concatenated into the outbound URL path without validating it is a valid token.
- **Attack Scenario**: An attacker submits a voice ID containing traversal characters, e.g. `../../voices`. This forces the server to call a different ElevenLabs endpoint under the context of the server's ElevenLabs API key.
- **Remediation**:
  Validate that `voiceId` matches an alphanumeric regex (e.g., `^[a-zA-Z0-9_-]+$`) before appending it to API endpoint URLs.

---

### SEC-05: Payment Signature Verification Timing Attack (LOW)
- **File**: [RazorpayService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/billing/service/RazorpayService.java#L192)
- **Intended Behavior**: Cryptographic signatures should be compared in constant time to prevent side-channel timing leaks.
- **Root Cause**: Standard string comparison `equals()` is used to verify payment signatures.
- **Attack Scenario**: An attacker measures high-precision response times to determine how many characters of a guessed signature match, eventually forging a valid signature to bypass subscription payment.
- **Remediation**:
  Use `MessageDigest.isEqual` to compare signatures:
  ```java
  return java.security.MessageDigest.isEqual(hexString.toString().getBytes(StandardCharsets.UTF_8), signature.getBytes(StandardCharsets.UTF_8));
  ```

---

### SEC-06: Missing Security Headers in Production Deployments (LOW)
- **Files**: [nginx.conf](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/nginx.conf) / [vercel.json](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/vercel.json)
- **Intended Behavior**: Production web servers should serve HTTP security headers.
- **Root Cause**: The Nginx container and Vercel configuration do not define headers like `X-Frame-Options`, `X-Content-Type-Options`, or `Strict-Transport-Security`.
- **Attack Scenario**: Clients are vulnerable to Clickjacking or MIME-sniffing when the application is accessed directly via Vercel or the standalone Nginx container.
- **Remediation**:
  Configure security headers inside `vercel.json` and `nginx.conf`.

---

## 5. Hardening Notes (Defense-In-Depth)
1. **Redis Rate Limiting**: The rate-limiting configuration uses in-memory maps which will not synchronize across multiple API instances. Migrate to Redis-based rate limiting for horizontal scaling.
2. **WebSocket Origin restrictions**: Specify explicit allowed origins (e.g. `https://yourdomain.com`) in `WebSocketConfig` rather than relying on wildcard allowed origin patterns (`*`).

---

## 6. Positive Security Patterns
1. **No SQL Injection**: All queries in the database repositories utilize JPA bindings, avoiding raw string concatenation.
2. **No CSWSH**: WebSocket connections require short-lived tickets generated from authenticated endpoints, preventing Cross-Site WebSocket Hijacking.
3. **No Stale Sessions**: `JwtAuthenticationFilter` checks token versions against the database on every request, ensuring that logging out from all devices invalidates JWTs immediately.
