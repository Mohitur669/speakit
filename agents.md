# SpeakIT Engineering Guide (AGENTS.md)

This document serves as the authoritative architectural blueprint and engineering standard for AI coding agents and developers working on the SpeakIT platform.

---

# 1. Project Overview & Tech Stack

SpeakIT is a production-grade SaaS for AI voice generation. It is designed for high concurrency, minimal database latency, and sub-second TTS delivery.

## Tech Stack
- **Backend:** Java 21, Spring Boot 3.x, Spring Security (JWT)
- **Data Layer:** PostgreSQL, Hibernate/JPA, Bucket4j (Rate Limiting)
- **Frontend:** Angular 21.x (Standalone Components, Signals), Tailwind CSS
- **Infrastructure:** AWS Polly (Neural Engine), Docker, Render (Keep-alive architecture)

---

# 2. Backend Architecture Standards

## Layered Responsibility
1. **Controllers:** Thin wrappers. Use `@Valid` for DTO validation. Accept `HttpServletRequest` to access pre-cached user attributes.
2. **Services:** Domain logic only. Must be `@Transactional` where state changes occur.
3. **Repositories:** Use JPA Interface Projections for READ operations. Use `@Modifying` JPQL for high-frequency updates.
4. **DTOs:** Mandatory for all API input/output. Never expose Entities directly.
5. **Entities:** Must extend `BaseEntity` for auditing. Use `FetchType.LAZY` for all relationships.
6. **OSIV:** `spring.jpa.open-in-view=false` in production to prevent unintended database queries during view rendering.

## High-Performance Data Access (Mandatory)
- **Eliminate Over-fetching:** Use projections to pull only required fields.
- **N+1 Prevention:** Never query the User entity inside a loop or repeatedly across a filter-controller chain.
- **Request Attribute Caching:** `JwtAuthenticationFilter` pre-fetches `userId` and `hasNaturalVoiceAccess`. Controllers must read from request attributes first.
- **Atomic Updates:** Use `@Modifying` queries for session increments or flag toggles.
- **Relationship Linking:** Use `userRepository.getReferenceById(id)` when saving child entities.

---

# 3. Database & JPA Standards

## Schema Design & Naming
- Always use `snake_case` for table and column names.
- All production tables must include:
  - `created_at`
  - `updated_at`
  - optionally `version`
- Soft deletes should use:
  - `is_active`
  - optionally `deleted_at`
- Enforce VARCHAR limits to match DTO validation.
- Foreign key types must always match referenced PK types (`BIGINT`).

## Database Column Ordering
1. Primary Key (`id`)
2. Foreign Keys (`user_id`)
3. Core Business Fields
4. Status/Boolean Fields
5. Analytics/Tracking Fields
6. Audit Fields
7. Soft Delete Fields
8. Version Fields

## Indexing Strategy
- Index all foreign keys.
- Index frequently filtered/sorted columns.
- Use composite indexes for multi-column query paths.
- Apply unique constraints to business identifiers.

---

# 4. Primary Key & Sequence Standards

## ID Generation Strategy
- Use numeric `Long` primary keys.
- Use `GenerationType.SEQUENCE`.
- Each table must have dedicated sequences.

### Preferred Pattern
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

## Allocation Size Rules
- Default: `50`
- Heavy write tables: `100`

---

# 5. Frontend Architecture Standards

## Angular Style Guide
- All new components must be standalone.
- Prefer Angular Signals for local state.
- Services hold global state.
- Components consume state via Signals.

## Folder Structure
```text
src/app/
 ├── core/
 ├── shared/
 ├── features/
 └── environments/
```

## UI/UX Rules
- Use Tailwind utility classes consistently.
- Components must dynamically adapt based on plan/access.
- Every async action must have loading state feedback.

---

# 6. Security & Validation

## Authentication
- JWT must remain stateless.
- Validate JWT against `session_version`.

## Lowercase Enforcement
- Usernames and emails must always be stored and processed in lowercase.
- Enforce both frontend and backend normalization.

## Sensitive Data Protection
- Never expose internal entities directly.
- Never log passwords, tokens, JWTs, or sensitive PII.
- Sanitize logs automatically.

---

# 7. Logging & Observability Standards

## Backend Structured Logging
- Every request receives unique `requestId`.
- Logs must follow:
```text
[timestamp] [level] [requestId] [logger] : message
```

## Frontend Logging
- Always use centralized `LoggerService`.
- Never use direct `console.log`.
- Suppress debug/info logs in production.

