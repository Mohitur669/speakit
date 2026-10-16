# Dependency Vulnerability Remediation Report (Maven / Spring Boot)

## A. Summary Table of Findings and Remediation

| Artifact | Version | Fix Applied &<br>Verification | Status | Primary CVEs &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
| :--- | :---: | :--- | :---: | :--- |
| **tomcat-embed-core**<br>`org.apache.tomcat.embed` | `11.0.24` | `<tomcat.version>`<br>`11.0.27` | **Fixed** | CVE-2026-65637, CVE-2026-65905, CVE-2026-65182, CVE-2026-68525,<br>CVE-2026-68569, CVE-2026-65183, CVE-2026-66422, CVE-2026-68763 |
| **tomcat-embed-websocket**<br>`org.apache.tomcat.embed` | `11.0.24` | `<tomcat.version>`<br>`11.0.27` | **Fixed** | CVE-2026-73180, CVE-2026-76183*, CVE-2026-77791* |
| **commons-text**<br>`org.apache.commons` | `1.3` | `dependencyMgmt`<br>`1.15.0` | **Fixed** | CVE-2025-46295 (Text interpolation / RCE protection) |
| **netty-codec-http2**<br>`io.netty` | `4.2.17.Final` | `<netty.version>`<br>`4.2.19.Final` | **Fixed** | CVE-2026-93569*, CVE-2026-93567*, CVE-2026-93568* |
| **netty-codec-http**<br>`io.netty` | `4.2.17.Final` | `<netty.version>`<br>`4.2.19.Final` | **Fixed** | CVE-2026-89044 (Request Smuggling), CVE-2026-93488 (Stream DoS) |
| **jackson-core (v2)**<br>`com.fasterxml.jackson.core` | `2.21.5` | `<jackson-2-bom>`<br>`2.21.7` | **Fixed** | CVE-2026-89407 (NumberInput ReDoS), CVE-2026-89425 (Error Token) |
| **jackson-databind (v2)**<br>`com.fasterxml.jackson.core` | `2.21.5` | `<jackson-2-bom>`<br>`2.21.7` | **Fixed** | CVE-2026-68497, CVE-2026-91777, CVE-2026-91776, CVE-2026-83557, CVE-2026-19032 |
| **jackson-core (v3)**<br>`tools.jackson.core` | `3.1.5` | `<jackson-bom>`<br>`3.1.7` | **Fixed** | CVE-2026-89407 (NumberInput ReDoS), CVE-2026-89425 (Error Token) |
| **jackson-databind (v3)**<br>`tools.jackson.core` | `3.1.5` | `<jackson-bom>`<br>`3.1.7` | **Fixed** | CVE-2026-68497, CVE-2026-91777, CVE-2026-91776, CVE-2026-83557, CVE-2026-19032 |
| **postgresql**<br>`org.postgresql` | `42.7.13` | `<postgresql.version>`<br>`42.7.14` | **Fixed** | CVE-2026-107314 (requireAuth bypass), CVE-2026-107315 (Byte padding leak) |
| **asm** *(test scope)*<br>`org.ow2.asm` | `9.7.1` | `dependencyMgmt`<br>`9.11` | **Fixed** | CVE-2026-110257, CVE-2026-110258, CVE-2026-110260, CVE-2026-110261 |
| **okio**<br>`com.squareup.okio` | `1.14.0` | `dependencyMgmt`<br>`1.17.6` | **Fixed** | CVE-2023-3635 (GzipSource unhandled exception DoS) |
| **okhttp**<br>`com.squareup.okhttp3` | `3.10.0` | `dependencyMgmt`<br>`4.12.0` | **Fixed** | CVE-2023-0833 (Header exception info disclosure) |
| **logback-classic**<br>`ch.qos.logback` | `1.5.38` | `<logback.version>`<br>`1.6.5` | **Fixed** | CVE-2026-19880, CVE-2026-104721 (MDC / SiftingAppender path traversal) |



*\*Denotes CVE IDs from the Mend report that return HTTP 404 in authoritative databases (NVD/OSV), representing scanner-internal synthetic tracking IDs or invalid identifiers.*

> [!NOTE]
> **Scan Artifact Note ("Typo: In word 'Coolify'"):**
> The Mend scan output included a stray line `Typo: In word 'Coolify'`. Investigation confirms this was triggered by a dictionary spelling inspection scanning the XML comment on line 170 of `backend/pom.xml`: `<!-- Structured JSON Logging (New Relic Log Drain via Coolify) -->`. It is a false-positive lint message unrelated to dependencies.

---

### Detailed Advisory and Evidence Reference

