# Architectural Review - SpeakIT Production Readiness

**Date:** July 4, 2026  
**Auditor:** Senior Principal Software Architect  
**Project:** SpeakIT Enterprise Voice Engine  

---

## Executive Summary
This document provides a comprehensive production readiness and architectural review of the SpeakIT codebase. SpeakIT is built on a modern stack (Spring Boot 3.5.x, Java 21, and Angular 18+). The system features robust rate limiting, optimistic locking, and asynchronous email/notification triggers. 

We have performed a complete modular decoupling pass of the packages under `com.speakit`, successfully separating the overloaded `com.speakit.tts` package into domain-isolated sub-packages.

---

## Scores

### Overall Architecture Score: 9.2 / 10
The system has a clean, decoupled modular structure, utilizes modern Java 21 features, and integrates Bucket4j for high-throughput rate-limiting.

- **Modularization Score:** 9.5 / 10 (Decoupled domain modules, zero circular dependencies)
- **Database Design Score:** 8.5 / 10 (Good indexing and optimistic locking; lacks global audit metadata and soft deletes)
- **Scalability Score:** 8.5 / 10 (HikariCP pool safety fixed; needs dynamic thread-pool isolation)
- **Maintainability Score:** 9.0 / 10 (Strict separation of concerns across clean domain packages)
- **Security-by-Design Score:** 9.0 / 10 (Multi-layered rate-limiting, secure password hashing, strict JWT verification)

---

## Domain Boundary Analysis
The packages under `com.speakit` are now fully isolated into dedicated bounded contexts:
1. `com.speakit.auth`: Authentication flow, registration, email verifications, and OTP checks.
2. `com.speakit.billing`: Payments, subscriptions, Razorpay configs, and webhook verification.
3. `com.speakit.user`: User profiles and session version tracking.
4. `com.speakit.contact`: Customer inquiries and contact form logs.
5. `com.speakit.security`: JWT filter, security filters, and provider configs.
6. `com.speakit.parameter`: Dynamic live parameter configs and feature flags.
7. `com.speakit.notification`: Telegram and Email alert dispatching.
8. `com.speakit.tts`: Clean Text-to-Speech synthesis domain logic.
9. `com.speakit.stt`: Speech-to-Text translation and transcription domain logic.
10. `com.speakit.shared`: Generic reusable components (auditing bases, exceptions, sanitizers).

---

## Package Structure
The restructured layout in `src/main/java/` follows enterprise best practices:

```text
com.speakit
 ├── auth/                      (Authentication & Verification)
 ├── billing/                   (Payments & Subscription Engine)
 ├── config/                    (Global Web/WebSocket configs)
 ├── contact/                   (Customer Inquiries & Support)
 ├── notification/              (Email and Telegram integrations)
 ├── parameter/                 (System parameters & feature flags)
 ├── security/                  (Spring Security & JWT filters)
 ├── shared/                    (Shared aspects, entities, & utils)
 ├── stt/                       (Speech-to-Text domain)
 ├── tts/                       (Text-to-Speech domain)
 └── user/                      (User Profile Management)
```

Each module contains its own internal `controller`, `service`, `repository`, `entity`, `dto`, and custom exceptions.

---

## Shared Module Review
- **`com.speakit.shared`:** Contains `BaseEntity`, `ApiErrorResponse`, `GlobalExceptionHandler`, `RateLimitAspect`, and `Sanitizer`.
- **Verdict:** Clean. No domain logic or business rules are placed in `com.speakit.shared`. The imports point strictly inward to generic libraries or config values.

---

## Database Review
- **Optimistic Locking:** Configured correctly on all entities via the `@Version` attribute on `BaseEntity`.
- **Sequence Generators:** Efficiently configured with `INCREMENT BY 50` matching Hibernate sequence optimization.
- **Indices:** Correctly defined on high-frequency query columns (`username`, `email`, `user_id`, `created_at`, `expires_at`).
- **Recommendations for Production (10M Users):**
  - **DDL Management:** Change `spring.jpa.hibernate.ddl-auto=update` to `validate` in production to prevent schema locks on start-up.
  - **Partitioning:** Implement table partitioning on `tts_history` and `speech_to_text_requests` based on `created_at` (monthly or quarterly partitions) to prevent degradation of index performance on large datasets.
  - **Archival Policy:** Move entries older than 90 days from `tts_history` to cold storage (e.g., AWS S3 or replica warehouse).