## Log Levels
- `debug`
- `info`
- `warn`
- `error`

## Exception Logging
- `GlobalExceptionHandler` must include `requestId`.
- Use proper log severity levels.

---

# 8. AI Agent Database Rules

## Investigation Phase (Read-Before-Write)
Before modifying anything:
1. Analyze existing relationships.
2. Analyze repositories and query patterns.
3. Analyze frontend usage.
4. Identify potential N+1 risks.
5. Identify backward compatibility impact.

## Implementation Phase
- Avoid destructive schema changes.
- Use migrations.
- Preserve compatibility.
- Maintain naming consistency.

---

# 9. Critical Stability & Backward Compatibility Rules

## Preserve Existing Business Logic
- NEVER change existing business logic unless absolutely necessary.
- Preserve:
  - Authentication flow
  - Authorization rules
  - Payment flow
  - Subscription enforcement
  - Validation logic
  - Rate limiting
  - Analytics logic
  - Existing workflows
  - Existing API contracts

## Backward Compatibility (Mandatory)
All updates must remain backward compatible.

Do NOT break:
- Existing APIs
- DTO contracts
- Database schema compatibility
- Frontend bindings
- Existing integrations
- Existing authentication/session behavior

## Comment Preservation Rule
- NEVER delete existing comments.
- NEVER remove TODOs, documentation, notes, or architectural explanations.
- Existing comments are part of the engineering knowledge system.

Allowed:
- Add comments
- Improve clarity
- Append explanations

Not allowed:
- Remove historical developer context without replacement clarification.

## Minimal Change Principle
- Prefer the smallest safe implementation.
- Avoid unnecessary refactoring.
- Avoid unrelated formatting changes.
- Avoid renaming stable modules unless required.

## Safe Refactoring Rules
If refactoring is unavoidable:
- Preserve public APIs.
- Preserve behavior.
- Preserve logs.
- Preserve validation rules.
- Preserve DB compatibility.
- Preserve monitoring/tracing behavior.

## UI/UX Preservation
- Do not redesign existing UI unless explicitly requested.
- Preserve:
  - responsiveness
  - dark/light mode
  - accessibility
  - existing design system consistency

## Database Safety Rules
- Never drop columns/tables unless explicitly required.
- New columns should initially be nullable or safely backfilled.
- Preserve relationships and constraints.

## Logging Preservation
- Do not remove existing logs unless duplicated/harmful.
- Preserve observability and audit behavior.

## Final Validation Requirement
Before finalizing implementation:
1. Verify existing features still work.
2. Verify backward compatibility.
3. Verify comments remain intact.
4. Verify no unrelated logic changed.
5. Verify existing business flows remain unchanged.

---

# 10. Local Development Commands

| Task | Command |
|---|---|
| Backend Run | `./mvnw spring-boot:run` |
| Backend Build | `./mvnw clean package -DskipTests` |
| Frontend Run | `npm start` |
| Frontend Build | `npm run build` |
| Full Stack | `docker compose up --build` |

---

# 11. Deployment Constraints

## Keep Alive
- GitHub Action pings `/api/auth/ping` every 25 minutes.

## CORS
- Origins are restricted via configuration.
- Update allowed origins carefully.

## Production Safety
- Never expose secrets in frontend builds.
- Use environment variables.
- Preserve production logging behavior.

---

# 12. AI Agent Operational Rules

## Read Before Modify
Before editing any file:
1. Read surrounding implementation.
2. Understand dependencies.
3. Check service/repository/controller usage.
4. Check frontend integration impact.
5. Check DTO compatibility.

## Avoid Destructive Changes
- Never mass rewrite files.
- Never replace stable architecture unnecessarily.
- Never remove unused-looking code without investigation.

## Enterprise Coding Standards
All generated code must be:
- Production-ready
- Clean
- Maintainable
- Modular
- Type-safe
- Performance-aware
- Secure-by-default

## Testing Expectations
When implementing features:
- Preserve existing tests.
- Avoid breaking integration flows.
- Ensure API compatibility.

## Documentation Rules
- Preserve all existing documentation.
- Add concise explanations for complex logic.
- Keep architecture decisions discoverable.

---

# 13. Final Engineering Principle

The platform is production-grade.

Every modification must prioritize:
1. Stability
2. Backward compatibility
3. Performance
4. Security
5. Maintainability
6. Minimal-risk implementation

When uncertain:
- Preserve existing behavior.
- Prefer additive changes over destructive changes.
- Avoid assumptions.
- Analyze before modifying.
