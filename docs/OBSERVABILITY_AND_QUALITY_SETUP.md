# SpeakIT Observability & Code Quality Setup Guide

This document is the single source of truth for integrating, configuring, and maintaining Sentry, New Relic, and container security controls on the SpeakIT platform.

---

## 1. ARCHITECTURE SNAPSHOT

```
                                        +-----------------------+
                                        |   Cloudflare (WAF)    |
                                        +-----------+-----------+
                                                    |
                         +--------------------------+--------------------------+
                         | (Public Traffic)                                    | (Tailscale VPN only)
                         v                                                     v
            +------------+------------+                           +------------+------------+
            |  Vercel Static Hosting  |                           |  OCI VM Coolify Admin   |
            |     (Angular 21 App)    |                           |    (Port 8000 / HTTPS)  |
            +------------+------------+                           +------------+------------+
                         |                                                     |
                         | (REST API / JSON)                                   | (GitOps Deployment)
                         v                                                     v
            +------------+------------+                           +------------+------------+
            |  OCI Backend (Coolify)  | <------------------------ |   Docker Image Registry |
            | (Spring Boot 3.5 / JVM) |                           |     (Non-Root execution)|
            +------------+------------+                           +-------------------------+
                         |
      +------------------+------------------+
      | (SQL)            | (REST / SDK)     | (SMTP / SES)
      v                  v                  v
+-----+-----+     +------+------+     +-----+--------+
| PostgreSQL|     |  AWS Polly  |     | Notifications|
| (Supabase)|     | ElevenLabs  |     | (Telegram)   |
+-----------+     +-------------+     +--------------+
```

* **Backend Engine**: Java 21 / Spring Boot 3.5.11 running as a non-root user (`appuser`) inside a lightweight JRE 21 Alpine image.
* **Frontend Client**: Angular 21.2.0 (Standalone Components + Signals) served by a hardened non-root Nginx container on port 8080.
* **Logging System**: Logback configured with a custom message redactor (`LogMaskingAppender`) to scrub PII locally and in transit to New Relic.

---

## 2. SENTRY (REAL-TIME ERROR & PERFORMANCE TRACKING)

Sentry provides client-side error tracing, performance tracing, session replays, and backend exception tracking.

