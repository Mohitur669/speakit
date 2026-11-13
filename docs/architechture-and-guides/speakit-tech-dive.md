<style>
h1, h2, h3, h4, h5, h6 {
    page-break-after: avoid !important;
    break-after: avoid !important;
}
.diagram-container {
    page-break-inside: avoid !important;
    break-inside: avoid !important;
    display: block !important;
}
</style>

# SpeakIT: Enterprise Engineering & Architecture Deep-Dive

_An exhaustive architectural handbook, system design review, technical interview guide, and engineering standard manual._

---

## TABLE OF CONTENTS

1. [Project Overview & System Cheat Sheet](#1-project-overview--system-cheat-sheet)
   - 1.5. [System Cheat Sheet (TL;DR Overview)](#15-system-cheat-sheet-tldr-overview)
2. [Engineering Principles & Applied Software Concepts](#2-engineering-principles--applied-software-concepts)
   - 2.3. [Clean Architecture Layer Boundaries Diagram](#23-clean-architecture-layer-boundaries-diagram)
3. [Repository Structure & Conventions](#3-repository-structure--conventions)
   - 3.2. [Repository Folder Hierarchy Diagram](#32-repository-folder-hierarchy-diagram)
4. [Network & Deployment Architecture (Two of Everything)](#4-network--deployment-architecture-two-of-everything)
   - 4.1. [System Network Routing & Deployment Topology Diagram](#41-system-network-routing--deployment-topology-diagram)
   - 4.2. [Zero-Disk Secret Storage Process Diagram](#42-zero-disk-secret-storage-process-diagram)
   - 4.3. [Dual Environment Setup: speakit & speakit-dev](#43-dual-environment-setup-speakit--speakit-dev)
   - 4.4. [Internal Network Namespaces & Port Isolation](#44-internal-network-namespaces--port-isolation)
   - 4.5. [Traefik Reverse Proxy Configuration](#45-traefik-reverse-proxy-configuration)
5. [Continuous Deployment (CI/CD) & Webhook Pipeline](#5-continuous-deployment-cicd--webhook-pipeline)
   - 5.1. [GitOps Continuous Integration & Deployment Flow Diagram](#51-gitops-continuous-integration--deployment-flow-diagram)
   - 5.2. [Branch-Based Auto-Deployments](#52-branch-based-auto-deployments)
   - 5.3. [GitHub Webhook & Cloudflare WAF Bypass](#53-github-webhook--cloudflare-waf-bypass)
   - 5.4. [Vercel Dynamic API Endpoint Injection](#54-vercel-dynamic-api-endpoint-injection)
6. [Tailscale Private VPN Network Overlay](#6-tailscale-private-vpn-network-overlay)
   - 6.1. [VPN Overlay Network Isolation Diagram](#61-vpn-overlay-network-isolation-diagram)
   - 6.2. [OCI Host Firewall (UFW) Hardening](#62-oci-host-firewall-ufw-hardening)
   - 6.3. [SSH Tunneling for Database Connections (DBeaver)](#63-ssh-tunneling-for-database-connections-dbeaver)
7. [Backend Architecture & Layer Responsibilities](#7-backend-architecture--layer-responsibilities)
   - 7.3. [Spring Boot Layer Dependency Flow Diagram](#73-spring-boot-layer-dependency-flow-diagram)
8. [Frontend Architecture & Standalone Components](#8-frontend-architecture--standalone-components)
   - 8.2. [Angular Signals Reactive Data Propagation Flow Diagram](#82-angular-signals-reactive-data-propagation-flow-diagram)
9. [API Design Standards & Endpoint Mapping](#9-api-design-standards--endpoint-mapping)
10. [DTO Guidelines & Request Validation](#10-dto-guidelines--request-validation)
11. [Database Standards & Schema Design](#11-database-standards--schema-design)
12. [Naming Conventions](#12-naming-conventions)
13. [Coding Standards & Formatting](#13-coding-standards--formatting)
14. [Error Handling Standards](#14-error-handling-standards)
    - 14.2. [Global Error Translator Architecture Diagram](#142-global-error-translator-architecture-diagram)
15. [Security Standards & Session Versioning](#15-security-standards--session-versioning)
16. [Rate Limiting & Traffic Governance](#16-rate-limiting--traffic-governance)
    - 16.3. [Composite Identity Limiter Processing Flow Diagram](#163-composite-identity-limiter-processing-flow-diagram)
    - 16.4. [Dual-Signal Rate Limiting for Email Security](#164-dual-signal-rate-limiting-for-email-security)
17. [Logging Standards, MDC Tracing & Masking Appenders](#17-logging-standards-mdc-tracing--masking-appenders)
    - 17.3. [MDC Correlation Request Trace Pipeline Diagram](#173-mdc-correlation-request-trace-pipeline-diagram)
18. [Configuration Management](#18-configuration-management)
19. [Testing Standards](#19-testing-standards)
20. [Performance Guidelines & Optimization](#20-performance-guidelines--optimization)
21. [Docker & Containerization Standards](#21-docker--containerization-standards)
    - 21.3. [Multi-Stage Compilation & Unprivileged Container Diagram](#213-multi-stage-compilation--unprivileged-container-diagram)
22. [Observability & Code Quality Setup (Sentry & New Relic)](#22-observability--code-quality-setup-sentry--new-relic)
    - 22.1. [System Integration Snapshot Diagram](#221-system-integration-snapshot-diagram)
23. [Razorpay Subscription Webhooks & Payment Lifecycle](#23-razorpay-subscription-webhooks--payment-lifecycle)
    - 23.4. [Double-Handshake Subscription Flow Diagram](#234-double-handshake-subscription-flow-diagram)
24. [Email & Amazon SES Notification Setup](#24-email--amazon-ses-notification-setup)
    - 24.1. [Email Deliverability Routing Diagram](#241-email-deliverability-routing-diagram)
    - 24.4. [Billing Budget Circuit Breaker Flow Diagram](#244-billing-budget-circuit-breaker-flow-diagram)
25. [Telegram Notification Integration](#25-telegram-notification-integration)
    - 25.2. [Async Telegram RestClient Webhook Flow Diagram](#252-async-telegram-restclient-webhook-flow-diagram)
26. [AI & Speech Synthesis Providers (Polly, ElevenLabs, Sarvam)](#26-ai--speech-synthesis-providers-polly-elevenlabs-sarvam)
    - 26.3. [Dynamic AI Voice Engine Strategy Router Diagram](#263-dynamic-ai-voice-engine-strategy-router-diagram)
    - 26.4. [Long-Form PDF & Document Synthesis Lifecycle (Audiobook Pipeline)](#264-long-form-pdf--document-synthesis-lifecycle-audiobook-pipeline)
    - 26.5. [PDF-to-Audiobook End-to-End Processing Flow Diagram](#265-pdf-to-audiobook-end-to-end-processing-flow-diagram)
27. [Git Workflow & Commit Conventions](#27-git-workflow--commit-conventions)
28. [AI Agent Code Mod Rules](#28-ai-agent-code-mod-rules)
29. [Code Review Checklist](#29-code-review-checklist)
30. [Architecture Decision Records (ADR)](#30-architecture-decision-records-adr)
31. [Future Development Guidelines](#31-future-development-guidelines)
    - 31.2. [REST Endpoint Addition Implementation Workflow Diagram](#312-rest-endpoint-addition-implementation-workflow-diagram)
32. [Repository Conventions](#32-repository-conventions)
33. [Mermaid Diagrams](#33-mermaid-diagrams)
34. [Advanced Interview Edge Cases & Q&A](#34-advanced-interview-edge-cases--qa)
35. [System Scaling & Design Discussion](#35-system-scaling--design-discussion)
    - 35.2. [Viral Cost-Cached Scaling System Design Diagram](#352-viral-cost-cached-scaling-system-design-diagram)
36. [Engineering Storytelling](#36-engineering-storytelling)
37. [Repository Health & Living Documentation](#37-repository-health--living-documentation)

---

<div style="page-break-before: always;"></div>

## 1. PROJECT OVERVIEW & SYSTEM CHEAT SHEET

### 1.1 Purpose
SpeakIT is a production-grade, full-stack Text-to-Speech (TTS) and Speech-to-Text (STT) Software-as-a-Service (SaaS) platform. It allows users to convert text into realistic, studio-quality audio files using neural voice models, manage synthesis histories, upload audio files for speech transcription, and buy subscription plans.

### 1.2 System Goals
* **Sub-Second Audio Delivery**: Serve audio files with the lowest possible Time to First Byte (TTFB).
* **Stateless Security**: Ensure secure, stateless user session verification.
* **Cost Governance**: Actively govern external AI api expenditures (AWS Polly, ElevenLabs, and Sarvam AI) to prevent runaway billing.
* **Zero Downtime**: Support zero-downtime, immutable GitOps deployments.

### 1.3 High-Level System Overview
SpeakIT is built on a decoupled, multi-surface architecture:
* **Web Frontend**: Angular 21 Single Page Application (SPA) utilizing Signals, Standalone Components, and Tailwind CSS, served statically via Vercel's Edge Network for global low-latency page delivery.
* **Native iOS Client**: Native SwiftUI application built for iOS 17.0+ on Swift 6, featuring hardware-backed Keychain security, AVFoundation audio engine (`AVAudioEngine`, `AVAudioSession`, `AVAudioPlayer`), real-time recording visualizer, and Apple StoreKit 2 in-app purchases.
* **Backend Application Layer**: Spring Boot 4.x REST and WebSocket API running Java 25 inside a hardened Docker container, hosted on Oracle Cloud Infrastructure (OCI) via Coolify.
* **Database & Persistence**: PostgreSQL 16+ managed through Flyway migrations (`V1__init_schema.sql`, `V2__add_stt_audio_storage.sql`), pooling connections via HikariCP and PgBouncer to prevent containerized connection exhaustion.
* **Object Storage**: Cloudflare R2 multi-bucket architecture providing zero-egress-fee storage for user avatars, synthesized audio files, and encrypted disaster-recovery log backups.
* **AI Speech Integrations**: AWS Polly (Neural & Standard engines), ElevenLabs (Natural AI, Audio Isolation, Sound Effects), and Sarvam AI (Saaras STT, Bulbul Indic TTS across 10 Indian languages, Translation, and Transliteration).

### 1.4 Future Direction
* Custom voice cloning pipelines.
* Multi-user shared workspaces.
* Audiobook builder async processing workflows.

### 1.5 Non-Goals
* Running local deep-learning voice models on backend application nodes.
* Building a custom database engine or user-hosted binary distributions.

---

### 1.5. SYSTEM CHEAT SHEET (TL;DR OVERVIEW)

Refer to this reference dashboard for a quick description of the entire application structure, security posture, and deployment pipeline:

#### 1. Core Application Features
* **Text-to-Speech (TTS) Studio**: Orchestrates requests to AWS Polly (Neural and Standard voice engines), ElevenLabs, and Sarvam AI (Indian dialects). Supports voice custom properties, real-time character limit enforcement, and dynamic history tracking.
* **Speech-to-Text (STT) Studio**: Supports audio file uploading, validation, user transcription logs, and Indian dialect speech translations powered by Sarvam AI translation models (`sarvam-translate:v1`).
* **Razorpay Subscription Engine**: Features automated, secure order creation, payment validation, and webhook idempotency. Handles dynamic updates, upgrading active plans (canceling previous autopays instantly to prevent double charges), and scheduled downgrades at the cycle's end.
* **Dynamic Parameter Engine (`SystemParameter`)**: Allows developers to adjust plan pricing, character quotas, and toggles dynamically from the DB, updating the application behavior globally at runtime without server restarts.

#### 2. Comprehensive Security Controls
* **Stateless JWT Session Management**: Decoupled access/refresh tokens mapped to user records. Decoded payloads are validated against a database-backed `sessionVersion` value, enabling instant global session invalidation.
* **WAF Admin Panel Lockdown**: Hides the administration dashboard (`coolify.mohitur.com`) from the public internet using a Cloudflare WAF block rule. Webhook events bypass the firewall automatically, while admin UI access is restricted strictly to a private **Tailscale VPN overlay** on port `8000`.
* **Jsoup Input Sanitization**: Processes all incoming client text through strict Jsoup parser configurations to strip out HTML/JS code before hitting AI synthesis engines, neutralizing XSS attacks and character-quota probing.
* **Cascading Delete Database Integrity**: Prunes child data tables before parent user records (`otp_verifications` -> `tts_history` -> `payments` -> `subscriptions` -> `users`) via clean cascading Python scripts, avoiding DB constraint faults.
* **AWS Cost Control Budget Shield**: Employs AWS Cloudwatch budgets linked to a Lambda function to immediately strip Polly permissions from the application IAM user if spending exceeds set limits, degrading the system gracefully (HTTP 503) to prevent runaway billing.

#### 3. Continuous Deployment (CI/CD) & Webhook Pipeline
* **Multi-Branch Front-End Tracks (Vercel)**:
  * Pushes to `master` trigger Vercel production deployments to `https://speakit.mohitur.com`.
  * Pushes to `feature` trigger Vercel preview/dev deployments to `https://speakit-dev.mohitur.com`.
* **Dynamic Client-Side Config Injection**: Injects the active environment API URL (`speakit-prod-api.mohitur.com` or `speakit-dev-api.mohitur.com`) into the browser's global scope (`window.__env.API_URL`) during Vercel's build via `prebuild` npm hooks and `runtime-env.js`.
* **Automated Backend GitOps (Coolify & OCI)**: 
  * Pushes to GitHub send signed webhook payloads to `https://coolify.mohitur.com/webhooks/source/github/events`.
  * Webhook signatures are verified locally using HMAC-SHA256. Coolify checks target directories (`backend/**`) and executes multi-stage Docker builds on an OCI Ampere instance.
  * Traefik v3 verifies the container health using `/api/auth/ping` and hot-swaps routing rules, executing a rolling zero-downtime deployment.

---

<div style="page-break-before: always;"></div>

## 2. ENGINEERING PRINCIPLES & APPLIED SOFTWARE CONCEPTS

Every contributor must adhere to the following software engineering guidelines:
* **Clean Architecture**: Strictly separate domain layers (Web, Service, Repository, Database).
* **SOLID**: Enforce single responsibility, open-closed, Liskov substitution, interface segregation, and dependency inversion.
* **DRY (Don't Repeat Yourself)**: Extract common logic into shared utility modules.
* **KISS (Keep It Simple, Stupid)**: Favor simple, readable, and standard code paths over highly clever algorithms.
* **YAGNI (You Aren't Gonna Need It)**: Do not add placeholder code, dead features, or hypothetical variables.
* **Composition Over Inheritance**: Avoid deep class hierarchies. Use configuration injection and helper delegates.
* **Convention Over Configuration**: Follow standard Spring Boot and Angular directory structures.
* **Stateless Services**: Services must not store transient state in member variables.
* **Secure by Default**: Deny all unauthenticated routes by default, validate all inputs, and escape output.
* **Immutability**: Use Java records, Lombok `@Value`, and TypeScript `readonly` modifiers to enforce immutable data structures.

### 2.1 SOLID Principles Applied in SpeakIT

| Principle | Application in SpeakIT |
|---|---|
| **S**ingle Responsibility | Controllers handle HTTP; Services handle logic; Repos handle data. Each class has one reason to change. |
| **O**pen-Closed | `@RateLimited` aspect — protect new endpoints by annotation addition, not code modification. |
| **L**iskov Substitution | Repository interfaces can swap implementations (JPA -> JDBC) without breaking service layer. |
| **I**nterface Segregation | `UserSessionProjection` exposes only 3 fields; controllers never see the full `User` entity's 12 fields. |
| **D**ependency Inversion | Services depend on repository interfaces (`UserRepository`), not concrete Hibernate classes. Spring DI wire the implementations. |

### 2.2 Design Patterns Applied in SpeakIT

| Pattern | Where Used | Why |
|---|---|---|
| **Filter Chain** | `JwtAuthenticationFilter`, `RequestLoggingFilter` | Composable, ordered cross-cutting concerns |
| **Proxy** | `getReferenceById` returns Hibernate Proxy | Avoids unnecessary SELECT for FK relationships |
| **Strategy** | `RateLimitAction` enum — different bucket configs per endpoint | Swappable algorithms for different rate limit zones |
| **Builder** | Bucket4j `Bandwidth.builder()`, AWS SDK request builders | Fluent, immutable object construction |
| **Observer / Event** | BroadcastChannel for cross-tab logout | Decoupled event propagation without shared state |
| **Decorator** | HTTP Interceptors in Angular | Augment HttpClient behavior without modifying it |
| **Aspect (AOP)** | `@RateLimited` annotation | Non-functional concerns separated from business logic |

<div class="diagram-container">

### 2.3 Clean Architecture Layer Boundaries Diagram

```mermaid
graph TD
    UI["Client Browser UI"] -->|HTTP Request| Controller["Controller Layer / Web"]
    Controller -->|DTO Records| Service["Service Layer / Domain Logic"]
    Service -->|Entities / Projections| Repository["Repository Layer / Data Access"]
    Repository -->|SQL Queries| DB[("Database / Postgres")]
```

</div>

---

<div style="page-break-before: always;"></div>

## 3. REPOSITORY STRUCTURE & CONVENTIONS

```
/ (Workspace Root)
├── .github/                 -> GitHub Actions workflows and security scripts
├── backend/                 -> Spring Boot 4.x / Java 25 Backend Project
│   ├── src/main/java/       -> Java domain modules (com.speakit.*)
│   ├── src/main/resources/  -> application.properties, Flyway migrations, logback
│   └── pom.xml              -> Maven build specification (Java 25, Spring Boot 4.1.1)
├── frontend/                -> Angular 21 Frontend Project (Signals, Standalone Components)
│   ├── src/app/             -> Angular application modules (core, features, shared)
│   ├── public/              -> Static assets and runtime-env.js
│   └── package.json         -> npm build dependencies
├── ios/                     -> Native iOS Client Application (Swift 6, SwiftUI)
│   └── SpeakIT/
│       ├── Config/          -> xcconfig build configurations (Config.xcconfig, Local.xcconfig)
│       ├── SpeakIT/         -> Core, DesignSystem, Features, Models, and Assets
│       └── SpeakIT.xcodeproj-> Xcode project configuration
├── deployment/              -> Production deployment manifests (Systemd, Nginx, UFW scripts)
├── docs/                    -> Technical architecture specifications and manuals
├── scripts/                 -> Operational administration scripts (manage-user.py, Cloudflare scans)
└── docker-compose.yml       -> Local multi-container orchestration
```

### 3.1 Folder Constraints
* **`backend/`**: No frontend files or compiled assets.
* **`frontend/`**: No java scripts, backend models, or raw databases.
* **`ios/`**: Native Swift 6 code only; no cross-compiled web frameworks.
* **`docs/`**: Only documentation files. No source code.
* **`shared/`**: Must contain only packages imported across multiple submodules.

<div class="diagram-container">

### 3.2 Repository Folder Hierarchy Diagram

```mermaid
graph TD
    Root[/Workspace Root/] --> BE["backend/"]
    Root --> FE["frontend/"]
    Root --> IOS["ios/SpeakIT/"]
    Root --> Docs["docs/"]
    Root --> Dep["deployment/"]
    Root --> Scripts["scripts/"]
    
    BE --> BESrc["src/main/java/com/speakit/"]
    FE --> FESrc["src/app/core/ & src/app/features/"]
    IOS --> IOSSrc["SpeakIT/Core/, Features/, DesignSystem/"]
```

</div>

---

<div style="page-break-before: always;"></div>

## 4. NETWORK & DEPLOYMENT ARCHITECTURE (TWO OF EVERYTHING)

SpeakIT operates a mirrored dual-environment architecture, executing a complete development/sandbox stack and a production stack on a single compute node.

<div class="diagram-container">

### 4.1 System Network Routing & Deployment Topology Diagram

```mermaid
flowchart TD
    subgraph Client [User Browser / Client-Side]
        C_Prod[Production Frontend: https://speakit.mohitur.com]
        C_Dev[Development Frontend: https://speakit-dev.mohitur.com]
    end

    subgraph Cloudflare DNS [DNS Name Resolution]
        DNS_Prod_FE[speakit.mohitur.com] -->|CNAME| Vercel_Prod[Vercel Production servers]
        DNS_Dev_FE[speakit-dev.mohitur.com] -->|CNAME| Vercel_Dev[Vercel Preview servers]
        
        DNS_Prod_BE[speakit-prod-api.mohitur.com] -->|A Record| OCI_IP[OCI Public IP Address]
        DNS_Dev_BE[speakit-dev-api.mohitur.com] -->|A Record| OCI_IP
    end

    subgraph OCI_Server [Oracle Cloud Instance]
        subgraph Coolify_Network [Internal Docker Network]
            Traefik[Traefik Reverse Proxy]
            
            Prod_BE[Prod Spring Boot App: Port 8080]
            Dev_BE[Dev Spring Boot App: Port 8080]
            
            Prod_DB[(speakit-prod-db: PostgreSQL Port 5432)]
            Dev_DB[(speakit-dev-db: PostgreSQL Port 5432)]
        end
    end

    %% Client Interactions
    C_Prod -->|Resolves to| DNS_Prod_FE
    C_Dev -->|Resolves to| DNS_Dev_FE
    
    %% API requests from frontend to OCI Instance
    C_Prod -->|API Requests| DNS_Prod_BE -->|Hits port 443| Traefik
    C_Dev -->|API Requests| DNS_Dev_BE -->|Hits port 443| Traefik

    %% Dynamic Routing inside Traefik
    Traefik -->|host = speakit-prod-api.mohitur.com| Prod_BE
    Traefik -->|host = speakit-dev-api.mohitur.com| Dev_BE

    %% Database Connections
    Prod_BE -->|Internal JDBC Connection| Prod_DB
    Dev_BE -->|Internal JDBC Connection| Dev_DB
```

</div>

<div class="diagram-container">

### 4.2 Zero-Disk Secret Storage Process Diagram

```mermaid
flowchart TD
    Dashboard["Coolify Web UI"] -->|1. Admin Inputs Secrets| DB[("Coolify Encrypted DB")]
    DB -->|2. Reads on Deploy| Docker["Docker Daemon"]
    Docker -->|3. Injects directly into Process Memory| Java["Running Spring Boot App"]
    
    subgraph OCI Host Disk [Filesystem - /opt/speakit]
        File[".env file"]
    end
    
    Java -.->|No Disk Read| File
```

</div>

### 4.3 Dual Environment Setup: speakit & speakit-dev
The project hosts **two of everything** to isolate development validation from live business transactions:
* **Two Frontends**:
  * **Production (`speakit`)**: Routed to `https://speakit.mohitur.com` via Vercel production build triggers on the `master` branch.
  * **Development (`speakit-dev`)**: Routed to `https://speakit-dev.mohitur.com` via Vercel preview build triggers on the `feature` branch.
* **Two Backends**:
  * **Production (`speakit-prod-backend`)**: Ingests requests at `https://speakit-prod-api.mohitur.com`.
  * **Development (`speakit-dev-backend`)**: Ingests requests at `https://speakit-dev-api.mohitur.com`.
* **Two Databases**:
  * **Production DB (`speakit-prod-db`)**: Postgres scheme storing live payment orders, users, and histories.
  * **Development DB (`speakit-dev-db`)**: Isolated sandbox database running test suites, dummy parameters, and developer sandboxes.

### 4.4 Internal Network Namespaces & Port Isolation
To prevent port collisions, databases and Spring Boot backends execute inside separate Docker network containers:
* **Databases**: Both speakit-prod-db and speakit-dev-db bind to PostgreSQL default port 5432 internally on their distinct container IP addresses. We do not publish these ports to the host's public network interface, completely isolating database sockets from external internet scans.
* **Backends**: Both production and development backends bind to port 8080 internally within their container isolation zones.
* **Host Mapping**: Traefik binds to the host's port 80 (HTTP) and 443 (HTTPS) to handle public requests and route traffic.

### 4.5 Traefik Reverse Proxy Configuration
Traefik v3 is utilized as Coolify's default reverse proxy engine rather than standard Nginx:
1. **Dynamic Service Discovery**: Traefik hooks directly into the Docker daemon socket, automatically registering container startup/shutdown events. No static upstream configurations are written.
2. **Automated SSL/TLS Management**: Traefik handles Let's Encrypt HTTP-01 challenges, provisions trusted SSL certs, and auto-renews them at 90-day marks.
3. **Zero Downtime Routing**: Enables hot-swapping container IPs dynamically during new image deploys, preventing request dropping.

---

<div style="page-break-before: always;"></div>

## 5. CONTINUOUS DEPLOYMENT (CI/CD) & Webhook Pipeline

Auto-deployments execute via signed webhooks and branch triggers, deploying updates dynamically to the correct target environment.

<div class="diagram-container">

### 5.1 GitOps Continuous Integration & Deployment Flow Diagram

```mermaid
flowchart LR
    Push[Commit Push to GitHub] -->|Webhook Event| CF_Proxy[Cloudflare Webhook Relay]
    CF_Proxy -->|Signature Match| Coolify[Coolify v4 Daemon]
    Coolify -->|Verify Watch Paths: backend/**| Docker_Build[Docker Multi-Stage Build]
    Docker_Build -->|Image Ready| Traefik_Engine[Traefik Hot-Swap Swap]
```

</div>

### 5.2 Branch-Based Auto-Deployments
* **`master` Branch**: Pushes to `master` trigger Production builds:
  * Vercel builds the SPA and points the target endpoint to `https://speakit-prod-api.mohitur.com`.
  * Coolify builds the `speakit-prod-backend` JRE container on OCI.
* **`feature` Branch**: Pushes to `feature` trigger Development/Preview tracks:
  * Vercel deploys the preview build to `https://speakit-dev.mohitur.com` with API target set to `https://speakit-dev-api.mohitur.com`.
  * Coolify builds the `speakit-dev-backend` JRE container.

### 5.3 GitHub Webhook & Cloudflare WAF Bypass
Coolify registers webhooks with GitHub. To receive webhook payloads on a private admin-locked URL:
1. The public URL `https://coolify.mohitur.com` is proxy-routed through Cloudflare.
2. We create a Cloudflare WAF Custom Rule that blocks all incoming requests to `coolify.mohitur.com` **unless** the URI path starts with `/webhooks`.
3. This keeps the Coolify login dashboard completely blocked from the public web, while allowing GitHub Apps to trigger builds on commit events.
4. Payload integrity is secured at the application layer by verifying the webhook HMAC-SHA256 signature against the shared secret.

### 5.4 Vercel Dynamic API Endpoint Injection
To build identical static packages once and run anywhere, a dynamic prebuild hook injects configurations into the browser window scope:
1. Inside Vercel, the environment variable `API_URL` is scoped:
   * Production Environment: `API_URL` = `https://speakit-prod-api.mohitur.com`
   * Preview/Dev Environment: `API_URL` = `https://speakit-dev-api.mohitur.com`
2. Vercel executes `"prebuild": "node scripts/set-env.js"`.
3. The script compiles a JavaScript configuration at `public/runtime-env.js`:
   ```javascript
   window.__env = { API_URL: "https://speakit-prod-api.mohitur.com" };
   ```
4. During bootstrap, the Angular client reads `window.__env.API_URL` to route requests dynamically.

---

<div style="page-break-before: always;"></div>

## 6. TAILSCALE PRIVATE VPN NETWORK OVERLAY

To isolate administrative operations from public scans, the server runs a private overlay network using Tailscale.

<div class="diagram-container">

### 6.1 VPN Overlay Network Isolation Diagram

```mermaid
graph TD
    subgraph Public Internet
        Attacker["Public Internet Scanner"] -.->|Blocked: Connection Refused| Port22["SSH Port 22"]
        Attacker -.->|Blocked: Connection Refused| Port8000["Coolify UI Port 8000"]
    end
    
    subgraph Private VPN Tunnel
        Admin["Admin / Mac"] -->|Authenticated SSH| Tailnet["Tailscale Overlay Interface"]
        Tailnet -->|Decrypt Access| Port22
        Tailnet -->|Decrypt Access| Port8000
    end
```

</div>

### 6.2 OCI Host Firewall (UFW) Hardening
The OCI Virtual Cloud Network security list and the local OS firewall (UFW) are locked down:
* **Allowed Publicly**: Ports 80 (HTTP) and 443 (HTTPS) to allow proxy routing.
* **Allowed Privately (Tailscale Interfaces only)**:
  * Port 22 (SSH) is blocked publicly and restricted strictly to Tailscale IP subnet ranges (`100.64.0.0/10`).
  * Port 8000 (Coolify Admin dashboard) is blocked from public ingress. Access is resolved strictly over the secure Tailscale interface: `http://<tailscale-ip>:8000`.

### 6.3 SSH Tunneling for Database Connections (DBeaver)
Database ports (`3000` for prod, `3001` for dev) bind locally to the OCI host loopback (`127.0.0.1`). To connect to the databases from your local Mac using DBeaver:
1. Enable the **SSH Tunnel** tab in your DBeaver connection settings.
2. Target the OCI SSH Server: Host `<tailscale-ip>`, Port `22`, User `ubuntu`, and select your private key.
3. Configure the DB parameters under the Main tab: Host `localhost`, Port `3000` (for prod) or `3001` (for dev), schema `speakit`.
4. DBeaver will securely tunnel SQL queries through SSH, bypassing public port exposure.

---

<div style="page-break-before: always;"></div>

## 7. BACKEND ARCHITECTURE & LAYER RESPONSIBILITIES

The backend enforces a strict layered design pattern:
```
[Filter Chain] -> [Controller] -> [Service] -> [Repository] -> [Database]
```

### 7.1 Layer Responsibilities
* **Filters**: Handle cross-cutting concerns (JWT authentication, logging contexts, CORS).
* **Controllers**: Bind HTTP requests, validate DTO schemas using `@Valid`, route requests to Services, and map responses. Controllers must contain **zero business logic**.
* **Services**: Manage `@Transactional` boundaries and evaluate core business logic. Services must never access HttpServletRequest directly.
* **Repositories**: Abstract SQL transactions. Utilize custom queries and JPA Projections to minimize row scan latency.
* **Entities**: Map to database schemas. Must remain isolated from controllers (never return raw JPA entities directly to API responses).

### 7.2 Allowed Dependencies
* Controllers can import Services.
* Services can import Repositories or other Services.
* Repositories can interact with Database drivers.
* **Violation**: Controllers must **never** import repositories directly. Services must **never** reference HTTP servlet response streams directly.

<div class="diagram-container">

### 7.3 Spring Boot Layer Dependency Flow Diagram

```mermaid
sequenceDiagram
    participant Web as Controller / Filters
    participant Business as Service / Core Domain
    participant Storage as Repository / Persistence
    participant DB as Postgres Instance
    
    Web->>Business: Invoke method (RequestDTO)
    Business->>Storage: Find projection / record (ID)
    Storage->>DB: SQL Execution
    DB-->>Storage: ResultSet
    Storage-->>Business: Entity / Projection
    Business-->>Web: ResponseDTO
```

</div>

---

<div style="page-break-before: always;"></div>

## 8. FRONTEND ARCHITECTURE & STANDALONE COMPONENTS

The frontend is built with **Angular 21**, strictly utilizing **Standalone Components** and **Signals** for reactive state governance.

### 8.1 Core State & State Management
* Component state is managed via **Angular Signals** (`signal`, `computed`, `effect`) for fine-grained DOM change detection.
* **RxJS** is strictly reserved for data streaming and HTTP requests via the `HttpClient` pipeline.
* Broadcasters are synced across tabs using the browser's `BroadcastChannel` API to instantly end sessions across duplicate windows during logouts.

<div class="diagram-container">

### 8.2 Angular Signals Reactive Data Propagation Flow Diagram

```mermaid
graph LR
    Input["User Action / Input"] -->|Sets value| UserSignal["User Signal / State"]
    UserSignal -->|Triggers compute| ComputedField["Computed Signal / Read-only"]
    UserSignal -->|Triggers side effect| DOMEffect["DOM Effect / Re-render"]
    ComputedField --> DOMEffect
```

</div>

---

<div style="page-break-before: always;"></div>

## 8B. NATIVE IOS ARCHITECTURE & AVFOUNDATION SUBSYSTEM

The native iOS client (`ios/SpeakIT/`) is engineered using Swift 6, SwiftUI, and Apple's AVFoundation framework, maintaining exact feature, capability, and legal parity with the web platform.

### 8B.1 MVVM & Reactive State Architecture
- **Global State Coordination (`AppState.swift`)**: Centralizes authenticated user identity, active subscription tier, live quota metrics, and network reachability.
- **Hardware-Backed Credential Security (`KeychainHelper.swift`)**: Stores JWT access tokens, refresh tokens, and session identifiers in the iOS Keychain using `kSecAttrAccessibleAfterFirstUnlock`. No secrets or tokens are ever written to `UserDefaults`.
- **Dynamic Endpoint Resolution (`APIEndpoint.swift`)**: Automatically detects execution environments:
  - iOS Simulator: Configurable via `IOS_SIMULATOR_BASE_URL` in `Local.xcconfig` or Xcode Scheme environment variables (defaults to `http://localhost:8080`).
  - Physical Devices: Reads `IOS_API_BASE_URL` from `Config.xcconfig` / `Local.xcconfig`, falling back to `IOS_API_BASE_BACKUP_URL`.

### 8B.2 AVFoundation Audio Pipelines
- **Audio Playback Subsystem (`AudioPlayerManager.swift`)**:
  - Configures `AVAudioSession` with category `.playback` and mode `.spokenAudio` to allow background playback through the iOS Control Center and lock screen Now Playing widget.
  - Implements remote URL streaming, local file playback, seek scrubbing, rate modulation (0.75x to 2.0x), and automatic audio session ducking.
- **Audio Capture & Real-Time Metering (`AudioRecordingManager.swift`)**:
  - Utilizes `AVAudioEngine` and `AVAudioInputNode` configured at a 16kHz or 44.1kHz sample rate for high-fidelity speech capture.
  - Computes root-mean-square (RMS) decibel levels from input audio buffers at 60 FPS, feeding real-time audio amplitude values directly to the UI visualizer.
- **Recording Visualizer (`SpeakITRecordingVisualizer.swift`)**:
  - Renders a multi-bar reactive waveform utilizing SwiftUI animations linked directly to live mic dB levels.

### 8B.3 Dual-Channel Monetization & StoreKit 2
- **Apple In-App Purchases (`StoreKitService.swift`)**:
  - Interacts with the App Store via StoreKit 2 (`Product.purchase()`, `Transaction.updates`).
  - Upon successful transaction, sends signed App Store JWS receipts to backend `/api/v1/payments/apple/verify` for server-side cryptographic validation.
- **Web Billing Fallback**:
  - Physical devices provide deep-links to the web billing checkout portal when preferred, while in-app upgrades are handled natively.

### 8B.4 Content & Legal Sheet Parity
To comply with App Store Review Guidelines and ensure unified policy enforcement, the iOS application includes native SwiftUI modal sheets for:
- Terms of Service (`TermsOfServiceSheet.swift`)
- Privacy Policy (`PrivacyPolicySheet.swift`)
- About SpeakIT (`AboutSpeakITSheet.swift`)
- Contact Support (`ContactSupportSheet.swift`)
- Product Changelog & Blog Updates (`BlogUpdatesSheet.swift`)

All legal and support content is synchronized in lockstep with `frontend/src/app/features/marketing/`.

<div class="diagram-container">

### 8B.5 iOS Audio Pipeline & Network Architecture Diagram

```mermaid
flowchart TD
    subgraph UI["SwiftUI Interface Layer"]
        TTSView["TTSStudioView / VoiceCatalogSheet"]
        STTView["STTStudioView / LiveTranscriptionView"]
        Visualizer["SpeakITRecordingVisualizer (60 FPS Metering)"]
        Paywall["SubscriptionPaywallView (StoreKit 2)"]
    end

    subgraph AudioEngine["AVFoundation Audio Core"]
        AVSession["AVAudioSession (.playback / .playAndRecord)"]
        Player["AudioPlayerManager (AVAudioPlayer / Streaming)"]
        Recorder["AudioRecordingManager (AVAudioEngine / InputNode)"]
    end

    subgraph SecurityState["State & Security"]
        AppState["AppState (@Observable / EnvironmentObject)"]
        Keychain["KeychainHelper (kSecAttrAccessibleAfterFirstUnlock)"]
    end

    subgraph Network["Core Networking Layer"]
        HTTP["HTTPClient (URLSession, Auto-Retry, Auth Header)"]
        Endpoints["APIEndpoint (Dynamic Environment Resolver)"]
        StoreKit["StoreKitService (App Store Receipts)"]
    end

    subgraph BackendAPI["Backend Cloud Services"]
        SpringAPI["Spring Boot API (/api/tts, /api/stt, /api/v1/users)"]
        R2CDN["Cloudflare R2 Audio CDN"]
        AppleVerify["/api/v1/payments/apple/verify"]
    end

    TTSView --> Player
    STTView --> Recorder
    Recorder --> Visualizer
    STTView --> Visualizer
    Paywall --> StoreKit

    Player --> AVSession
    Recorder --> AVSession

    TTSView --> HTTP
    STTView --> HTTP
    AppState --> Keychain
    HTTP --> Endpoints
    HTTP --> SpringAPI
    Player -->|Stream Audio Bytes| R2CDN
    StoreKit -->|Verify Receipt JWS| AppleVerify
```

</div>

---

<div style="page-break-before: always;"></div>

## 9. API DESIGN STANDARDS & ENDPOINT MAPPING

All API endpoints follow strict RESTful conventions and versioning (`/api/v1/*` or module routes `/api/*`):

### 9.1 General Rules
* **Resource Pluralization**: Use plural nouns (`/api/v1/users`, `/api/v1/payments`).
* **Naming**: Use kebab-case for resource paths (`/api/system-parameters`, `/api/tts/synthesize-stream`).
* **HTTP Verbs**:
  * `GET`: Safe, idempotent resource retrieval.
  * `POST`: Creation of entities or triggering non-idempotent workflows (synthesis, verification).
  * `PUT`: Idempotent replacement or complete field update.
  * `DELETE`: Removal of resources (cascade-isolated).

### 9.2 Complete Endpoint Inventory

#### 1. Authentication (`/api/auth`)
* `POST /api/auth/register`: Initiate user registration and dispatch verification OTP.
* `POST /api/auth/verify-email`: Verify OTP and activate user account.
* `POST /api/auth/login`: Authenticate credentials; returns signed JWT and profile payload.
* `POST /api/auth/forgot-password`: Request password reset OTP.
* `POST /api/auth/reset-password`: Set new password with verified OTP token.
* `POST /api/auth/resend-otp`: Resend registration or verification OTP.
* `POST /api/auth/logout`: Invalidate session globally by incrementing database `session_version`.
* `POST /api/auth/ws-ticket`: Issue temporary single-use token for WebSocket authentication.
* `GET /api/auth/me`: Fetch current authenticated principal.
* `GET /api/auth/ping`: Public health check endpoint for monitoring and uptime probes.
* `GET /api/auth/check-username`: Live availability check for username during signup.
* `GET /api/auth/check-email`: Live availability check for email address.
* `GET /api/auth/check-phone`: Live validation and uniqueness check for phone numbers.

#### 2. User Profile & Account Management (`/api/v1/users`)
* `GET /api/v1/users/me`: Return authenticated profile, plan type, quota, and avatar URL.
* `PUT /api/v1/users/profile`: Update user biographical details.
* `PUT /api/v1/users/full-name`: Update user display name.
* `PUT /api/v1/users/username`: Modify username (enforcing unique constraints).
* `PUT /api/v1/users/phone-number`: Update contact phone number.
* `POST /api/v1/users/email/request-otp`: Request security OTP for email address change.
* `PUT /api/v1/users/email`: Confirm email update with verified OTP.
* `POST /api/v1/users/password/request-otp`: Request OTP for in-app password changes.
* `POST /api/v1/users/password`: Update user password with verification.
* `POST /api/v1/users/avatar`: Multipart image upload (JPEG/PNG/WebP), resized and stored in Cloudflare R2 bucket `speakit-avatars`.
* `DELETE /api/v1/users/avatar`: Delete user profile picture from R2 and reset profile record.
* `DELETE /api/v1/users/me`: Hard delete user account and cascade purge all child records across 12 tables.

#### 3. Text-to-Speech Engine (`/api/tts`)
* `GET /api/tts/voices`: Return catalog of available voices across AWS Polly, ElevenLabs, and Sarvam AI, filtered by active user plan.
* `POST /api/tts/synthesize`: Convert text to speech (buffered output uploaded to Cloudflare R2).
* `POST /api/tts/synthesize-stream`: Stream raw audio bytes directly to the caller.
* `GET /api/tts/usage`: Fetch remaining daily character limits and total syntheses.
* `GET /api/tts/usage/analytics`: Detailed usage breakdown, voice distribution, and 30-day metrics.
* `POST /api/tts/documents/analyze`: Multipart PDF upload; extracts text using Apache PDFBox, verifies size, and returns estimated audio duration.
* `POST /api/tts/jobs`: Enqueue long-form document synthesis job using sentence chunking.
* `GET /api/tts/jobs/{jobId}`: Poll async document synthesis progress, completion status, and CDN download URL.
* `POST /api/tts/audio-isolation`: Isolate speech from background noise via ElevenLabs audio tools.
* `POST /api/tts/speech-to-speech`: Transform speech audio into a target voice profile.
* `POST /api/tts/sound-effects`: Generate custom SFX clips from descriptive text prompts.

#### 4. Speech-to-Text & Live Transcription (`/api/stt`)
* `POST /api/stt/transcribe`: Transcribe uploaded audio file via Sarvam Saaras model.
* `POST /api/stt/transcribe-live`: Transcribe audio chunk recorded during a live microphone session.
* `POST /api/stt/translate`: Translate speech audio or transcript into English or target Indic language.
* `POST /api/stt/transliterate`: Transliterate text across supported scripts (e.g. Latin to Devanagari).
* `POST /api/stt/live/session`: Save complete live conversation session with metadata.
* `GET /api/stt/live/session/{id}/turns`: Retrieve conversation turns for a saved session.
* `GET /api/stt/session/{id}/export`: Export transcript in TXT, SRT, or VTT format.

#### 5. Synthesis History (`/api/history`)
* `GET /api/history`: Paginated history of TTS and STT operations with filtering by generation type.
* `GET /api/history/{id}/audio`: Secure streaming proxy or signed URL redirect for saved audio.
* `DELETE /api/history/delete`: Batch delete selected history records by ID list.
* `DELETE /api/history/clear-all`: Purge entire synthesis history for the authenticated user.

#### 6. Billing, Subscriptions & Webhooks (`/api/v1/payments` & `/api/v1/webhooks`)
* `GET /api/v1/payments/proration-quote`: Calculate prorated cost when upgrading between tiers.
* `POST /api/v1/payments/create-order`: Generate Razorpay payment order for subscription upgrade.
* `POST /api/v1/payments/verify`: Verify Razorpay HMAC-SHA256 signature and provision new subscription.
* `POST /api/v1/payments/apple/verify`: Verify Apple StoreKit 2 transaction receipt on App Store Server.
* `POST /api/v1/payments/downgrade-free`: Revert user subscription to Free tier.
* `POST /api/v1/payments/downgrade`: Schedule end-of-period plan downgrade.
* `POST /api/v1/payments/cancel`: Cancel active recurring subscription.
* `GET /api/v1/payments/history`: Paginated payment receipt and invoice history.
* `POST /api/v1/webhooks/razorpay`: Public signed webhook receiver for asynchronous Razorpay events.

#### 7. Dynamic Parameters, Contact & Administration
* `GET /api/system-parameters/bulk`: Fetch batch runtime configuration values (limits, prices, flags).
* `GET /api/system-parameters/cached/{name}`: Fetch single cached configuration value.
* `GET /api/system-parameters/live/{name}`: Direct database read bypassing application cache.
* `POST /api/contact`: Submit contact inquiry; triggers Discord webhook dispatch and email notifications.
* `POST /api/admin/logs/backup`: Trigger manual encrypted log backup to Cloudflare R2 bucket `speakit-logs`.
* `GET /api/admin/logs/download`: Admin stream of archived log backup files.

---

<div style="page-break-before: always;"></div>

## 10. DTO GUIDELINES & REQUEST VALIDATION

Data Transfer Objects (DTOs) decouple serialization schemas from database states:

### 10.1 General Rules
* DTOs must be immutable. Use `@Value` or `record` classes in Java.
* Request validation must be handled using Jakarta annotations (`@NotNull`, `@Email`, `@Size`, `@NotBlank`).
* Avoid returning null fields; use sensible default initializers or empty arrays.

### 10.2 Example Java Request DTO
```java
public record LoginRequest(
    @NotBlank(message = "Username or email is required")
    @Size(max = 100)
    String identifier,

    @NotBlank(message = "Password is required")
    String password
) {}
```

---

<div style="page-break-before: always;"></div>

## 11. DATABASE STANDARDS & SCHEMA DESIGN

The persistence layer is powered by **PostgreSQL 16+**, accessed via Spring Data JPA and Hibernate, and governed by versioned **Flyway migrations** (`backend/src/main/resources/db/migration/`).

### 11.1 Schema Architecture & Flyway Migration Strategy
The schema is strictly version-controlled to guarantee identical migration reproducibility across development, preview, and production environments:
- **`V1__init_schema.sql`**: Initial relational baseline provisioning 13 production tables, primary key sequences with pooled allocation (`allocationSize = 50`), foreign key constraints, and b-tree indexes.
- **`V2__add_stt_audio_storage.sql`**: Schema evolution adding `audio_url VARCHAR(512)` and `storage_key VARCHAR(255)` to `speech_to_text_requests` for persistent audio playback and Cloudflare R2 CDN delivery.

### 11.2 Complete Table Inventory

| Table Name | Primary Key | Key Columns | Purpose |
| :--- | :--- | :--- | :--- |
| `users` | `id` (BIGINT) | `email`, `username`, `password_hash`, `plan_type`, `session_version`, `role` | Core user identity, credentials, plan tier, and atomic session version. |
| `tts_history` | `id` (BIGINT) | `user_id`, `text_snippet`, `voice_id`, `character_count`, `audio_url`, `storage_key` | Historical record of synthesized text-to-speech audio outputs. |
| `subscriptions` | `id` (BIGINT) | `user_id`, `plan_type`, `status`, `razorpay_subscription_id`, `current_period_end` | Active subscription state, billing period boundaries, and auto-renewal status. |
| `payments` | `id` (BIGINT) | `user_id`, `razorpay_order_id`, `razorpay_payment_id`, `amount`, `status`, `currency` | Immutable audit trail of completed billing transactions and invoices. |
| `webhook_events` | `id` (BIGINT) | `event_id`, `event_type`, `payload`, `status`, `processed_at` | Idempotency log for incoming Razorpay and third-party webhook payloads. |
| `system_parameters` | `id` (BIGINT) | `name`, `value`, `description`, `data_type`, `is_active` | Dynamic database-backed configuration for character limits, pricing, and toggles. |
| `contact_submissions` | `id` (BIGINT) | `name`, `email`, `subject`, `message`, `status`, `ip_address` | Customer support submissions linked to Discord and email dispatch queues. |
| `speech_to_text_requests` | `id` (BIGINT) | `user_id`, `audio_duration_seconds`, `model_used`, `transcription_text`, `audio_url` | Transcribed audio files and live recording transcriptions with R2 storage keys. |
| `otp_verifications` | `id` (BIGINT) | `user_id`, `email`, `otp_hash`, `type`, `attempts`, `expires_at` | Short-lived security OTP hashes for password resets, email updates, and signups. |
| `pending_registrations` | `id` (BIGINT) | `email`, `username`, `password_hash`, `otp_hash`, `expires_at` | Staged user registrations awaiting initial email confirmation. |
| `user_avatar_history` | `id` (BIGINT) | `user_id`, `avatar_url`, `storage_key`, `file_size_bytes`, `content_type` | Audit and CDN reference history for uploaded user profile pictures. |
| `live_session_turns` | `id` (BIGINT) | `session_id`, `user_id`, `turn_index`, `speaker`, `text`, `start_time_ms` | Granular conversational dialogue turns recorded during live STT sessions. |
| `log_backup_audits` | `id` (BIGINT) | `backup_filename`, `storage_key`, `file_size_bytes`, `sha256_hash`, `status` | Disaster recovery tracking for encrypted nightly log backups archived in R2. |

<div class="diagram-container">

### 11.3 Entity-Relationship (ER) Architecture Diagram

```mermaid
erDiagram
    users ||--o{ tts_history : "generates"
    users ||--o{ subscriptions : "owns"
    users ||--o{ payments : "makes"
    users ||--o{ speech_to_text_requests : "transcribes"
    users ||--o{ otp_verifications : "verifies"
    users ||--o{ user_avatar_history : "uploads"
    users ||--o{ live_session_turns : "speaks"

    users {
        bigint id PK
        varchar username UK
        varchar email UK
        varchar password_hash
        varchar plan_type
        varchar role
        integer session_version
        boolean is_active
        boolean is_verified
        timestamptz created_at
    }

    tts_history {
        bigint id PK
        bigint user_id FK
        varchar text_snippet
        varchar voice_id
        varchar voice_type
        integer character_count
        varchar audio_url
        varchar storage_key
        varchar status
        timestamptz created_at
    }

    subscriptions {
        bigint id PK
        bigint user_id FK
        varchar plan_type
        varchar status
        varchar razorpay_subscription_id
        timestamptz current_period_start
        timestamptz current_period_end
        boolean cancel_at_period_end
    }

    payments {
        bigint id PK
        bigint user_id FK
        varchar razorpay_order_id
        varchar razorpay_payment_id
        integer amount
        varchar currency
        varchar status
        varchar plan_type
        timestamptz created_at
    }

    speech_to_text_requests {
        bigint id PK
        bigint user_id FK
        integer audio_duration_seconds
        varchar language_code
        varchar model_used
        text transcription_text
        varchar audio_url
        varchar storage_key
        timestamptz created_at
    }

    live_session_turns {
        bigint id PK
        varchar session_id
        bigint user_id FK
        integer turn_index
        varchar speaker
        text text
        integer start_time_ms
        integer end_time_ms
        timestamptz created_at
    }

    user_avatar_history {
        bigint id PK
        bigint user_id FK
        varchar avatar_url
        varchar storage_key
        bigint file_size_bytes
        timestamptz created_at
    }
```

</div>

### 11.4 Schema Design Philosophy
All tables adhere to a standardized column sequence ensuring consistent database maintenance:
1. Primary Key (`id BIGINT PRIMARY KEY`)
2. Foreign Keys (`user_id BIGINT REFERENCES users(id)`)
3. Domain Data Columns
4. Status & State Indicators
5. Audit Timestamps (`created_at`, `updated_at TIMESTAMPTZ`)
6. Optimistic Locking Version (`version BIGINT NOT NULL DEFAULT 0`)

### 11.5 Database Backups & Disaster Recovery Configuration
Database persistence is protected against disaster using automated S3-compatible backups configured via Coolify and Cloudflare R2:
* **Storage Destination**: S3-Compatible Bucket `speakit-backups`
* **Encryption**: AES-256 client-side encrypted tarballs
* **Retention Policy**: Nightly cron schedules with rolling 30-day retention and automated local temp-file cleanup.

---

<div style="page-break-before: always;"></div>

## 12. NAMING CONVENTIONS

All assets in the codebase must follow strict naming templates:

| Asset | Convention | Example |
|---|---|---|
| Java Package | lowercase, dot-separated | `com.speakit.auth.controller` |
| Java Class | PascalCase | `JwtAuthenticationFilter` |
| Java Interface | PascalCase | `UserRepository` |
| Angular Component | kebab-case, suffixed `.component` | `login.component.ts` |
| DB Table | lowercase, snake_case | `users`, `tts_history` |
| DB Column | lowercase, snake_case | `plan_type`, `session_version` |
| Env Variable | UPPERCASE, snake_case | `SPRING_DATASOURCE_URL` |
| JSON Field | camelCase | `planType`, `sessionVersion` |
| Git Branch | prefix, slash, description | `feature/doppler-integration` |
| Commit Message | prefix, description | `feat(sentry): add before-send callback` |

---

<div style="page-break-before: always;"></div>

## 13. CODING STANDARDS & FORMATTING

All code must conform to the following syntax and structural patterns:

### 13.1 Java formatting
* Indentation: 4 spaces. No tabs.
* Max Class Size: 500 lines.
* Max Method Size: 50 lines.
* Annotation ordering: `@Entity`, `@Table`, `@Getter`, `@Setter` before classes.
* Avoid magic strings: declare constants or configure enums.

### 13.2 JavaScript/TypeScript formatting
* Indentation: 2 spaces.
* Strictly type everything; avoid using `any` unless absolutely necessary.
* Declare Angular selectors as `app-` kebab-case (e.g. `app-tts-studio`).

---

<div style="page-break-before: always;"></div>

## 14. ERROR HANDLING STANDARDS

SpeakIT utilizes a centralized exception handling pattern:

### 14.1 Backend Exception Handler
All backend controller advice routes through `com.speakit.shared.exception.GlobalExceptionHandler` which catches standard RuntimeExceptions:
```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UserFriendlyException.class)
    public ResponseEntity<ErrorResponse> handleUserFriendlyException(UserFriendlyException ex) {
        ErrorResponse error = new ErrorResponse(
            HttpStatus.BAD_REQUEST.value(),
            ex.getMessage(),
            LocalDateTime.now()
        );
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }
}
```
*Note: Never print stack traces or raw system error logs to client HTTP responses.*

<div class="diagram-container">

### 14.2 Global Error Translator Architecture Diagram

```mermaid
graph TD
    Ex["Exception Occurs inside Controller/Service"] -->|Bubble Up| Advice["GlobalExceptionHandler"]
    Advice -->|Log Stacktrace locally with MDC requestID| Log["Logback Output"]
    Advice -->|Create UserFriendly ErrorResponse JSON| Response["HTTP Client Response"]
```

</div>

---

<div style="page-break-before: always;"></div>

## 15. SECURITY STANDARDS & SESSION VERSIONING

The platform is hardened against OWASP Top 10 vulnerabilities:

### 15.1 Authentication Flow — Stateless JWT with Stateful Invalidation
A JWT is self-contained and stateless. If a token is stolen or a user changes their password, the old token remains valid until it expires. SpeakIT solves this through **Session Versioning**:
```
JWT Payload: { userId: 42, sessionVersion: 7, exp: ... }
DB:          users table: { id: 42, session_version: 7 }

On every request:
  Filter reads sessionVersion from JWT (no DB call yet)
  Filter fetches UserSessionProjection from DB (ONE indexed query)
  Filter compares: JWT.sessionVersion == DB.session_version?
    -> Match: proceed
    -> Mismatch: 401 Unauthorized

On "Logout from all devices":
  UPDATE users SET session_version = session_version + 1 WHERE id = 42
  -> All old tokens (with version 7) are instantly invalid
  -> No Redis. No token blacklist. One DB update.
```

### 15.2 Input Sanitization & Password Security
* **XSS Shield**: All user text inputs are processed through a custom parser configured with strict `jsoup` whitelist parameters to strip script tags.
* **Password Storage**: Passwords must be hashed using **BCrypt** with a minimum work factor (rounds) of 10.

---

<div style="page-break-before: always;"></div>

## 16. RATE LIMITING & TRAFFIC GOVERNANCE

Every synthesis request invokes AWS Polly, which costs real money per character. Rate limiting in SpeakIT is therefore **dual-purpose infrastructure** — protecting both system stability and cloud budgets.

### 16.1 The Composite Identity Model
SpeakIT builds a **composite identity profile** per request, not a single IP lookup:
```
Resolution logic in RateLimitAspect:
  if (authenticated):
    key = "user:" + userId          <- JWT-bound. Proxy rotation irrelevant.
  else:
    key = "anon:" + hash(CF-IP + User-Agent)   <- Lightweight fingerprint
```

### 16.2 AOP Implementation — @RateLimited Annotation
Rate limiting is wired into the application via **Aspect-Oriented Programming (AOP)**:
```java
@Aspect
@Component
public class RateLimitAspect {

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Around("@annotation(rateLimited)")
    public Object enforceRateLimit(ProceedingJoinPoint joinPoint, RateLimited rateLimited)
            throws Throwable {

        String key = resolveIdentityKey(rateLimited.action());
        Bucket bucket = buckets.computeIfAbsent(key, k -> buildBucket(rateLimited.action()));
        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (probe.isConsumed()) {
            return joinPoint.proceed();
        }

        long retryAfterSeconds = probe.getNanosToWaitForRefill() / 1_000_000_000;
        HttpServletResponse response = getCurrentHttpResponse();
        response.addHeader("Retry-After", String.valueOf(retryAfterSeconds));
        throw new TooManyRequestsException(retryAfterSeconds);
    }
}
```

<div class="diagram-container">

### 16.3 Composite Identity Limiter Processing Flow Diagram

```mermaid
graph TD
    Req["Incoming HTTP request"] -->|Interrupted by| AOP["RateLimitAspect"]
    AOP -->|Check if JWT authentication header exists| CheckAuth{"Is Authenticated?"}
    CheckAuth -->|Yes| KeyUser["Identity Key = user:userId"]
    CheckAuth -->|No| KeyAnon["Identity Key = anon:hash IP+UA"]
    KeyUser --> Bucket["Lookup Bucket4j token bucket"]
    KeyAnon --> Bucket
    Bucket -->|Consume 1 Token| CheckToken{"Tokens Available?"}
    CheckToken -->|Yes| Execute["Proceed to target controller method"]
    CheckToken -->|No| Reject["Throw HTTP 429 TooManyRequestsException"]
```

</div>

### 16.4 Dual-Signal Rate Limiting for Email Security
To prevent abusers from spinning proxy networks to bypass IP rate limits and trigger massive SES billing expenses, email triggers (SignUp, Forgot Password, OTP request) enforce **Dual-Signal Rate Limiting**:
* Outgoing actions evaluate **both** an IP-level bucket (`OTP_RESEND_IP_[clientIp]`) and an Identity-level bucket (`OTP_RESEND_EMAIL_[emailHash]`).
* If the user rotates their IP, the Identity-level bucket locks them out of triggering duplicate email dispatches, mitigating mail loops and spam attacks.

---

<div style="page-break-before: always;"></div>

## 17. LOGGING STANDARDS, MDC TRACING & MASKING APPENDERS

Logs are used for metrics correlation and exception diagnosis:

### 17.1 MDC (Mapped Diagnostic Context) Tracing
The `RequestLoggingFilter` generates a unique `requestId` (UUID) for every incoming request and binds it to the SLF4J MDC context, printing it on all logs in the call thread.
```java
String requestId = UUID.randomUUID().toString().substring(0, 8);
MDC.put("X-Request-ID", requestId);
response.addHeader("X-Request-ID", requestId);
```
Logback pattern in `logback-spring.xml`:
```xml
<pattern>%d{ISO8601} [%X{X-Request-ID}] [%thread] %-5level %logger{36} - %msg%n</pattern>
```

### 17.2 Sensitive Data Redaction & Masking Appender
SpeakIT protects customer data (DPDP Act compliance) by routing JVM logs through `LogMaskingAppender`:
* Uses a custom regex converter (`LogMaskingConverter`) that scans messages for credentials, SMTP passwords, JWTs, and email regexes before printing to console.
* Sensitive patterns are replaced with `[REDACTED]` or obfuscated formats in memory.

<div class="diagram-container">

### 17.3 MDC Correlation Request Trace Pipeline Diagram

```mermaid
sequenceDiagram
    participant Client as User Browser
    participant Filter as RequestLoggingFilter
    participant Code as App Service Code
    participant Log as Logback Output
    
    Client->>Filter: HTTP Request (no correlation ID)
    Filter->>Filter: Generate unique short UUID
    Filter->>Filter: Bind UUID to SLF4J MDC context
    Filter->>Code: Execute business code
    Code->>Log: log.info("Validating payment order")
    Note over Log: Log output prints short UUID dynamically
    Code-->>Filter: Success response
    Filter->>Client: Response + Header [X-Request-ID]
```

</div>

---

<div style="page-break-before: always;"></div>

## 18. CONFIGURATION MANAGEMENT

Environment parameters must be decoupled from the code payload:
* Development environments use a local, git-ignored `.env` file to set properties.
* Production environments rely on Coolify variables (Backend JRE) and Vercel dashboard settings (Frontend).
* Secrets (e.g., API keys, passwords, tokens) must **never** be hardcoded or checked into Git.

---

<div style="page-break-before: always;"></div>

## 19. TESTING STANDARDS

Test code quality ensures platform stability:
* **Unit Tests**: Test single classes (e.g., helpers, utilities, enums) using mocks.
* **Integration Tests**: Boot database states using Spring profiles (e.g. `SPRING_PROFILES_ACTIVE=test`) to verify repository queries.
* **Coverage Targets**: High-risk business logic classes (like `RazorpayService` and `AuthService`) should target high coverage baselines.

---

<div style="page-break-before: always;"></div>

## 20. PERFORMANCE GUIDELINES & OPTIMIZATION

Performance bottlenecks are mitigated through efficient I/O routing:

### 20.1 Audio Streaming
AWS Polly streams are piped directly to the HTTP `OutputStream` to prevent OOM errors:
```java
try (InputStream pollyStream = pollyClient.synthesizeSpeech(...).audioStream()) {
    response.setContentType("audio/mpeg");
    pollyStream.transferTo(response.getOutputStream());
}
```

### 20.2 Database Pooling & Caching
* **Database Pooling**: All Supabase connections are routed through **PgBouncer** using transaction-level pooling.
* **Pre-cached Auth**: JWT validation queries utilize database JPA projections to fetch only `id`, `planType`, and `sessionVersion`, avoiding full entity loads.
* **In-Memory Caching**: Cache the AWS Polly `DescribeVoices` metadata inside JVM memory to drop lookup response latency from 800ms to <1ms.

---

<div style="page-break-before: always;"></div>

## 21. DOCKER & CONTAINERIZATION STANDARDS

The Docker configurations are designed for secure, reproducible container execution:
* **Non-Root Execution**:
  * The backend runner uses the `eclipse-temurin` JRE alpine stage executing under `USER appuser`.
  * The frontend container uses Nginx configured to run as `USER nginx` on unprivileged port `8080`.
* **Compose Governance**: Resources must be limited to prevent container runaways (e.g. backend limit set to 512MB RAM, frontend to 256MB RAM).

<div class="diagram-container">

### 21.3 Multi-Stage Compilation & Unprivileged Container Diagram

```mermaid
graph TD
    subgraph Build Phase
        JDK["Eclipse Temurin JDK 21 Image"] -->|Run maven package| JAR["Built executable JAR file"]
    end
    
    subgraph Run Phase
        JAR -->|Copy to| JRE["Eclipse Temurin JRE 21 Alpine Image"]
        JRE -->|Instantiate user appuser| Container["Running Container (Read-Only FS)"]
    end
```

</div>

---

<div style="page-break-before: always;"></div>

## 22. OBSERVABILITY & CODE QUALITY SETUP (SENTRY & NEW RELIC)

SpeakIT implements a mature error tracking and logging pipeline to track runtime anomalies:

<div class="diagram-container">

### 22.1 System Integration Snapshot Diagram

```mermaid
graph TD
    User["User Session / Browser"] -->|Errors & Performance| Sentry["Sentry SDK / Replay"]
    User -->|Interactions| LogService["LoggerService / Client Logs"]
    LogService -->|HTTP POST| Server["Spring Boot Backend"]
    Server -->|Structured JSON logs| NR["New Relic Logback Appender"]
    Server -->|Exceptions| SentryBackend["Sentry Spring Boot Starter"]
    SentryBackend -->|Redacted Payloads| SentryCloud["Sentry.io"]
    NR -->|Asynchronous Logs Shipping| NewRelicCloud["NewRelic.com"]
```

</div>

### 22.2 Sentry (Error Tracking & Session Replay)
* **SDK Configurations**: Integrates Sentry Spring Boot starter on the API, and `@sentry/angular` on the frontend.
* **Client Replay Shield**: Enforces privacy by default in `app.config.ts` by configuring the Sentry SDK Replay options:
  ```typescript
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  maskAllText: true,
  maskAllInputs: true,
  blockAllMedia: true
  ```
* **Data Scrubbing Callback**: A custom Java `BeforeSendCallback` inside `SentryConfig.java` intercepts server crash reports, redacting OAuth headers, tokens, and email strings before payloads are sent over the network.

### 22.3 New Relic (Centralized Log Aggregator)
* **Log Ingestion**: Connects Logback outputs to New Relic using the New Relic logback appender (v3.5.0).
* **Asynchronous Shipping**: Log shipping is decoupled from Spring execution, processing events on background JRE threads to prevent request delays.

---

<div style="page-break-before: always;"></div>

## 23. RAZORPAY SUBSCRIPTION WEBHOOKS & PAYMENT LIFECYCLE

Razorpay is integrated as the primary payment processor for user subscription upgrades and renewals.
* **Subscription Setup**: Plans are created on Razorpay and registered in `system_parameters` (`PRO_PLAN_ID_RAZORPAY`, `PRO_PLUS_PLAN_ID_RAZORPAY`, `RAZORPAY_SUBSCRIPTION_BILLING_CYCLES`).
* **Handled Webhook Events (`/api/v1/webhooks/razorpay`)**:
  * `subscription.activated` & `subscription.charged`: Validates signatures, records transactions, and updates the user's plan.
  * `subscription.cancelled`: Schedules a downgrade at the cycle's end.

<div class="diagram-container">

### 23.4 Double-Handshake Subscription Flow Diagram

```mermaid
sequenceDiagram
    participant Client as Angular Frontend
    participant Server as Spring Boot API
    participant Razorpay as Razorpay API

    Client->>Server: POST /create-order (planType)
    Server->>Razorpay: Create Subscription (plan_id)
    Razorpay-->>Server: Return subscription_id
    Server-->>Client: Return subscriptionId
    Client->>Client: Open Razorpay Checkout modal (subscription_id)
    Client->>Razorpay: User completes credit card payment
    Razorpay-->>Client: Return payment_id, subscription_id, signature
    Client->>Server: POST /verify (payment_id, subscription_id, signature)
    Server->>Server: Verify local signature using HMAC-SHA256
    Server->>Server: Mark subscription ACTIVE, reset quotas
    Server-->>Client: Return HTTP 200 SUCCESS
```

</div>

* **Idempotency**: All webhook transactions are registered in the `webhook_events` table to enforce exactly-once execution.

---

<div style="page-break-before: always;"></div>

## 24. EMAIL & AMAZON SES NOTIFICATION SETUP

SpeakIT manages transactional and inbound/outbound emails through a secure deliverability infrastructure.

<div class="diagram-container">

### 24.1 Email Deliverability Routing Diagram

```mermaid
graph TD
    subgraph Inbound Emails
        Sender["Customer / Internet"] -->|Send email to support@mohitur.com| CF["Cloudflare Email Routing"]
        CF -->|Auto-forward| Destination["admin-inbox@example.com"]
    end

    subgraph Outbound Emails
        Backend["Spring Boot Backend"] -->|SMTP TLS Port 587| SES["Amazon SES ap-south-1"]
        SES -->|DKIM Signed & SPF Aligned| Customer["Customer Inbox"]
    end
```

</div>

### 24.2 Domain Keys & DMARC Alignment
To maintain high email deliverability, DNS entries are configured in Cloudflare:
* **DKIM (Easy DKIM)**: 3 generated CNAME records authorize AWS SES sending.
* **DMARC Pass / Alignment**: A custom MAIL FROM subdomain (`mail.mohitur.com`) is configured to align Header and Envelope domains.
* **Merged SPF Record**: Authorizes Cloudflare routing and AWS SES securely in a single record:
  ```text
  v=spf1 include:_spf.mx.cloudflare.net include:amazonses.com ~all
  ```
* **DMARC Record**:
  ```text
  v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc-reports@mohitur.com; adkim=s; aspf=s;
  ```

### 24.3 AWS Budget Alerts & SES Regional Circuit Breaker
To prevent billing runaways from DDoS email spam, a global monitoring circuit breaker is deployed:
1. **AWS Budgets Alert**: Placed in `us-east-1` (AWS billing region) with alert threshold at `$20.00`.
2. **SNS Ingestion**: If triggered, Budgets publishes to `SES-Billing-Circuit-Breaker-Topic` (SNS `us-east-1`).
3. **AWS Lambda Execution**: A Python Lambda function triggers, executing `ses.update_account_sending_enabled(Enabled=False)` targeting the production region (**Mumbai `ap-south-1`**).
4. **Graceful Degradation**: SES sending is disabled globally, and the backend handles the resulting `AccessDeniedException` by degrading gracefully (returning HTTP 503).

<div class="diagram-container">

### 24.4 Billing Budget Circuit Breaker Flow Diagram

```mermaid
flowchart LR
    Alert["Budget Threshold > 100%"] -->|Trigger| SNS["Amazon SNS Topic in us-east-1"]
    SNS -->|Invoke| Lambda["AWS Lambda Circuit Breaker in us-east-1"]
    Lambda -->|ses:UpdateAccountSendingEnabled| SES["Amazon SES ap-south-1 Mumbai"]
    Lambda -->|Alert| Log["CloudWatch Logs / Admin Email"]
```

</div>

---

<div style="page-break-before: always;"></div>

## 25. TELEGRAM NOTIFICATION INTEGRATION

When users submit questions on the contact support forms, the platform dispatches real-time alerts to support agents via Telegram.

### 25.1 Telegram Service Implementation
The backend leverages `com.speakit.notification.service.TelegramService` to communicate with the Telegram Bot API:
* **Asynchronous Processing**: The service method is annotated with `@Async` to dispatch alerts in the background, preventing thread blocks in the main request path.
* **Strict Timeouts**: Instantiates a JdkClientHttpRequestFactory limiting read/connection timeouts to `5` seconds.
* **Message Formatting & Escaping**: The alert body is encoded using `MarkdownV2`. The service runs a custom escaping utility (`escapeMarkdown`) to parse and escape characters (e.g. `_`, `*`, `[`, `]`, `.`, `!`), avoiding payload injection issues.
* **Exponential Backoff**: If an HTTP request fails, the service executes a retry loop up to 3 times, doubling wait times between retry loops (1s -> 2s -> 4s) before logging final dispatch errors.

<div class="diagram-container">

### 25.2 Async Telegram RestClient Webhook Flow Diagram

```mermaid
sequenceDiagram
    participant Code as Business Service Thread
    participant TeleService as TelegramService (Async Executor)
    participant API as Telegram Bot Endpoint
    
    Code->>TeleService: sendNotification(name, email, text)
    Note over TeleService: Instantiates background task thread
    Code-->>Code: Proceed with execution flow (Non-blocking)
    TeleService->>TeleService: Escape raw strings to MarkdownV2
    TeleService->>API: HTTP POST /sendMessage
    alt Success
        API-->>TeleService: Return 200 OK
    else Failure (HTTP Timeout / Rate Limit)
        Note over TeleService: Double sleep timer (1s -> 2s -> 4s)
        TeleService->>API: Retry API execution
    end
```

</div>

---

<div style="page-break-before: always;"></div>

## 26. AI & SPEECH SYNTHESIS PROVIDERS (POLLY, ELEVENLABS, SARVAM)

SpeakIT dynamically matches speech generation requests against three API vendors depending on voice options and billing tiers:

### 26.1 Vendor Strategy Mapping
* **AWS Polly (Neural & Standard)**: Ground layer. Standard engines serve `FREE` users; `NEURAL` engine profiles are restricted to `PRO` and `PRO_PLUS` subscribers.
* **ElevenLabs**: Premium natural voice synthesis. REST endpoint routing is configured strictly for high-end `PRO_PLUS` users. Additionally provides audio isolation (noise removal), speech-to-speech transformation, and AI sound effects.
* **Sarvam AI**: High-accuracy synthesis for Indic languages and regional dialects. Expressly leverages the `bulbul:v3` model via endpoint `https://api.sarvam.ai/text-to-speech` authenticated via `api-subscription-key`. It is mapped to `PRO` and `PRO_PLUS` users, and dynamically toggled using the system parameter `SARVAM_ENABLED`.

### 26.2 Speech-to-Text & Live Audio Transcription Engine
* **Sarvam Saaras STT (`SarvamSpeechToTextProvider`)**: Processes regional and multilingual speech with exceptional dialect accuracy:
  * Batch Audio Upload (`POST /api/stt/transcribe`): Transcribes uploaded audio files (WAV, MP3, FLAC, OGG, AAC) with automatic language detection or explicit locale selection.
  * Live Chunk Transcription (`POST /api/stt/transcribe-live`): Ingests audio slices recorded in real-time from web or iOS microphones, returning low-latency partial and finalized transcripts.
  * Live Session & Dialogue Turns (`POST /api/stt/live/session`): Persists full session metadata and individual dialogue turns (`live_session_turns`) with millisecond timestamps and speaker labels.
  * Transcript Export: Generates downloadable formatted exports in plain text (TXT), SubRip Subtitle (SRT), and WebVTT (VTT) formats.
* **Translation & Transliteration Services**:
  * Translation (`sarvam-translate:v1`): Translates recognized speech or arbitrary text between 10 Indian regional languages and English.
  * Transliteration: Converts phonetics across native Indic scripts (e.g., Devanagari, Bengali, Tamil, Telugu) and Latin alphabets.

### 26.3 Cloudflare R2 Multi-Bucket Object Storage Topology
Audio and asset storage is architected across three independent, dedicated Cloudflare R2 buckets using S3-compatible APIs via the AWS SDK for Java:
* **Bucket 1 (`speakit-avatars`)**: User profile pictures. Subject to strict file-type validation (JPEG, PNG, WebP) and daily upload limit enforcement (`AVATAR_DAILY_LIMIT = 2`). Served via dedicated CDN domain.
* **Bucket 2 (`speakit-audio`)**: Synthesized TTS audio generations, recorded STT audio clips, and long-form audiobook outputs. Partitioned under clean prefix namespaces:
  * `translate-audio/`: Text-to-speech audio files (`u_{userId}_{timestamp}_{hash}.mp3`).
  * `transcribe-audio/`: Speech-to-text recorded input clips.
  * `pdf-audio/`: Assembled long-form audiobook outputs.
* **Bucket 3 (`speakit-logs`)**: Nightly encrypted application log backups (`logs/speakit-backend.log`) stored with SHA256 checksum audit records in `log_backup_audits`.

<div class="diagram-container">

### 26.4 Dynamic AI Voice Engine Strategy Router Diagram

```mermaid
graph TD
    Req["Synthesis Request / API"] -->|Inspect requested voice parameters| Strategy{"Strategy Router"}
    Strategy -->|Engine: Standard or Neural| AWS_Polly["AWS Polly Client"]
    Strategy -->|Engine: ElevenLabs| ElevenLabs["ElevenLabs Client\n(TTS / Isolation / STS / SFX)"]
    Strategy -->|Engine: Sarvam Indic| Sarvam["Sarvam AI Client\n(Bulbul TTS / Saaras STT / Translate)"]
    
    AWS_Polly --> Storage["Cloudflare R2 Object Storage"]
    ElevenLabs --> Storage
    Sarvam --> Storage
    Storage --> CDN["Cloudflare Audio CDN (Zero Egress Fees)"]
```

</div>

### 26.4 Long-Form PDF & Document Synthesis Lifecycle (Audiobook Pipeline)

SpeakIT provides an enterprise-grade document-to-audiobook pipeline designed for synthesizing multi-page PDFs containing 10,000+ words without encountering HTTP gateway timeouts (such as Cloudflare's 100-second limit). The system uses a two-stage decoupled architecture: synchronous pre-validation & text staging, followed by asynchronous chunked synthesis.

#### 1. Security & Deep Document Validation (`PdfDocumentValidator`)
To prevent malicious payload injections, denial-of-service (Zip-bombs/PDF-bombs), and unentitled usage, incoming documents undergo strict server-side validation:
* **Binary Magic Byte Verification**: Never relies on client-supplied `Content-Type` headers or file extensions. The validator reads the initial byte stream and verifies the PDF file signature (`%PDF-` in the first 1024 bytes).
* **Path Traversal & Filename Sanitization**: Strips directory navigation characters (`..`, `/`, `\`) and blocks hidden or executable extensions.
* **Tier-Based Quota Enforcement**:
  * `FREE`: 5 MB max file size, up to 10 pages, up to 5,000 words.
  * `PRO`: 25 MB max file size, up to 100 pages, up to 50,000 words.
  * `PRO_PLUS`: 50 MB max file size, up to 300 pages, up to 150,000 words.

#### 2. Text Extraction & Pre-Analysis (`PdfProcessingService`)
* **Apache PDFBox 3.0.4**: Uses `Loader.loadPDF(RandomAccessReadBuffer)` for thread-safe memory management.
* **Encryption & Password Detection**: Calls `PDDocument.isEncrypted()`. Protected documents are immediately rejected with a clean `400 Bad Request` specifying that encrypted files must be unlocked before synthesis.
* **Intelligent Text Normalization**: Employs `PDFTextStripper` to extract text while respecting Unicode characters, paragraph boundaries, and whitespace normalization.
* **Empty & Image-Only Scanned PDF Detection**: If extracted text contains no meaningful words, the system rejects the request with an explicit advisory informing the user that OCR (Optical Character Recognition) is required.
* **Word Counting & Audio Estimation**: Implements regex `\p{L}+[\p{L}\p{N}'’-]*` to accurately count words across languages. Audio duration is estimated using an industry-standard 150 words per minute (WPM) heuristic.

#### 3. Staged Document Token Architecture
Uploading multi-megabyte PDFs or passing huge JSON payloads during synthesis request initiation is prone to network failure.
* `POST /api/tts/documents/analyze` validates and extracts the document, stores the parsed text in a thread-safe `ConcurrentHashMap` with a **30-minute TTL**, and returns a UUID `documentToken` along with document metrics (pages, words, estimated audio duration).
* Scheduled eviction (`@Scheduled(fixedRate = 300000)`) purges expired tokens automatically to prevent memory leaks.

#### 4. Asynchronous Sentence Chunking & Dynamic Synthesis (`LongFormSynthesisService`)
* `POST /api/tts/jobs` (or `/api/tts/jobs/document`) receives the `documentToken`, voice parameters, and creates a `LongFormJobStatusDto` in the `QUEUED` state.
* **Sentence Boundary Splitting**: The engine breaks extracted text using regex `(?<=[.!?])\s+`, packing sentences up to an 800-character ceiling to guarantee that neural speech engines maintain natural cadence and intonation without abrupt mid-sentence cuts.
* **Multi-Engine Synthesis**: Each chunk is dynamically routed to the matching provider (AWS Polly, ElevenLabs, or Sarvam AI).
* **Audio Concatenation & Cloud Storage**: Completed audio chunk byte streams are assembled in memory and uploaded to Cloudflare R2 via `AudioStorageService` under dedicated CDN bucket path prefixes:
  * `translate-audio/`: Standard Text-to-Speech audio (`https://cdn-speakit-audio.mohitur.com/translate-audio/u_{id}_{ts}_{hash}.mp3`)
  * `transcribe-audio/`: Speech-to-Text recorded/uploaded audio (`https://cdn-speakit-audio.mohitur.com/transcribe-audio/u_{id}_{ts}_{hash}.mp3`)
  * `pdf-audio/`: Long-form PDF audiobook synthesis (`https://cdn-speakit-audio.mohitur.com/pdf-audio/u_{id}_{ts}_{hash}.mp3`)
* **Client Recovery & Polling**: Frontend (Angular) and native iOS (SwiftUI) poll `GET /api/tts/jobs/{jobId}` every 2.5 seconds. The iOS app persists active job identifiers in `UserDefaults` to automatically resume tracking across app restarts.

<div class="diagram-container">

### 26.5 PDF-to-Audiobook End-to-End Processing Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Angular / iOS)
    participant Client as Client Application
    participant Gateway as Cloudflare Edge / WAF
    participant Controller as TtsController
    participant Validator as PdfDocumentValidator
    participant Parser as PdfProcessingService
    participant JobService as LongFormSynthesisService
    participant AI as TTS Engine (Polly/ElevenLabs/Sarvam)
    participant Storage as Cloudflare R2 / S3

    Note over User,Parser: Phase 1: Pre-validation & Document Staging
    User->>Client: Selects / Drops PDF Document
    Client->>Gateway: POST /api/tts/documents/analyze (Multipart PDF)
    Gateway->>Controller: Forward Request
    Controller->>Validator: Validate Magic Bytes (%PDF-), Size, MIME
    Validator-->>Controller: Validation OK
    Controller->>Parser: Extract Text, Pages, Word Count
    Parser->>Parser: PDFBox parse, verify unencrypted, extract Unicode text
    Parser->>Parser: Stage text with UUID Token (30-min TTL cache)
    Parser-->>Controller: DocumentAnalysisDto (token, pages, words, duration)
    Controller-->>Client: 200 OK + Analysis Summary
    Client-->>User: Display Document Summary (e.g. 86 pages, 24k words, 2h 45m)

    Note over User,Storage: Phase 2: Asynchronous Job Processing
    User->>Client: Configures Voice & Clicks "Generate Audiobook"
    Client->>Gateway: POST /api/tts/jobs (documentToken, voiceId, format)
    Gateway->>Controller: Forward Job Request
    Controller->>JobService: Claim Token & Enqueue Synthesis Job
    JobService-->>Controller: Job ID Created (QUEUED)
    Controller-->>Client: 202 Accepted (jobId)
    
    activate JobService
    JobService->>JobService: Update Status -> PROCESSING
    JobService->>JobService: Split Text by Sentence Regex (?<=[.!?])\s+ (<=800 chars)
    loop For each chunk (1 to N)
        JobService->>AI: Synthesize Audio Chunk (Polly/Eleven/Sarvam)
        AI-->>JobService: Audio Bytes (MP3)
        JobService->>JobService: Update progress (currentChunk / totalChunks)
    end
    JobService->>JobService: Concatenate Audio Byte Streams
    JobService->>Storage: Upload Assembled Audiobook (audio/mpeg)
    Storage-->>JobService: Public / CDN Audio URL
    JobService->>JobService: Update Status -> COMPLETED
    deactivate JobService

    loop Poll every 2.5s
        Client->>Controller: GET /api/tts/jobs/{jobId}
        Controller-->>Client: LongFormJobStatusDto (progress, status, audioUrl)
    end
    Client-->>User: Synthesis Complete! Enable Playback & Download
```

</div>

---

<div style="page-break-before: always;"></div>

## 27. GIT WORKFLOW & COMMIT CONVENTIONS

* **Branch Naming**:
  * Features: `feature/your-feature-name`
  * Bugfixes: `bugfix/your-fix-name`
* **Conventional Commits**:
  * Commits must follow format: `type(scope): description` (e.g., `feat(auth): add login rate limit`).
* **PR Requirements**: Before merging to `master`, code must compile cleanly, pass local unit tests, and contain zero raw secrets.

---

<div style="page-break-before: always;"></div>

## 28. AI AGENT CODE MOD RULES

These instructions apply to all AI coding agents modifying the SpeakIT repository:
1. **Never Invent Architecture**: Follow existing architecture layer boundaries.
2. **Re-use Common Utilities**: Check `shared/util` and `shared/exception` before creating custom logic.
3. **Zero PII Leakage**: Ensure new parameters or logs do not print user emails, phone numbers, or passwords.
4. **Update Setup Guides**: If adding environment parameters, immediately update this guide and the corresponding `.env.example` files.
5. **No Code Duplication**: Do not create duplicate DTO classes or duplicate query repositories.

---

<div style="page-break-before: always;"></div>

## 29. CODE REVIEW CHECKLIST

Ensure the following are verified before approving pull requests:
* [ ] **Secrets**: No raw API keys, passwords, or credentials exist in the diff.
* [ ] **Inputs**: All public strings are sanitized via jsoup whitelist configurations.
* [ ] **Permissions**: Endpoint authorization is enforced (e.g. roles are validated).
* [ ] **Performance**: SQL queries avoid N+1 scans and retrieve only projected columns where appropriate.
* [ ] **Redaction**: New fields do not leak user-identifiable data in logs.

---

<div style="page-break-before: always;"></div>

## 30. ARCHITECTURE DECISION RECORDS (ADR)

* **ADR-001: Migration of Backend Container to OCI & Coolify**
  * **Context**: Free tier Render instances suffered from cold-start spin-downs, degrading client experience.
  * **Decision**: Migrate production backend container execution to an Always-Free OCI Ampere host managed by Coolify v4.
  * **Consequences**: Zero cold-starts, infinite persistent hosting uptime, and zero infrastructure billing cost.

---

<div style="page-break-before: always;"></div>

## 31. FUTURE DEVELOPMENT GUIDELINES

### 31.1 Adding a New REST API Endpoint
1. Create request and response DTO records under `com.speakit.[module].dto`.
2. Add Jakarta Validation annotations to the request DTO.
3. Create the endpoint in `com.speakit.[module].controller.[Module]Controller`.
4. Validate permissions inside the controller using HttpServletRequest user attributes.
5. Implement service layer logic in `[Module]Service` under `@Transactional` boundaries.

<div class="diagram-container">

### 31.2 REST Endpoint Addition Implementation Workflow Diagram

```mermaid
flowchart TD
    CreateDTO["1. Create Request & Response DTO records"] --> AddValidator["2. Add Jakarta Validation annotations"]
    AddValidator --> AddController["3. Define routes in Controller"]
    AddController --> AddAuth["4. Set endpoint permissions in controller"]
    AddAuth --> AddService["5. Write business logic in Service under Transactional"]
    AddService --> AddRepo["6. Query database via Repository interfaces"]
```

</div>

---

<div style="page-break-before: always;"></div>

## 32. REPOSITORY CONVENTIONS

* **Folder Ownership**:
  * `/backend` -> Backend Engineers (Java/Maven).
  * `/frontend` -> Frontend Engineers (Angular/npm).
* **Imports**: Backend classes must never import from other modules if it creates a circular dependency. Extract dependencies to `shared` packages.

---

<div style="page-break-before: always;"></div>

## 33. MERMAID DIAGRAMS

<div class="diagram-container">

### 33.1 System Architecture
```mermaid
graph TD
    Client[Angular 21 Client - Vercel]
    Edge[Cloudflare Edge DNS/WAF]
    Server[Spring Boot 3.5 App - OCI]
    Database[(Postgres Database - Supabase)]
    PgBouncer[PgBouncer Pooler]
    Polly[AWS Polly AI Service]

    Client -->|HTTPS| Edge
    Edge -->|Verified traffic| Server
    Server --> PgBouncer
    PgBouncer --> Database
    Server -->|AWS SDK| Polly
```

</div>

<div class="diagram-container">

### 33.2 Authentication Session Loop
```mermaid
sequenceDiagram
    participant Client as Angular App
    participant Filter as JwtFilter
    participant DB as User Database
    participant API as Controller

    Client->>Filter: Request with Bearer JWT
    Filter->>DB: Fetch user session version (projection)
    alt Token session version == DB session version
        DB-->>Filter: Match Successful
        Filter->>API: Route to Endpoint
        API-->>Client: HTTP 200 OK
    else Token session version != DB session version
        DB-->>Filter: Mismatch (Old session)
        Filter-->>Client: HTTP 401 (X-Logout-Reason: MULTI_LOGIN)
    end
```

</div>

---

<div style="page-break-before: always;"></div>

## 34. ADVANCED INTERVIEW EDGE CASES & QA

**Q: Your `sessionVersion` check reads from the DB on every request. Isn't this a performance problem?**

**A:** It's a deliberate, managed tradeoff. The query is:
```sql
SELECT id, session_version, plan_type FROM users WHERE id = ?
```
This hits a **primary key index** — PostgreSQL B-tree index lookup is O(log n), typically 1-2 page reads from SSD. With PgBouncer and HikariCP maintaining warm connections, this executes in 1-3ms. The alternative (pure stateless JWT, no DB check) means a compromised token is valid for up to 24 hours after the user changes their password. For a TTS SaaS with billing, this is unacceptable.

**Q: Your `sessionVersion` increment is an atomic DB update, but isn't there a race condition if two requests hit the filter at the exact same millisecond?**

**A:** No. The `JwtAuthenticationFilter` executes a `SELECT` projection to read the current `sessionVersion`. This is a point-in-time check under PostgreSQL's `READ COMMITTED` isolation level.
Scenario: User is logging out (UPDATE) while a concurrent request is being validated (SELECT).
- If the SELECT sees the OLD version and the JWT also has the old version -> request proceeds.
- If the SELECT sees the NEW version (post-commit) and the JWT has the old version -> 401.
- The UPDATE (`SET version = version + 1`) is inherently atomic in PostgreSQL.

**Q: You're using `getReferenceById` to avoid a SELECT. What happens if the user was deleted between JWT validation and the history insert?**

**A:** The JWT validation (SELECT from users) happens in the filter. The `tts_history` insert happens asynchronously in the controller. The time gap is ~10-50ms.
If the user is hard-deleted in that window:
1. `getReferenceById` returns an uninitialized Hibernate Proxy — no SELECT yet.
2. When the transaction tries to INSERT into `tts_history`, the FK constraint fires.
3. PostgreSQL raises: `ERROR: insert or update on table "tts_history" violates foreign key constraint`.
4. Our `GlobalExceptionHandler` catches it and logs a warning — no stack trace leak, no 500 error to the user.

---

<div style="page-break-before: always;"></div>

## 35. SYSTEM SCALING & DESIGN DISCUSSION

### 35.1 "SpeakIT just went viral. Traffic spiked 10,000%. What breaks first?"
* **Database Connections (~immediate)**: HikariCP connection pool settings will exceed Supabase's free tier pooler thresholds.
  * *Fix*: Upgrade Supabase plan and switch to transaction-level PgBouncer settings.
* **AWS Polly TPS Quotas (Minutes)**: Default account transactions per second limits will trigger `ThrottlingException`.
  * *Fix*: Request AWS limit increases and configure exponential backoff in JVM clients.
* **AWS Budget Burn**: Max text volumes will consume Polly dollar budgets.
  * *Fix*: Enable content-addressable S3 cache storage matching voice/text hashes to reuse outputs without charging Polly APIs.

<div class="diagram-container">

### 35.2 Viral Cost-Cached Scaling System Design Diagram

```mermaid
graph TD
    Req["Browser Speech Request"] -->|Text + Voice settings hash lookup| Cache{"Is Synthesized Audio Cached?"}
    Cache -->|Yes: Cost is $0| S3["Deliver S3 Audio URL instantly"]
    Cache -->|No| Engine["Acquire Rate Limit token -> Forward to Polly/ElevenLabs/Sarvam API"]
```

</div>

---

<div style="page-break-before: always;"></div>

## 36. ENGINEERING STORYTELLING

### 36.1 The Founder / CTO Pitch
_"We built SpeakIT because high-quality auditory experiences shouldn't require a Hollywood budget. The problem isn't that AWS Polly is hard to use — it's that building a production SaaS around it responsibly requires solving about 20 non-trivial engineering problems: How do you invalidate a JWT instantly without Redis? How do you prevent a single angry user from draining your AWS budget? How do you stream audio without buffering gigabytes in JVM heap?_

_We solved all of them. Angular 21 with Signals gives us a reactive, low-latency frontend that serves globally in under 30ms. Spring Boot 3.5 with Java 21 gives us the multi-threaded, strongly-typed backbone needed to stream audio at scale. Our session versioning system invalidates compromised tokens globally with one SQL UPDATE — no Redis, no blacklist, no complexity."_

---

<div style="page-break-before: always;"></div>

## 37. REPOSITORY HEALTH & LIVING DOCUMENTATION

### 37.1 Detected Architecture Observations
* **JWT session projections**: The backend successfully optimizes token validation queries by only fetching required session versions, preventing database table joins.
* **Logging masking layer**: The JVM logging pipeline successfully redacts sensitive email patterns and credential keys at the Logback appender level.
* **Non-root docker containment**: Both backend and frontend Dockerfiles conform to non-root execution guidelines.

### 37.2 Technical Debt & Actions
* **High Priority**: Configure integration test environments using H2 or testcontainers to ensure queries stay validated during Maven packages upgrades.
* **Medium Priority**: Keep dependencies updated to mitigate alpine/cve container alerts.
* **Low Priority**: Clean up any unused legacy DTO references in the contact packages.

---

<div style="page-break-before: always;"></div>

## 38. VULNERABILITY ASSESSMENT AND PENETRATION TESTING (VAPT) PIPELINE

### 38.1 Pipeline Overview & Architecture
SpeakIT implements a sophisticated, multi-stage DevSecOps pipeline designed to automatically detect, aggregate, and resolve dependency vulnerabilities (CVEs) across the full stack. The pipeline bridges GitHub's Security API (Dependabot) with local Bash orchestration, Python-based automation, and autonomous AI agent remediation.

The architecture ensures that simple, repetitive vulnerabilities (like minor NPM bumps) are resolved instantly and silently, while complex backend vulnerabilities (Maven/Java) are securely orchestrated by an AI agent under strict workspace governance.

<div class="diagram-container">

### 38.2 VAPT Pipeline Execution Flow

```mermaid
sequenceDiagram
    autonumber
    participant GH as GitHub Security API
    participant Gen as generate-vapt-reports.sh
    participant Py as dependabot_report.py
    participant Npm as auto-fix-npm.py
    participant Repo as Working tree
    participant AI as AI Agent (agy)

    Gen->>GH: Verify CLI Auth & API Permissions
    Gen->>Py: Execute Python Report Generator
    Py->>GH: Fetch Paginated Alerts
    Py->>Repo: Output agent-queue.json & PDF Reports
    Gen->>Npm: Auto-Trigger Fast-Track NPM fixes
    Npm->>Repo: Loop through NPM alerts, bump package.json, run tests, commit
    Npm-->>Gen: Return fast-track success
    Gen-->>AI: Ready for complex AI handoff
    AI->>Repo: Read reports/dependabot/fix-vapt-alerts.md
    loop For each complex backend vulnerability
        AI->>Repo: Update Maven POMs, run 'mvn test'
        AI->>Repo: Update progress checklist in fix-vapt-alerts.md
    end
```

</div>

### 38.3 Phase 1: Vulnerability Aggregation (Python Engine)
* **Trigger**: Scheduled via GitHub Actions (`.github/workflows/dependabot-report.yml`) or manually orchestrated locally.
* **Engine**: `.github/scripts/dependabot_report.py`.
* **Execution**: Normalizes nested advisory data, extracts CVSS/EPSS scores, and deduplicates vulnerabilities by computing the highest necessary target version. 
* **Outputs**: Generates `agent-queue.json` (severity-ordered fix queue), `fix-vapt-alerts.md` (single consolidated AI remediation plan & protocol), and human-readable HTML/PDF reports stored in `reports/dependabot/`.

### 38.4 Phase 2: Local Orchestration & Fast-Tracking (Bash Automation)
* **Setup Orchestrator**: `scripts/dependency-vapt-pipeline/generate-vapt-reports.sh` acts as the single entry point. It provisions local virtual environments, installs Python requirements, tests `gh cli` token scopes, and runs the Phase 1 Python engine.
* **NPM Fast-Track Engine**: Immediately after report generation, the orchestrator triggers `auto-fix-npm.py`. This script instantly eliminates frontend vulnerability noise by autonomously bumping `package.json` targets, running `npm ci` and Angular test suites, and committing successful patches to the `vapt-fix` branch.

### 38.5 Phase 3: Autonomous AI Remediation & Strict Governance
* **Instruction Protocol**: Complex alerts (e.g., Maven vulnerabilities, breaking API changes) bypass the fast-track and are handed off to the AI agent using the consolidated `reports/dependabot/fix-vapt-alerts.md` protocol.
* **Governance**: The pipeline is strictly governed by workspace rules (`.agents/AGENTS.md`) which explicitly block the AI from interacting with legacy interactive scripts (e.g., `fix-alerts.py`).
* **Execution**: The AI orchestrates itself—reading the queue, modifying `pom.xml`, executing JVM test suites (`mvn clean compile test`), and cleanly formatting `fix(deps)` commits without requiring interactive bash prompts.
