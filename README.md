# SpeakIT: Enterprise AI Voice Generation Platform

> Transforming digital content with lifelike AI-powered speech synthesis.

SpeakIT is a production-grade, full-stack SaaS platform powered by **AWS Polly**. It provides a high-performance, responsive interface for converting text into natural, human-quality speech using both Standard and Neural engines. Designed with enterprise scalability in mind, the platform features robust session management, plan-based rate limiting, and a comprehensive marketing suite.

**Live Platform:** [mohitur-speakit.vercel.app](https://mohitur-speakit.vercel.app)

---

## 🚀 Key Features

- **Dual-Engine Synthesis** — Leverages AWS Polly's Standard and Neural engines for studio-quality audio.
- **Subscription Tiers** — Enforced limits: **Free (200 characters)** and **Pro (3,000 characters)**.
- **Stateless Authentication** — JWT-based auth with stateless validation and "Logout from all devices" support via DB session versioning.
- **Production Dashboard** — Real-time usage statistics and paginated conversion history.
- **Marketing Suite** — Fully integrated, SEO-optimized About, Blog, Contact, and Legal pages.
- **High-Performance Data Layer** — Optimized PostgreSQL schema with dedicated sequences and N+1 prevention.
- **Observability** — Structured logging with MDC-based `requestId` tracing and 30-day log rotation.
- **Responsive Architecture** — Modern Angular SPA with standalone components and reactive Signals.

---

## 🛠 Tech Stack

### Frontend (Modern SPA)
- **Framework:** Angular 21.x (Standalone Components, Signals)
- **Styling:** Tailwind CSS 4.x
- **State Management:** Angular Signals & Services
- **Hosting:** Vercel

### Backend (Enterprise Java)
- **Framework:** Spring Boot 3.5.x
- **Language:** Java 21 (LTS)
- **Security:** Spring Security 6.x (Stateless JWT)
- **Database:** PostgreSQL (Hibernate/JPA)
- **Integration:** AWS SDK for Polly (v2.x)
- **Hosting:** Render

### Infrastructure & DevOps
- **Health Monitoring:** GitHub Actions (Keep-alive health checks)
- **CORS Hardening:** Environment-driven origin restriction
- **Rate Limiting:** Bucket4j (Token Bucket algorithm)

---

## 🏗 Architecture Overview

SpeakIT follows a clean, layered architecture optimized for high insert throughput and low-latency synthesis.

```text
User Browser (Angular SPA)
     │
     │ HTTPS (JWT + Request-ID)
     ▼
Spring Boot API (Render)
     │
     ├── Filter: RequestID (MDC Tracing)
     ├── Filter: JWT (Session Version Validation)
     ├── Controller: Plan-based Validation (Sanitization)
     └── Service: Polly Integration (Neural Engine)
             │
             ▼
      AWS Polly Engine ──► Audio Stream (MP3) ──► Frontend Playback
```

---

## 🔒 Security Compliance

SpeakIT is built with a **Security-First** mindset:

- **Secret Isolation:** No credentials or tokens are stored in code. All configuration is injected via Environment Variables.
- **Session Versioning:** Every JWT contains a `sessionVersion`. Logging out instantly invalidates all tokens globally.
- **Input Sanitization:** All text inputs are processed through `Jsoup` sanitization before reaching business logic.
- **Ownership Validation:** Strict isolation ensures users only access their own history logs.
- **MDC Tracing:** Every request is assigned a unique `X-Request-ID` for end-to-end tracing.
- **PII Protection:** Frontend redaction prevents leaking sensitive keys to the browser console.

---

## 📊 Database Design Philosophy

The database is engineered for **PostgreSQL 16+** using enterprise-grade JPA patterns:

- **Sequence-Based IDs:** Uses numeric `Long` primary keys with dedicated sequences (`users_seq`, `tts_history_seq`).
- **Pooled Optimizer:** `allocationSize = 50` reduces database network round-trips by 98%.
- **Audit Tracing:** All entities inherit from `BaseEntity`, providing automated audit timestamps.
- **Standardized Ordering:** Tables follow a consistent physical pattern for optimized performance.
- **Security:** Internal IDs are never exposed in sensitive public-facing APIs.

---

## 📂 Project Structure

### Backend
- `/src/main/java/com/tts/config`: Infrastructure, Security, and Logging configuration.
- `/src/main/java/com/tts/entity`: JPA entities with standard column ordering.
- `/src/main/java/com/tts/dto`: Strict validation-based Data Transfer Objects.
- `/src/main/java/com/tts/repository`: Optimized repositories with interface projections.
- `/src/main/java/com/tts/service`: Core business logic and AWS integrations.

### Frontend
- `/src/app/core`: Singletons (Auth, Interceptors, Guards, Centralized Logger).
- `/src/app/shared`: Reusable UI components (Navbar, Footer, Toast).
- `/src/app/features`: Domain modules (auth, tts, marketing, blog).
- `/scripts`: Runtime environment generators for zero-rebuild deployments.

---

## 🛠 Local Development Setup

### Prerequisites
- **Node.js** 22+
- **Java 21** (JDK)
- **Maven** 3.9+
- **PostgreSQL** 16+ (Local or Cloud)

### 1. Environment Configuration

#### Backend Setup
Initialize the backend environment file:
```bash
cp backend/.env.example backend/.env
```

#### Backend Variables (`backend/.env`)
| Variable | Description | Default |
| :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | IAM User access key for Polly access | - |
| `AWS_SECRET_ACCESS_KEY` | IAM User secret key | - |
| `AWS_REGION` | AWS region (e.g., `us-east-1`) | - |
| `SPRING_DATASOURCE_URL` | JDBC URL (Use Supabase Session Pooler for IPv4) | - |
| `SPRING_DATASOURCE_USERNAME` | Database username (usually `postgres`) | - |
| `SPRING_DATASOURCE_PASSWORD` | Database password | - |
| `JWT_SECRET` | 64-character secure secret for token signing | - |
| `JWT_EXPIRATION` | Token validity in milliseconds | `86400000` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated list of permitted origins | `http://localhost:4200` |
| `LOG_LEVEL_APP` | Application logging level (`DEBUG`, `INFO`, `WARN`) | `INFO` |
| `LOG_MAX_FILE_SIZE` | Log rotation size trigger | `20MB` |
| `LOG_MAX_HISTORY` | Days of log retention | `10` |

#### Frontend Setup
Initialize the frontend environment file:
```bash
cp frontend/.env.example frontend/.env
```

#### Frontend Variables (`frontend/.env`)
| Variable | Description | Default |
| :--- | :--- | :--- |
| `API_URL` | Base URL of the Spring Boot Backend | `http://localhost:8080` |
| `SUPABASE_URL` | Supabase project URL (client-side only) | - |
| `SUPABASE_KEY` | Supabase anonymous key | - |
| `LOG_LEVEL` | Client logging verbosity (`DEBUG`, `INFO`, `WARN`, `OFF`) | `DEBUG` |
| `NODE_ENV` | Environment mode (`development` or `production`) | `development` |

### 2. Manual Setup Steps

Follow these steps to run the services natively on your machine:

#### Step 1: Database Setup
1. Create a PostgreSQL database (locally or via [Supabase](https://supabase.com)).
2. If using Supabase, ensure you use the **Session Pooler** URL (Transaction mode) for the `SPRING_DATASOURCE_URL`.
3. The schema will be automatically created on the first backend run via Hibernate `ddl-auto: update`.

#### Step 2: Backend Initialization
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies and compile:
   ```bash
   ./mvnw clean compile
   ```
3. Initialize your `.env` file and fill in your AWS and Database credentials (if not already done in the "Environment Configuration" section above):
   ```bash
   cp .env.example .env
   ```
4. Start the Spring Boot application:
   ```bash
   ./mvnw spring-boot:run
   ```
   The backend will be available at `http://localhost:8080`.

#### Step 3: Frontend Initialization
1. Open a new terminal and navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install Node dependencies:
   ```bash
   npm install
   ```
3. Initialize your `.env` file (if not already done in the "Environment Configuration" section above):
   ```bash
   cp .env.example .env
   ```
4. Start the Angular development server:
   ```bash
   npm start
   ```
   The platform will be available at `http://localhost:4200`.

---

## 📈 Logging & Monitoring

SpeakIT implements structured logging for both development and production:

- **Backend:** Logs are written to `logs/speakit-backend.log` with a 10MB rotation policy and 30-day retention.
- **Frontend:** Centralized `LoggerService` suppresses verbose logs in production and redacts sensitive data.
- **Health Checks:** A dedicated `/api/auth/ping` endpoint is monitored by a GitHub Action to prevent service hibernation.

---

## 🤝 Contribution Standards

We follow the **SpeakIT Engineering Guide** (`AGENTS.md`). Before contributing:
1. Ensure all new components are **Standalone**.
2. Use **Signals** for state management.
3. Maintain **100% Build Success** for both backend (`./mvnw compile`) and frontend (`npm run build`).
4. Follow the **Standardized DB Column Ordering** for schema changes.

---

## ⚖️ License & Commercial Usage

SpeakIT is distributed under a **Dual-Licensing Model** to support both the open-source community and enterprise commercial requirements.

### Open Source License (GNU AGPLv3)
For individuals, open-source projects, and non-commercial educational use, SpeakIT is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**. 
- You are free to download, modify, and run the software.
- **Requirement:** If you modify the codebase and provide it as a hosted service over a network (SaaS), you **must** open-source your modifications under the same AGPLv3 license.

### Commercial License
For startups, enterprises, and businesses looking to:
- Use SpeakIT in a commercial SaaS environment without open-sourcing their proprietary modifications
- Remove the AGPLv3 restrictions
- Receive priority technical support and SLA guarantees

Please contact **founders@speakit.ai** to purchase a Commercial License.

---

_Built and maintained by [Mohd Mohitur Rahaman](https://github.com/Mohitur669) — Enterprise AI Voice Synthesis._