### 2.1 Sentry Dashboard Set Up (Step-by-Step UI Guide)
1. Navigate to [Sentry.io](https://sentry.io) and log in (Sentry provides a free team-tier equivalent via the GitHub Student Developer Pack).
2. In the left navigation sidebar, click on **Projects**.
3. In the top-right corner of the Projects page, click the **Create Project** button.
4. **Set Up the Backend Project**:
   * Under **Choose a platform**, select **Spring Boot** (or **Java** if not visible).
   * Under **Set your project details**, set the project name: `speakit-backend`.
   * Click **Create Project**.
   * Under **Configure SDK**, copy the generated **DSN URL** (looks like `https://publickey@oXXXXXX.ingest.us.sentry.io/XXXXXX`). Write this down as `SENTRY_DSN_BACKEND`.
5. **Set Up the Frontend Project**:
   * Return to **Projects** and click **Create Project** again.
   * Under **Choose a platform**, select **Angular**.
   * Set the project name: `speakit-frontend`.
   * Click **Create Project**.
   * Copy the generated **DSN URL**. Write this down as `SENTRY_DSN_FRONTEND`.
   * Note: Sentry Replay masking is configured directly at the SDK level (not in the dashboard UI settings). Our client-side SDK configuration already sets `maskAllText: true`, `maskAllInputs: true`, and `blockAllMedia: true` by default. To maintain privacy, ensure you do not add the `sentry-unmask` class to any HTML elements containing PII.

---

### 2.2 Backend Spring Boot Integration
1. Add the Sentry dependency to your [pom.xml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/pom.xml):
   ```xml
   <dependency>
       <groupId>io.sentry</groupId>
       <artifactId>sentry-spring-boot-starter-jakarta</artifactId>
       <version>7.8.0</version>
   </dependency>
   ```
2. Add Sentry properties mapping in your [application.properties](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/resources/application.properties):
   ```properties
   sentry.dsn=${SENTRY_DSN_BACKEND:}
   sentry.environment=${SENTRY_ENVIRONMENT:production}
   sentry.traces-sample-rate=${SENTRY_TRACES_SAMPLE_RATE:0.1}
   sentry.release=${SENTRY_RELEASE:}
   sentry.exception-resolver-order=${SENTRY_EXCEPTION_RESOLVER_ORDER:-2147483648}
   sentry.send-default-pii=${SENTRY_SEND_DEFAULT_PII:false}
   ```
   *Note: Setting `exception-resolver-order` to the lowest integer (`-2147483648`) ensures Sentry intercepts unhandled exceptions before standard Spring controller advisors wrap them in general HTTP responses. `send-default-pii=${SENTRY_SEND_DEFAULT_PII:false}` disables the default transmission of client IP addresses and usernames.*

3. We enforce data compliance (DPDP Act 2023 / IT Act 2000) using a custom `BeforeSendCallback` inside [SentryConfig.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/config/SentryConfig.java) that checks incoming events and scrubs standard emails, passwords, OTPs, JWT tokens, authorizations, and API keys before they leave the process memory:
   ```java
   @Bean
   public BeforeSendCallback sentryBeforeSendCallback() {
       return (event, hint) -> {
           Request request = event.getRequest();
           if (request != null) {
               // Scrub headers
               Map<String, String> headers = request.getHeaders();
               if (headers != null) {
                   headers.entrySet().forEach(entry -> {
                       if (SENSITIVE_KEY_PATTERN.matcher(entry.getKey()).find()) {
                           entry.setValue("[REDACTED]");
                       }
                   });
               }
               // Scrub payload/request data
               if (request.getData() instanceof String) {
                   request.setData(scrubString((String) request.getData()));
               }
           }
           return event;
       };
   }
   ```

---

### 2.3 Frontend Angular Integration
1. Install Sentry browser packages:
   ```bash
   cd frontend
   npm install @sentry/angular
   ```
2. Sentry is initialized conditionally in [app.config.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/app.config.ts) using the dynamically injected `window.__env` variables:
   ```typescript
   const env = (window as any).__env || {};
   const sentryDsn = env.SENTRY_DSN_FRONTEND;

   if (sentryDsn) {
     Sentry.init({
       dsn: sentryDsn,
       environment: env.SENTRY_ENVIRONMENT || 'production',
       release: env.SENTRY_RELEASE || undefined,
       integrations: [
         Sentry.browserTracingIntegration(),
         Sentry.replayIntegration({
           maskAllText: true,
           maskAllInputs: true,
           blockAllMedia: true
         }),
       ],
       tracesSampleRate: 0.1,
       replaysSessionSampleRate: 0.1,
       replaysOnErrorSampleRate: 1.0,
     });
   }

   const sentryProvider = sentryDsn ? [
     {
       provide: ErrorHandler,
       useValue: Sentry.createErrorHandler({
         showDialog: false,
       }),
     }
   ] : [];
   ```
   *Note: `maskAllText` and `maskAllInputs` are enabled by default. This ensures that user text inputs (like scripts) and form values (like passwords/OTPs) are completely masked in Session Replays.*

---

## 3. CENTRALIZED LOG AGGREGATION (NEW RELIC via COOLIFY LOG DRAINS)

Log aggregation is handled externally by the Coolify host container engine. Instead of putting network shipping overhead on the Java VM, the host automatically intercepts the application's standard console output (`stdout`) and forwards it to New Relic using a lightweight log drain shipper (Vector/FluentBit).

### 3.1 New Relic Set Up (Step-by-Step UI Guide)
1. **Redeem via GitHub Student Developer Pack**:
   * Navigate to the [GitHub Student Developer Pack](https://education.github.com/pack) and log in.
   * Search for **New Relic** in the pack offers.
   * Click **Redeem** to link your student status. This upgrades your account to the premium student plan, which provides:
     * **300 GB/month of free data ingestion** (upgraded from the default 100 GB/month).
     * **3 full platform users** (upgraded from 1).
2. **Retrieve Your License Key**:
   * Log in to your upgraded [NewRelic.com](https://newrelic.com) account.
   * In the bottom-left corner of the sidebar, click on your **User Profile Name/Avatar** ➔ **API Keys**.
   * On the API Keys dashboard page, locate the key type labeled **INGEST - LICENSE** (often named `default` or `original` license key).
   * Copy the key string (e.g., `NRAL-XXXX...XXXX`). Write this down as `NEW_RELIC_LICENSE_KEY`.
3. To view incoming records, click **Logs** in the left sidebar of your New Relic console.

---

### 3.2 Coolify Log Drain Configuration (Step-by-Step UI Guide)
Log drains in Coolify v4 must be configured first at the **Server** level and then activated on the individual **Resource** level:

#### Step A: Configure Sinks at the Server Level
1. Log in to your secure **Coolify Administration Dashboard** (e.g. `http://100.66.182.36:8000`).
2. On the main dashboard or servers page, click on your **active server** (e.g., `localhost` or the name of your VM compute node).
3. Inside the server dashboard configuration options, click on the **Log Drains** tab.
4. **Configure the Destination**:
   * Select **New Relic** as your Log Drain destination.
   * Paste your copied New Relic license key (e.g. `NRAL-XXXX...XXXX`) into the **New Relic License Key** input field.
   * Verify the **Endpoint URL**:
     * For US-based accounts (default): `https://log-api.newrelic.com/log/v1`
     * For EU-based accounts: `https://log-api.eu.newrelic.com/log/v1`
5. Click **Save** / **Update** to apply the configuration.

#### Step B: Enable Log Draining on the Application Resource
1. Navigate back to your Coolify projects, and select your target application (e.g., `speakit-prod-backend` or `speakit-dev-backend`).
2. Inside your application dashboard, click on the **Advanced** tab.
3. Scroll down to find the **Drain Logs** configuration toggle.
4. Toggle **Drain Logs** to `ON` (Enabled).
5. Trigger a **Redeploy** or **Restart** of your application to spin up the container with the log drain routing active.
6. Trigger some requests, and logs will populate in your New Relic console.

---

### 3.3 Security & PII compliance
Because Logback writes application logs to the console using the custom `LogMaskingAppender` (`SECURE_CONSOLE`), all logs are processed and scrubbed of sensitive patterns (emails, tokens, passwords) *before* hitting the standard output stream.

Coolify captures the pre-masked `stdout` stream, ensuring that **zero sensitive PII reaches your New Relic dashboard**.

---

## 4. DOCKER & ENVIRONMENT SECURITY HARDENING

1. **Non-Root Execution**:
   * **Backend**: Container runs as `USER appuser`.
   * **Frontend**: Hardens the Nginx server by creating writeable cache directories owned by `nginx` and binding to port `8080` (unprivileged), switching execution to `USER nginx`.
2. **Secrets Decoupling**:
   * All secret credentials are removed from `docker-compose.yml` and `Dockerfile` files.
   * Local development configurations live strictly in git-ignored `.env` files.

---

## 5. ENVIRONMENT VARIABLE REFERENCE

| Variable Name | Purpose | Location | Default Value / Placeholder |
|---|---|---|---|
| `SENTRY_DSN_BACKEND` | Backend Sentry Endpoint DSN | Runtime `.env` / OCI / Render | Empty (Disabled in Dev) |
| `SENTRY_DSN_FRONTEND` | Frontend Sentry Endpoint DSN | Runtime `.env` / Vercel | Empty (Disabled in Dev) |
| `SENTRY_ENVIRONMENT` | Active Sentry Environment | Runtime `.env` | `development` / `production` |
| `SENTRY_SEND_DEFAULT_PII` | Dictates if default PII (IPs, users) is sent to Sentry | Runtime `.env` | `false` / `true` |
| `NEW_RELIC_LICENSE_KEY` | New Relic Ingestion API Key | Runtime `.env` / OCI / Render | Empty (Disabled in Dev) |
| `NEW_RELIC_APP_NAME` | Log Identifier Name in New Relic | Runtime `.env` | `speakit-prod-backend` |

---

## 6. TRIAGE RUNBOOK

### Scenario A: Sentry Exception Alert Triggered
1. Log in to your Sentry Dashboard.
2. Filter by Environment (`production`/`staging`).
3. Locate the Exception. Check the **MDC Context parameters** to find the specific `requestId` that generated the error.
4. Search New Relic Logs using query: `MDC.requestId:"<requestId>"` to view the full contextual log trail leading up to the crash.

---

## 7. ROLLBACK ACTIONS

To cleanly disable integrations without changing business logic:
* **Disable Sentry**: Leave `SENTRY_DSN_BACKEND` and `SENTRY_DSN_FRONTEND` blank in your environment settings.
* **Disable New Relic Log Forwarding**: Leave `NEW_RELIC_LICENSE_KEY` blank or run the backend container under a profile other than `prod`.
