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

## Package & Directory Structure
The backend is structured into two main namespaces: `com.speakit` for module-specific business logic, and `com.shared` for common utility/infrastructure components.

```text
src/main/java/
 ├── com/
 │    ├── speakit/
 │    │    ├── SpeakItApplication.java   (Application Root)
 │    │    ├── tts/                      (Text-to-Speech domain)
 │    │    │    ├── aspect/
 │    │    │    ├── config/
 │    │    │    ├── controller/
 │    │    │    ├── dto/
 │    │    │    ├── entity/
 │    │    │    ├── exception/
 │    │    │    ├── repository/
 │    │    │    ├── security/
 │    │    │    └── service/
 │    │    └── stt/                      (Speech-to-Text domain)
 │    │         ├── controller/
 │    │         ├── dto/
 │    │         ├── entity/
 │    │         ├── exception/
 │    │         ├── provider/
 │    │         ├── repository/
 │    │         └── service/
 │    └── shared/                        (Common modules)
 │         ├── aspect/                   (Common aspect-based shields)
 │         ├── dto/                      (Common responses)
 │         ├── entity/                   (Common JPA entity bases)
 │         ├── exception/                (Common exception handler & exceptions)
 │         └── util/                     (Common utilities/sanitizers)
```

- **Rule:** Never duplicate cross-cutting infrastructure (like rate limit shields, global exception handlers, sanitizers, or base auditing entities) under `com.speakit`. Move them to `com.shared` for global reuse.

## High-Performance Data Access (Mandatory)
- **Eliminate Over-fetching:** Use projections to pull only required fields.
- **N+1 Prevention:** Never query the User entity inside a loop or repeatedly across a filter-controller chain.
- **Request Attribute Caching:** `JwtAuthenticationFilter` pre-fetches `userId` and `planType`. Controllers must read from request attributes first.
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

## Git & Commits
- **NEVER commit anything without explicit user permission.** Always ask the user before staging (`git add`) or committing (`git commit`) any changes. 
- AI agents must never automatically push to remote repositories.

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

---

# 14. Anti-Duplication & Code Reuse Standards

> This section is enforced by **fallow** (dead-code, duplication, and health analysis) and **fallow skills** installed in the project directory. All AI agents and developers must comply. These rules apply to every feature — current and future.

## 14.1 Mandatory Pre-Implementation Scan

Before writing any new component, service, utility function, validator, or helper:

1. **Run fallow** to get the current duplication baseline:
   ```bash
   npx fallow          # full report (dead code + dupes + health)
   npx fallow dupes    # duplication only
   ```
2. **Search `shared/` first.** If a component, directive, pipe, or utility already exists there — use it. Do not re-implement it.
3. **Search by behavior, not name.** A password validator named `isPasswordStrong` in `signup.component.ts` is the same as `isPasswordValid` in `profile-settings.component.ts`. Search for the logic pattern, not just the identifier.
4. **If you find similar logic in a feature component** — extract it to `shared/` before adding more call sites.

## 14.2 Shared Directory — Source of Truth for Reusable Code

```text
frontend/src/app/shared/
 ├── components/          ← reusable UI components (inputs, buttons, modals, loaders)
 ├── directives/          ← attribute directives (e.g. onlyNumbers, trimInput)
 ├── pipes/               ← pure transformation pipes
 ├── validators/          ← AbstractControl validators (password, phone, email rules)
 ├── utils/               ← pure functions (formatting, parsing, regex constants)
 └── index.ts             ← barrel export — always export new additions here
```

**Rules:**
- Any logic used in **2 or more places** must live in `shared/`. No exceptions.
- Feature components import from `shared/`. `shared/` never imports from `features/`.
- Always add new shared items to `shared/index.ts` immediately.

## 14.3 Known Duplications to Fix (from fallow output)

The following duplication was detected by fallow and must be resolved before adding new features to these files:

| Clone Family | Lines | Files |
|---|---|---|
| Password validation logic (`isPasswordValid`) | 7 lines × 2 | `signup.component.ts:302`, `profile-settings.component.ts:309` |
| Numeric-only input handler (`onlyNumbers`) | 6 lines × 2 | `signup.component.ts:367`, `profile-settings.component.ts:386` |
| Form field build logic | 37 lines × 2 | `signup.component.ts:244–280`, `profile-settings.component.ts:259–294` |
| Submit/save handler pattern | 28 lines × 2 | `signup.component.ts:344–371`, `profile-settings.component.ts:363–390` |
| Error mapping block | 19 lines × 2 | `signup.component.ts:370–388`, `profile-settings.component.ts:397–415` |
| Field reset logic | 18 lines × 2 | `signup.component.ts:290–307`, `profile-settings.component.ts:297–314` |
| Validation feedback block | 11+10+9 lines × 2 | `signup.component.ts:317–344`, `profile-settings.component.ts:336–363` |

**Resolution plan:**
```text
Extract to:
  shared/validators/password.validator.ts         ← isPasswordValid()
  shared/directives/only-numbers.directive.ts     ← onlyNumbers handler → @Directive
  shared/utils/form.utils.ts                      ← shared form build/reset helpers
  shared/components/password-field/               ← if UI is also duplicated
```

## 14.4 Dead Code Removal Protocol

fallow currently flags these as unreachable — remove before they accumulate:

