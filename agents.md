# SpeakIT Engineering Guide (AGENTS.md)

This document serves as the authoritative architectural blueprint and engineering standard for AI coding agents and developers working on the SpeakIT platform.

---

## 1. Project Overview & Tech Stack

SpeakIT is a production-grade SaaS for AI voice generation. It is designed for high concurrency, minimal database latency, and sub-second TTS delivery.

### Tech Stack
- **Backend:** Java 21, Spring Boot 3.x, Spring Security (JWT)
- **Data Layer:** PostgreSQL, Hibernate/JPA, Bucket4j (Rate Limiting)
- **Frontend:** Angular 21.x (Standalone Components, Signals), Tailwind CSS
- **Infrastructure:** AWS Polly (Neural Engine), Docker, Render (Keep-alive architecture)

---

## 2. Backend Architecture Standards

### Layered Responsibility
1. **Controllers:** Thin wrappers. Use `@Valid` for DTO validation. Accept `HttpServletRequest` to access pre-cached user attributes.
2. **Services:** Domain logic only. Must be `@Transactional` where state changes occur.
3. **Repositories:** Use JPA Interface Projections for READ operations. Use `@Modifying` JPQL for high-frequency updates.
4. **DTOs:** Mandatory for all API input/output. Never expose Entities directly.
5. **Entities:** Must extend `BaseEntity` for auditing. Use `FetchType.LAZY` for all relationships.

### High-Performance Data Access (Mandatory)
- **Eliminate Over-fetching:** Use projections to pull only required fields.
- **N+1 Prevention:** Never query the User entity inside a loop or repeatedly across a filter-controller chain.
- **Request Attribute Caching:** `JwtAuthenticationFilter` pre-fetches `userId` and `hasNaturalVoiceAccess`. **Controllers must read from attributes first.**
- **Atomic Updates:** Use `@Modifying` queries for session increments or flag toggles.
- **Relationship Linking:** Use `userRepository.getReferenceById(id)` when saving child entities.

---

## 3. Database & JPA Standards

### Schema Design & Naming
- **Snake Case:** Always use `snake_case` for table and column names.
- **Auditing:** All production tables must include `created_at`, `updated_at`, and optionally `version`.
- **Soft Deletes:** Use `is_active` boolean (and `deleted_at` if needed) to preserve data integrity.
- **Constraints:** Enforce `VARCHAR` limits (e.g., username=50, email=100) to match DTO validation.
- **Foreign Keys:** Types must always match the referenced PK type (`BIGINT`). Use consistent naming: `{entity}_id` (e.g., `user_id`).

### Database Column Ordering
All tables must follow this enterprise ordering pattern:
1. Primary Key (`id`)
2. Foreign Keys (`user_id`, etc.)
3. Core Business Fields
4. Status/Boolean Fields (`is_active`, etc.)
5. Analytics/Tracking Fields
6. Audit Fields (`created_at`, `updated_at`)
7. Soft Delete Fields (`deleted_at`)
8. Version Fields (`version`)

### Indexing Strategy
- **Mandatory Indexing:** Index all Foreign Keys and frequently sorted/filtered columns (`username`, `created_at`).
- **Composite Indexes:** Use for multi-column search paths to optimize query plans.
- **Unique Constraints:** Apply to business identifiers (`username`, `email`).

---

## 4. Primary Key & Sequence Standards

### ID Generation Strategy
- **Internal IDs:** Use numeric `Long` primary keys with `GenerationType.SEQUENCE`. This improves insert performance and reduces database contention compared to `IDENTITY`.
- **Dedicated Sequences:** Each major table must have its own sequence named `{table_name}_seq`.
- **Never Use:** `GenerationType.AUTO` or shared default Hibernate sequences.

**Preferred Entity Pattern:**
```java
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_seq")
@SequenceGenerator(
    name = "user_seq",
    sequenceName = "user_seq",
    allocationSize = 50
)
private Long id;
```

### Allocation Size Rules
- Use optimized `allocationSize` to reduce database round-trips.
- Default: `50`.
- Heavy-write tables: `100`.

---

## 5. Frontend Architecture Standards

