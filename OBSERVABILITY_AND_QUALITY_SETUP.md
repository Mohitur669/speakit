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
   sentry.send-default-pii=false
   ```
   *Note: Setting `exception-resolver-order` to the lowest integer (`-2147483648`) ensures Sentry intercepts unhandled exceptions before standard Spring controller advisors wrap them in general HTTP responses. `send-default-pii=false` disables the default transmission of client IP addresses and usernames.*

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

## 3. CENTRALIZED LOG AGGREGATION (NEW RELIC)

New Relic logs are ingested asynchronously from the JVM, keeping execution lightweight on OCI/Coolify compute nodes.

### 5.1 New Relic Set Up (Step-by-Step UI Guide)
1. Log in to [NewRelic.com](https://newrelic.com) (New Relic includes a generous free tier of 100 GB/month data ingestion).
2. **Find Your License Key**:
   * In the bottom-left corner of the sidebar, click on your **User Profile Name/Avatar** ➔ **API Keys**.
   * Under the API Keys dashboard page, locate the key labeled **Ingest - License**.
   * Copy the key string (e.g. `XXXX...XXXX`). Write this down as `NEW_RELIC_LICENSE_KEY`.
3. Set `NEW_RELIC_APP_NAME` to `speakit-prod-backend`.
4. To view logs, go to **Logs** in the left sidebar of your New Relic console.

---

### 5.2 Maven Dependency
Add the New Relic logging appender to [pom.xml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/pom.xml):
```xml
<dependency>
    <groupId>com.newrelic.logging</groupId>
    <artifactId>logback</artifactId>
    <version>2.6.2</version>
</dependency>
```

### 5.3 Secure Logging Pipeline (`logback-spring.xml`)
We configure a custom `LogMaskingAppender` in [logback-spring.xml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/resources/logback-spring.xml) which acts as a proxy for all console, file, and New Relic log forwarders. This ensures sensitive data is scrubbed before being printed or shipped:
```xml
    <!-- Secure Masking Appender Wrapper -->
    <appender name="SECURE_CONSOLE" class="com.speakit.shared.util.LogMaskingAppender">
        <appender-ref ref="RAW_CONSOLE" />
    </appender>

    <!-- Production Log Forwarder -->
    <springProfile name="prod">
        <appender name="NewRelicLogback" class="com.newrelic.logging.logback.NewRelicLogbackAppender">
            <apiKey>${newRelicLicenseKey}</apiKey>
            <appName>${newRelicAppName}</appName>
        </appender>
        <appender name="SECURE_NEW_RELIC" class="com.speakit.shared.util.LogMaskingAppender">
            <appender-ref ref="ASYNC_NEW_RELIC" />
        </appender>
    </springProfile>
```

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