| File | Issue |
|---|---|
| `frontend/src/app/app.scss` | Unused file — not reachable from any entry point |
| `frontend/src/app/core/index.ts` | Unused barrel — no consumers |
| `frontend/src/app/shared/components/index.ts` | Unused barrel — add exports or remove |
| `frontend/src/app/shared/index.ts` | Unused barrel — populate or remove |
| `core/auth/models/auth.models.ts` `:25 User` | Unused type export — remove or consume |

**Protocol:**
1. Before removing: `grep -r "ClassName\|functionName" src/` to confirm zero consumers.
2. Remove the dead code.
3. Re-run `npx fallow` to confirm clean.
4. Commit with message: `chore: remove dead code flagged by fallow`.

## 14.5 Complexity Budget — Per-File Limits

fallow health scores enforce these hard limits. AI agents must not generate code that exceeds them:

| Metric | Limit | Action if exceeded |
|---|---|---|
| File LOC | 300 lines | Split into sub-components or extract services |
| Function LOC | 40 lines | Extract named private methods |
| Cyclomatic complexity | 10 per function | Break into smaller decision paths |
| Cognitive complexity | 15 per function | Flatten nested conditionals; extract helpers |
| CRAP score | < 30 (estimated) | Reduce complexity or increase test coverage |
| Template LOC (`<template>`) | 150 lines | Extract child components |

**Current files already over budget** (do not add further complexity — only reduce):

| File | Current cyclomatic | Current template LOC | Action |
|---|---|---|---|
| `tts.component.ts` + `.html` | 66 / 56 | 244 | Extract sub-components: voice selector, output panel, controls bar |
| `profile-settings.component.ts` | 51 | 225 | Extract: password section, profile section, plan section |
| `signup.component.ts` | 49 | 208 | Extract: password field group, validation summary |
| `razorpay.service.ts` | 11 | — | Extract: error handler, retry logic |

## 14.6 Template Decomposition Standard

Large inline templates are the primary source of complexity violations in this codebase. Apply this pattern:

**Instead of one god-template:**
```typescript
// ❌ tts.component.ts — 244-line template doing everything
@Component({
  template: `
    <!-- voice selector: 40 lines -->
    <!-- text input: 30 lines -->
    <!-- output audio panel: 60 lines -->
    <!-- controls: 50 lines -->
    <!-- history table: 64 lines -->
  `
})
```

**Extract into focused child components:**
```typescript
// ✅ tts.component.ts — orchestrator only
@Component({
  template: `
    <app-voice-selector [(voice)]="selectedVoice" />
    <app-tts-input [(text)]="inputText" (convert)="onConvert()" />
    <app-tts-output [result]="result()" />
    <app-tts-history [entries]="history()" />
  `,
  imports: [VoiceSelectorComponent, TtsInputComponent, TtsOutputComponent, TtsHistoryComponent]
})
```

Each child component lives in its own folder under `features/tts/components/`.

## 14.7 New Feature Checklist (Anti-Duplication Gate)

Every AI agent must complete this checklist before generating code for any new feature:

```
PRE-IMPLEMENTATION
[ ] Run: npx fallow dupes — confirm no existing clone of this logic
[ ] Search shared/ for existing validators, utils, directives that apply
[ ] Search feature files for similar patterns (form build, submit handler, error map)
[ ] If similar logic exists: extract first, then reuse — never copy

IMPLEMENTATION
[ ] Form validators → shared/validators/
[ ] Input masks / key handlers → shared/directives/
[ ] Pure utility functions → shared/utils/
[ ] Reusable UI blocks (> 20 lines, used in 2+ places) → shared/components/
[ ] Export all new shared items from shared/index.ts
[ ] No single template exceeds 150 lines
[ ] No single function exceeds 40 lines or cyclomatic 10

POST-IMPLEMENTATION
[ ] Run: npx fallow — zero new duplication warnings
[ ] Run: npx fallow health — no new files above complexity threshold
[ ] Commit shared extractions separately from feature code
     e.g. "refactor: extract password validator to shared" then "feat: add profile update"
```

## 14.8 fallow Integration in CI (Recommended)

Add to `.github/workflows/` to enforce these rules on every PR:

```yaml
- name: Run fallow analysis
  run: |
    cd frontend
    npx fallow --format json > fallow-report.json
    # Fail if new duplication or dead code is introduced
    npx fallow dupes
    npx fallow dead-code
```

If fallow reports new clone groups or dead files introduced by the PR, the PR must not be merged until resolved.

## 14.9 Refactoring Priority Order (from fallow)

When scheduling refactoring work, follow fallow's computed priority:

| Priority | File | Reason | Suggested Action |
|---|---|---|---|
| 1 (high) | `core/auth/auth.service.ts` | 9 dependents, highest churn, 271 LOC | Split into `AuthTokenService`, `AuthSessionService`, `OAuthService` |
| 2 | `tts.component.html` | cognitive 62, 244 LOC | Extract child components (see §14.6) |
| 3 | `signup.component.ts` | cognitive 33, 435 LOC, 7 clone groups | Extract shared validators + child form sections |
| 4 | `profile-settings.component.ts` | cognitive 39, 452 LOC, 7 clone groups | Same as above — shares all clones with signup |

> **Note:** Items 3 and 4 share the same 7 clone families. Fix them together in a single refactor PR to avoid partial extractions.

---