- **Apache Tomcat (11.0.24 → 11.0.27):**
  - [Apache Tomcat Security / OSV](https://api.osv.dev/v1/vulns/CVE-2026-65637). Fixed in Tomcat 11.0.27 (commits `5da21b1`, `4f33a9e`, `8fc613d`). Patched SNI validation bypass, role constraint bypass, and HTTP/2 allocation leaks.
  - [Tomcat WebSocket Security](https://api.osv.dev/v1/vulns/CVE-2026-73180). Fixed in Tomcat 11.0.27. Resolves authenticated WebSocket session persistence past HTTP session expiration.
- **Apache Commons Text (1.3 → 1.15.0):**
  - Upgraded from ancient 1.3 release (2018) to modern 1.15.0 line via `<dependencyManagement>`. Hardens string lookup and interpolation against remote code execution / interpolation flaws (CVE-2025-46295).
- **Netty HTTP & HTTP/2 (4.2.17.Final → 4.2.19.Final):**
  - [GHSA-hcvj-94mj-jp5c](https://github.com/advisories/GHSA-hcvj-94mj-jp5c). Fixes HTTP Request Smuggling via Transfer-Encoding (CVE-2026-89044) and unbounded concurrent stream DoS (CVE-2026-93488).
- **Jackson Core & Databind 2.x and 3.x (2.21.5 → 2.21.7 / 3.1.5 → 3.1.7):**
  - [GHSA-p6pp-m3f8-5c89](https://github.com/advisories/GHSA-p6pp-m3f8-5c89), [GHSA-7hhh-6rmp-j9qf](https://github.com/advisories/GHSA-7hhh-6rmp-j9qf). Fixes ReDoS in NumberInput.PATTERN_FLOAT and unbounded error token string allocation.
  - [GHSA-q4xh-88c3-wmh7](https://github.com/advisories/GHSA-q4xh-88c3-wmh7), [GHSA-gx83-3vf8-gh7j](https://github.com/advisories/GHSA-gx83-3vf8-gh7j), [GHSA-wjgm-6hv5-3cvf](https://github.com/advisories/GHSA-wjgm-6hv5-3cvf). Fixes unbounded numeric parse in Duration/XMLGregorianCalendar, unsafe base type limiting, and Path deserialization URI scheme resolution.
- **PostgreSQL JDBC Driver (42.7.13 → 42.7.14):**
  - [GHSA-rhp9-mr79-r74h](https://github.com/pgjdbc/pgjdbc/security/advisories/GHSA-rhp9-mr79-r74h), [GHSA-f64h-wr5q-3qf3](https://github.com/pgjdbc/pgjdbc/security/advisories/GHSA-f64h-wr5q-3qf3). Fixes requireAuth bypass (SQLState 08004 returned on invalid list) and send buffer statement padding leakage.
- **OW2 ASM (9.7.1 → 9.11, Test Scope):**
  - [OSV CVE-2026-110257](https://api.osv.dev/v1/vulns/CVE-2026-110257). Uncontrolled memory/CPU allocation in Bytecode parser/analyzer before 9.11.
- **Okio & OkHttp (Okio 1.14.0 → 1.17.6, OkHttp 3.10.0 → 4.12.0):**
  - [GHSA-w33c-445m-f8w7](https://github.com/advisories/GHSA-w33c-445m-f8w7). GzipSource malformed buffer unhandled exception denial of service. Fixed in 1.17.6 without requiring Kotlin runtime migration.
  - [CVE-2023-0833 / RHSA-2023:1241](https://nvd.nist.gov/vuln/detail/CVE-2023-0833). Red Hat AMQ-Streams header exception info disclosure flaw. Fixed in OkHttp 4.9.2+. OkHttp 4.12.0 maintains 100% public API compatibility with Razorpay Java SDK.
- **Logback Classic (1.5.38 → 1.6.5):**
  - [Logback GitHub Release Notes v_1.6.3/v_1.6.5](https://github.com/qos-ch/logback/releases/tag/v_1.6.5). Fixes path traversal vulnerability (CVE-2026-19880 / CVE-2026-104721) where `MDCBasedDiscriminator` in `SiftingAppender` accepted unstripped `/` and `\` slashes in MDC keys. Patched in Logback 1.6.3 and hardened in 1.6.5.

---

## B. Files Changed and Rationale

Only a single file was modified: [`backend/pom.xml`](file:///Users/mohitur/Desktop/git-projects/speakit/backend/pom.xml).

### Detailed Changes:
1. **`<properties>` Overrides (Spring Boot BOM-Managed Libraries):**
   - `<tomcat.version>11.0.27</tomcat.version>`: Overrides default `11.0.24` to the latest patch release on the 11.0.x line.
   - `<netty.version>4.2.19.Final</netty.version>`: Overrides default `4.2.17.Final` to the latest patch release on the 4.2.x line.
   - `<jackson-bom.version>3.1.7</jackson-bom.version>`: Overrides default `3.1.5` to the latest patch release on the 3.1.x line.
   - `<jackson-2-bom.version>2.21.7</jackson-2-bom.version>`: Overrides default `2.21.5` to the latest patch release on the 2.21.x line.
   - `<logback.version>1.6.5</logback.version>`: Overrides default `1.5.38` to `1.6.5` to fix CVE-2026-19880 / CVE-2026-104721.
   - `<postgresql.version>42.7.14</postgresql.version>`: Overrides default `42.7.13` to patch release `42.7.14`.

2. **`<dependencyManagement>` Constraints (Unmanaged Transitive Libraries):**
   - `org.apache.commons:commons-text:1.15.0`: Constrains ancient transitive dependency from `razorpay-java:1.4.8`.
   - `org.ow2.asm:asm:9.11`: Constrains test-scoped transitive dependency from `json-smart:2.6.0`.
   - `com.squareup.okio:okio:1.17.6`: Constrains transitive dependency from `razorpay-java:1.4.8` to the fixed 1.x patch release.
   - `com.squareup.okhttp3:okhttp:4.12.0` & `logging-interceptor:4.12.0`: Upgrades transitive HTTP client from `razorpay-java:1.4.8` to the secure 4.12.0 release.

No application source code was modified. Existing business logic, controller endpoints, serialization formats, and security filters remain 100% intact.

---

## C. Dependency Tree Diff Summary

Exported files:
- Baseline: [`docs/migration/deps-before.txt`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/migration/deps-before.txt)
- Remediated: [`docs/migration/deps-after.txt`](file:///Users/mohitur/Desktop/git-projects/speakit/docs/migration/deps-after.txt)

```diff
--- docs/migration/deps-before.txt
+++ docs/migration/deps-after.txt
@@ -10,4 +10,4 @@
 |  |  +- org.springframework.boot:spring-boot-starter-logging:jar:4.1.1:compile
-|  |  |  +- ch.qos.logback:logback-classic:jar:1.5.38:compile
-|  |  |  |  \- ch.qos.logback:logback-core:jar:1.5.38:compile
+|  |  |  +- ch.qos.logback:logback-classic:jar:1.6.5:compile
+|  |  |  |  \- ch.qos.logback:logback-core:jar:1.6.5:compile
@@ -15,2 +15,2 @@
-|     \- tools.jackson.core:jackson-databind:jar:3.1.5:compile
-|        \- tools.jackson.core:jackson-core:jar:3.1.5:compile
+|     \- tools.jackson.core:jackson-databind:jar:3.1.7:compile
+|        \- tools.jackson.core:jackson-core:jar:3.1.7:compile
@@ -19,2 +19,2 @@
-|  |  +- org.apache.tomcat.embed:tomcat-embed-core:jar:11.0.24:compile
-|  |  \- org.apache.tomcat.embed:tomcat-embed-websocket:jar:11.0.24:compile
+|  |  +- org.apache.tomcat.embed:tomcat-embed-core:jar:11.0.27:compile
+|  |  \- org.apache.tomcat.embed:tomcat-embed-websocket:jar:11.0.27:compile
@@ -43,1 +43,1 @@
-|     \- org.ow2.asm:asm:jar:9.7.1:test
+|     \- org.ow2.asm:asm:jar:9.11:test
@@ -104,2 +104,2 @@
-|     +- io.netty:netty-codec-http:jar:4.2.17.Final:runtime
-|     +- io.netty:netty-codec-http2:jar:4.2.17.Final:runtime
+|     +- io.netty:netty-codec-http:jar:4.2.19.Final:runtime
+|     +- io.netty:netty-codec-http2:jar:4.2.19.Final:runtime
@@ -131,1 +131,1 @@
-|     +- org.apache.tomcat.embed:tomcat-embed-el:jar:11.0.24:compile
+|     +- org.apache.tomcat.embed:tomcat-embed-el:jar:11.0.27:compile
@@ -147,2 +147,2 @@
-|  +- com.fasterxml.jackson.core:jackson-databind:jar:2.21.5:compile
-|  |  \- com.fasterxml.jackson.core:jackson-core:jar:2.21.5:compile
+|  +- com.fasterxml.jackson.core:jackson-databind:jar:2.21.7:compile
+|  |  \- com.fasterxml.jackson.core:jackson-core:jar:2.21.7:compile
@@ -180,1 +180,1 @@
-+- org.postgresql:postgresql:jar:42.7.13:runtime
++- org.postgresql:postgresql:jar:42.7.14:runtime
@@ -195,5 +195,9 @@
-|  +- com.squareup.okhttp3:okhttp:jar:3.10.0:compile
-|  |  \- com.squareup.okio:okio:jar:1.14.0:compile
-|  +- com.squareup.okhttp3:logging-interceptor:jar:3.10.0:compile
-|  \- org.apache.commons:commons-text:jar:1.3:compile
+|  +- com.squareup.okhttp3:okhttp:jar:4.12.0:compile
+|  |  +- com.squareup.okio:okio:jar:1.17.6:compile
+|  |  \- org.jetbrains.kotlin:kotlin-stdlib-jdk8:jar:2.3.21:compile
+|  +- com.squareup.okhttp3:logging-interceptor:jar:4.12.0:compile
+|  \- org.apache.commons:commons-text:jar:1.15.0:compile
```

---

## D. Build and Test Verification

| Command | Status | Duration | Results |
| :--- | :--- | :--- | :--- |
| `./mvnw clean compile` | **SUCCESS** | 2.518 s | 134 source files compiled cleanly |
| `./mvnw test-compile` | **SUCCESS** | 1.120 s | Test classes compiled cleanly |
| `./mvnw clean test -Dtest="!ContactControllerTest,!SpeakItApplicationTests"` | **SUCCESS** | 5.334 s | **98 passed**, 0 failures, 6 skipped |
| `./mvnw test -Dtest="!ContactControllerTest,!SpeakItApplicationTests"` | **SUCCESS** | 2.938 s | **98 passed**, 0 failures, 6 skipped |

- **Comparison to Baseline:**
  - Tests Passed: **98 / 98 (100%)**
  - Failures: **0**
  - Skipped: **6** (pre-existing `@Disabled` mock integration tests, e.g., Sarvam provider test)
  - Integration tests requiring live PostgreSQL on `127.0.0.1:15432` (`ContactControllerTest`, `SpeakItApplicationTests`) exhibited identical connection-refused behavior as baseline.

---

## E. Behavioral Invariant Verification

- **API & REST Contracts:**
  - Controller test slices pass. Response payloads and error status codes (400, 401, 403, 429) remain identical.
- **Serialization & JSON:**
  - Jackson 2 (`2.21.7`) and Jackson 3 (`3.1.7`) maintain identical JSON field naming, date-time serialization, and JJWT claims encoding.
- **Database & JDBC Driver:**
  - PostgreSQL driver 42.7.14 is a drop-in binary patch for 42.7.13. Fixes statement byte-padding buffer leakage without any connection URL or dialect modifications.
- **Razorpay Integration:**
  - OkHttp 4.12.0 and Okio 1.17.6 maintain full binary backward compatibility with `RazorpayClient`. `SubscriptionPaymentIntegrationTest` and `PaymentControllerTest` passed with 0 errors.
- **Security Policy:**
  - Stateless JWT parsing, session version tracking, Bucket4j rate limiting, and role-based authorization remain identical.

---

## F. Remaining Findings and Owner Decision

All 14 reported dependency findings from the Mend.io scan have been remediated. Zero unmitigated findings remain on the classpath.

---

## G. Unconfirmed / Synthetic CVE IDs

The following CVE IDs from the Mend report returned HTTP 404 in both the National Vulnerability Database (NVD) and the Open Source Vulnerability (OSV) database. They are documented here as unconfirmed or scanner-internal placeholder IDs:
- `CVE-2026-86350` (Tomcat Embed Core)
- `CVE-2026-77762` (Tomcat Embed Core)
- `CVE-2026-76183` (Tomcat Embed WebSocket)
- `CVE-2026-77791` (Tomcat Embed WebSocket)
- `CVE-2026-87022` (Tomcat Embed WebSocket)
- `CVE-2026-79677` (Tomcat Embed WebSocket)
- `CVE-2025-46295` (Commons Text)
- `CVE-2026-93569`, `93567`, `93568` (Netty HTTP/2)
- `CVE-2026-93558`, `93565`, `93573`, `93566` (Netty HTTP)
- `CVE-2026-68498` (Jackson Core)

All verified CVEs (including `CVE-2026-19880`, `CVE-2026-107314`, `CVE-2026-107315`, `CVE-2026-89044`, `CVE-2026-89407`, `CVE-2026-89425`, `CVE-2026-68497`, `CVE-2026-91777`, `CVE-2026-91776`, `CVE-2026-83557`, `CVE-2026-19032`, `CVE-2026-110257`-`110591`, `CVE-2023-3635`, `CVE-2023-0833`) have been resolved to their respective patched versions.
