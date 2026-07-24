# SpeakIT Observability & Code Quality Setup Guide

This document is the single source of truth for integrating, configuring, and maintaining Sentry, CodeScene, Codecov, New Relic, and container security controls on the SpeakIT platform.

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

## 3. CODESCENE (TECHNICAL DEBT & HOTSPOT ANALYSIS)

CodeScene maps where developers edit code, revealing technical debt, hotspots, and circular coupling.

### 3.1 CodeScene Set Up (Step-by-Step UI Guide)
1. Go to [CodeScene.io](https://codescene.io) and log in using your **GitHub account** (choose the free student tier if active).
2. On your CodeScene dashboard, click the **Create Project** button.
3. Select **GitHub** as the integration provider. Authorize CodeScene access to your account/organization if prompted.
4. Select the repository: **`Mohitur669/speakit`** and click **Import**.
5. **Install the GitHub App**:
   * Navigate to your CodeScene project page ➔ **Project Configuration** (left menu) ➔ **PR Integration**.
   * Click **Install GitHub App** and select the repository to grant CodeScene permission to write check runs and PR comments.
6. **Set Branch Tracking**:
   * Go to **Project Configuration** ➔ **Branches**.
   * Set the **Default Branch** to `master`.
   * Set **Target Branches** to track `feature` branch pull requests.
7. **Configure File Exclusions**:
   * Go to **Project Configuration** ➔ **Files**.
   * Under **Exclude File Extensions**, add standard binaries or build outputs (e.g. `*.pdf; *.png; *.jpg; *.class; *.jar`).
   * Under **Exclude Paths**, enter glob paths to ignore (e.g., `/node_modules/`, `/dist/`, `/target/`).
8. **Generate Analysis Token**:
   * In your CodeScene account settings (top right avatar dropdown) ➔ **API Credentials**.
   * Generate a new API token. Copy the token and save it as a GitHub Repository Secret named **`CODESCENE_ANALYSIS_TOKEN`**.

### 3.2 Automated PR Quality Gate (`.github/workflows/codescene.yml`)
The workflow file [codescene.yml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/.github/workflows/codescene.yml) triggers on every pull request:
```yaml
      - name: CodeScene Delta Analysis
        uses: codescene/codescene-action@v2.0.0
        env:
          CODESCENE_ANALYSIS_TOKEN: ${{ secrets.CODESCENE_ANALYSIS_TOKEN }}
        with:
          fail-on-regression: true # Block merge only if new commits decrease code health
```

---

## 4. CODECOV (TEST COVERAGE REPORTING)

Codecov processes test reports and visualizes code coverage metrics directly on pull request lines.

### 4.1 Codecov Set Up (Step-by-Step UI Guide)
1. Navigate to [Codecov.io](https://codecov.io) and log in with your GitHub account.
2. Under your organization/account dashboard, locate the list of repositories and click **Configure** next to **`Mohitur669/speakit`**.
3. Under the configuration screen, Codecov will display a **Repository Upload Token** (looks like a UUID). Copy this token.
4. Go to your GitHub repository webpage: **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**.
5. Save the secret with Name: **`CODECOV_TOKEN`** and paste the token as Value.

---

### 4.2 Backend JaCoCo Integration
Add the coverage reporter to your `<build><plugins>` section inside your [pom.xml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/pom.xml):
```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

### 4.3 Frontend Vitest Coverage Integration
1. Install the Vitest coverage engine in your [package.json](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/package.json):
   ```bash
   cd frontend
   npm install --save-dev @vitest/coverage-v8
   ```
2. Running `npx vitest run --coverage` will automatically generate LCOV-compatible coverage reports under the `coverage/lcov.info` directory.

### 4.4 CI/CD Coverage Pipeline (`.github/workflows/coverage.yml`)
The workflow file [coverage.yml](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/.github/workflows/coverage.yml) builds and tests both apps and uploads reports to Codecov:
```yaml
      - name: Upload Coverage Reports to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: |
            backend/target/site/jacoco/jacoco.xml
            frontend/coverage/lcov.info
          flags: |
            backend
            frontend
```

### 4.5 Coverage Quality Rules (`.codecov.yml`)
The project baseline coverage is gated to prevent regressions:
```yaml
coverage:
  status:
    project:
      default:
        target: auto      # Match target to parent commit
        threshold: 1%     # Fail if code coverage drops by more than 1%
```

---

## 5. CENTRALIZED LOG AGGREGATION (NEW RELIC)

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

## 6. DOCKER & ENVIRONMENT SECURITY HARDENING

1. **Non-Root Execution**:
   * **Backend**: Container runs as `USER appuser`.
   * **Frontend**: Hardens the Nginx server by creating writeable cache directories owned by `nginx` and binding to port `8080` (unprivileged), switching execution to `USER nginx`.
2. **Secrets Decoupling**:
   * All secret credentials are removed from `docker-compose.yml` and `Dockerfile` files.
   * Local development configurations live strictly in git-ignored `.env` files.
3. **Container Image Scan (Trivy)**:
   * The CI pipeline builds images on each push and runs Trivy to scan for CVEs. The build fails on `HIGH` or `CRITICAL` issues.

---

## 7. ENVIRONMENT VARIABLE REFERENCE

| Variable Name | Purpose | Location | Default Value / Placeholder |
|---|---|---|---|
| `SENTRY_DSN_BACKEND` | Backend Sentry Endpoint DSN | Runtime `.env` / OCI / Render | Empty (Disabled in Dev) |
| `SENTRY_DSN_FRONTEND` | Frontend Sentry Endpoint DSN | Runtime `.env` / Vercel | Empty (Disabled in Dev) |
| `SENTRY_ENVIRONMENT` | Active Sentry Environment | Runtime `.env` | `development` / `production` |
| `NEW_RELIC_LICENSE_KEY` | New Relic Ingestion API Key | Runtime `.env` / OCI / Render | Empty (Disabled in Dev) |
| `NEW_RELIC_APP_NAME` | Log Identifier Name in New Relic | Runtime `.env` | `speakit-prod-backend` |
| `CODESCENE_ANALYSIS_TOKEN`| CodeScene PR Check Authorization | GitHub Actions Secret | CI-Only |
| `CODECOV_TOKEN` | Codecov Coverage Uploader token | GitHub Actions Secret | CI-Only |

---

## 8. TRIAGE RUNBOOK

### Scenario A: Sentry Exception Alert Triggered
1. Log in to your Sentry Dashboard.
2. Filter by Environment (`production`/`staging`).
3. Locate the Exception. Check the **MDC Context parameters** to find the specific `requestId` that generated the error.
4. Search New Relic Logs using query: `MDC.requestId:"<requestId>"` to view the full contextual log trail leading up to the crash.

### Scenario B: CI Build Fails on Coverage Check
1. Go to your GitHub Action run logs.
2. Select the "Upload Coverage Reports to Codecov" job.
3. Inspect the PR comment posted by Codecov showing which new code lines missed unit tests.
4. Add corresponding Vitest/Surefire tests and push again to resolve the block.

---

## 9. ROLLBACK ACTIONS

To cleanly disable integrations without changing business logic:
* **Disable Sentry**: Leave `SENTRY_DSN_BACKEND` and `SENTRY_DSN_FRONTEND` blank in your environment settings.
* **Disable New Relic Log Forwarding**: Leave `NEW_RELIC_LICENSE_KEY` blank or run the backend container under a profile other than `prod`.
* **Disable CodeScene**: Uninstall the App from the GitHub Repository Settings interface or remove `.github/workflows/codescene.yml`.