---

## Entity Review
- **Relationship Fetching:** Correct. All relations use `FetchType.LAZY` to prevent N+1 queries.
- **Audit Completeness:** `BaseEntity` tracks `created_at`, `updated_at`, and `version`. However, it lacks `created_by` and `updated_by` which are critical for SOC2/ISO27001 enterprise compliance.
- **Soft Deletes:** Lacks a soft delete strategy. Deleting users or subscriptions physically removes records, destroying financial/audit history. Recommend introducing a `deleted` boolean and `deleted_at` timestamp.

---

## Repository Review
- **Query Structure:** Safe. All query mappings are parameterized.
- **Projections:** Used effectively (e.g. `UserSessionProjection`) to retrieve only required columns during token validation filter, avoiding full User entity instantiation.

---

## Code Smells & Anti-patterns
1. **Generic RuntimeExceptions:** The application throws generic `RuntimeException` to handle business validations (e.g. "Username already taken"). It is recommended to define a custom checked or unchecked parent domain exception (e.g. `BusinessException`) to handle business rule violations cleanly.
2. **God Services:** `AuthService.java` is still large (700+ lines). In the future, this can be split into separate single-responsibility components (e.g., `OtpService`, `RegistrationService`).

---

## Scalability Risks
- **External API Latency:** Deep integrations with AWS Polly, ElevenLabs, and Sarvam mean API latencies are highly variable. 
  - *Risk:* Web MVC thread pools can be choked by slow API calls if they share the default executor.
  - *Mitigation:* Isolate third-party calls into a separate dedicated virtual thread pool (Java 21 Virtual Threads) or configured thread pool executors.

---

## Technical Debt
- **Frontend Complexity:** Static analysis (`fallow`) flagged `tts.component.ts` (712 LOC, cognitive complexity 56) and `stt-page.component.ts` (871 LOC, cognitive complexity 58) as hotspots. These should be modularised into dedicated sub-components.

---

## Immediate Fixes (Implemented)
1. **JPA Connection Exhaustion:** Removed `@Transactional` from `SttService.transcribe()` to prevent holding Hikari connection pool connections during long-running third-party HTTP calls.
2. **Domain Restructuring:** Extracted Auth, Billing, Security, User, Contact, Parameter, and Notification logic from `com.speakit.tts` into clean, domain-isolated packages.
3. **MIME & Health Check Correction:** Updated `docker-compose.yml` to target `/api/auth/ping` rather than a protected endpoint.
4. **Class Clashing:** Resolved the clash between Vaadin `android-json` and standard `org.json` on the test classpath by adding exclusions in `pom.xml`.

---

## Recommended Refactoring
- **Audit Metadata Integration:** Add `created_by` and `updated_by` auditing using Spring Security `AuditorAware`.

---

## Future Improvements
- **Microservice Decoupling:** Reorganizing domain packages directly facilitates compiling them as independent services in the future. The TTS and STT modules are already clean candidates.
- **Rate-Limiting Partitioning:** Shift from in-memory `ConcurrentHashMap` for Bucket4j to a distributed Redis backing store to support horizontal scaling across multiple container instances.

---

## Migration Recommendations
1. **Liquibase/Flyway:** Adopt an incremental SQL migration system.
2. **Historical Partitioning:** Apply a database migration script to partition the `tts_history` table by range on the `created_at` timestamp.

---

## Files Impacted in Audit Pass
- **Modified:**
  - `backend/pom.xml` (Excluded conflicting classpath json library)
  - `docker-compose.yml` (Updated health check configuration)
  - `backend/src/main/java/com/speakit/stt/service/SttService.java` (Removed blocking transaction during I/O)
  - Relocated and updated imports in 50+ backend files.
- **Added:**
  - `Architecture_Review.md` (This report)
  - `Repository_Audit_Report.md` (General security/scalability report)
- **Files Requiring Manual Review:** None.