### Angular Style Guide
- **Standalone Components:** All new components must be standalone.
- **Signals:** Prefer Signals (`signal`, `computed`, `effect`) for local component state.
- **State Flow:** Services hold global state; Components consume state via Signals.

### Folder Structure
```text
src/app/
 ├── core/         # Singletons: Auth, Interceptors, Guards, API Services
 ├── shared/       # Reusable UI: Navbar, Footer, Toast, UI Kits
 ├── features/     # Domain Modules: auth, tts, dashboard, marketing
 └── environments/ # Runtime & Build configs
```

### UI/UX Rules
- **Consistency:** Use Tailwind CSS utility classes.
- **Plan Enforcement:** Components must dynamically adjust UI (e.g., `maxlength`, visibility) based on `authService.hasNaturalAccess()`.
- **Loading States:** Every async action must have a `loading` signal and corresponding UI feedback.

---

## 7. Security & Validation

...
- **JWT:** Stateless. Validated against `session_version` in the DB.
---

## 8. Logging & Observability Standards

### Backend Structured Logging
- **Request Tracing:** Every request is assigned a unique 8-character `requestId` via `RequestLoggingFilter`, stored in the SLF4J MDC. 
- **Pattern:** Logs must follow the standard pattern: `[timestamp] [level] [requestId] [logger] : message`.
- **MDC Usage:** The `requestId` is automatically included in all logs generated during a request thread.

### Frontend Observability
- **Centralized Logger:** All logging must go through `LoggerService`. Never use `console.log` directly in feature components or services.
- **Environment Aware:** `LoggerService` automatically suppresses `debug` and `info` logs in production based on the `LOG_LEVEL` environment variable.
- **Sensitive Data Protection:** The logger includes a `sanitize` mechanism that automatically redacts fields like `token`, `password`, and `jwt` from log arguments.
- **Standard Levels:**
    - `debug`: Low-level tracing (e.g., WebSocket connection attempts).
    - `info`: Key milestones (e.g., session hydration).
    - `warn`: Recoverable errors (e.g., 401/403 auth failures).
    - `error`: Fatal exceptions (e.g., API unreachable).

### Production Log Management
- **File Rotation:** Configured in `application.properties` with a 10MB per-file limit and 30-day retention.
...
- **Root Level:** Default is `INFO`. Spring internals are suppressed to `WARN` to reduce noise.
- **Sensitive Data:** NEVER log passwords, tokens, or raw PII. Mask identifiers if logging is required for debugging.

### Exception Logging
- **Global Handler:** `GlobalExceptionHandler` logs all errors with the `requestId`.
- **Level Usage:**
    - `ERROR`: System failures, integration issues (AWS Polly, DB).
    - `WARN`: User-driven errors (Validation failed, Rate limit hit).
    - `INFO`: Critical business milestones (User registered, synthesis successful).

---

## 9. AI Agent Database Rules

### Investigation Phase (Read-Before-Write)
1. **Analyze Relationships:** Inspect existing foreign keys and JPA mappings.
2. **Analyze Query Patterns:** Check repositories for existing projections and N+1 risks.
3. **Analyze Frontend Usage:** Only fetch fields required by the actual UI screens.

### Implementation Phase
- **Preserve Compatibility:** Avoid destructive schema changes. Use migrations.
- **Maintain Migration Safety:** When adding `NOT NULL` columns to existing tables, make them nullable in JPA first or provide a backfill SQL script.
- **Consistent Naming:** Match existing project conventions (`snake_case` DB, `camelCase` Java).

---

## 8. Local Development Commands

| Task | Command |
| :--- | :--- |
| **Backend Run** | `./mvnw spring-boot:run` |
| **Backend Build** | `./mvnw clean package -DskipTests` |
| **Frontend Run** | `npm start` |
| **Frontend Build** | `npm run build` |
| **Full Stack** | `docker compose up --build` |

---

## 9. Deployment Constraints
- **Keep-Alive:** GitHub Action pings `/api/auth/ping` every 25 mins.
- **CORS:** Origins are restricted via `application.properties`. Update for new environments.
