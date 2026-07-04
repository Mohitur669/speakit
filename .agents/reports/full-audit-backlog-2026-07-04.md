# SpeakIT — Consolidated Audit Backlog

This report aggregates all findings from **Phases 1–5** of the repository audit.

---

## Phase 1 — Codebase Intelligence (`fallow`)

### ## [SEVERITY: Low] Unused Component Inputs in `tts-input.component.ts`
- **Source skill:** `fallow`
- **File(s):** [tts-input.component.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/tts/components/tts-input/tts-input.component.ts) (Lines 68, 69)
- **Current behavior:** `@Input() loading` and `@Input() voiceId` are declared but never read.
- **Risk if unfixed:** Unnecessary props bloat the compiler memory and code footprint.
- **Proposed minimal fix:** Delete the unused inputs.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Verify component specs pass.

### ## [SEVERITY: Low] Unused Component Output `convert` in `tts-input.component.ts`
- **Source skill:** `fallow`
- **File(s):** [tts-input.component.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/tts/components/tts-input/tts-input.component.ts) (Line 72)
- **Current behavior:** `@Output() convert` is declared but never emitted.
- **Risk if unfixed:** Dead event emitter code.
- **Proposed minimal fix:** Remove the unused output emitter.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Verify specs pass.

### ## [SEVERITY: Low] Unused Component Output `selectedCountryChange` in `profile-form.component.ts`
- **Source skill:** `fallow`
- **File(s):** [profile-form.component.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/user/profile-settings/components/profile-form/profile-form.component.ts) (Line 118)
- **Current behavior:** Output emitter `selectedCountryChange` is declared but never emitted.
- **Risk if unfixed:** Dead code.
- **Proposed minimal fix:** Delete the unused output.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Verify form component specs pass.

### ## [SEVERITY: Low] Unlisted Code Duplications in Angular Components
- **Source skill:** `fallow`
- **File(s):** 
    - `verify-email.component.ts` (126-138) and `verify-profile.component.ts` (174-187) [14 lines]
    - `verify-email.component.ts` (146-158) and `verify-profile.component.ts` (217-229) [13 lines]
    - `transcript-card.component.ts` (252-263) and `stt-page.component.ts` (560-571) [12 lines]
    - `reset-password.component.ts` (149-159) and `verify-email.component.ts` (106-116) [11 lines]
    - `stt.service.ts` (22-29) and `stt.service.ts` (41-48) [8 lines]
    - `stt-page.component.ts` (759-763) and `stt-page.component.ts` (767-771) [5 lines]
- **Current behavior:** Near-identical helper methods/error mappings across multiple files.
- **Risk if unfixed:** Maintenance overhead; potential for divergent behavior when fixing issues.
- **Proposed minimal fix:** Extract redundant logic (e.g. error/alert parsing and timer countdown functions) to shared utility helpers or directives.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Ensure unit tests of affected components continue to pass.

---

## Phase 2 — Architecture Review (`architect-review`)

### ## [SEVERITY: Medium] Bounded Context Boundary Violations in Controllers
- **Source skill:** `architect-review`
- **File(s):**
    - [PaymentController.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/billing/controller/PaymentController.java)
    - [TtsController.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/tts/controller/TtsController.java)
- **Current behavior:** Billing and TTS controllers directly access `UserRepository` to fetch/verify user records.
- **Risk if unfixed:** Direct coupling of different feature modules to the core User persistence layer, bypassing the service layer.
- **Proposed minimal fix:** Inject a facade or service interface (e.g. `UserService` or `AuthService`) to handle user retrieval or validation.
- **Requires sign-off before fix?** Y (Touches user context interaction)
- **Test to add/extend before fixing:** Verify controller integration tests.

### ## [SEVERITY: Medium] Duplicate Business Orchestration in TTS Module
- **Source skill:** `backend-architect`
- **File(s):**
    - [TtsController.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/tts/controller/TtsController.java)
    - [TtsService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/tts/service/TtsService.java)
- **Current behavior:** `recordHistory` and `validatePlanAccess` are duplicated in both the Controller and Service classes.
- **Risk if unfixed:** Logic drift; controller performing database/transaction actions directly.
- **Proposed minimal fix:** Delete duplicates from `TtsController.java` and delegate directly to `TtsService`.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Verify `TtsController` test suite continues to pass.

---

## Phase 3 — Language & Framework Modernization (`java-pro`, `typescript-pro`)

### ## [SEVERITY: Low] Enable Virtual Threads for Java 21 Performance
- **Source skill:** `java-pro`
- **File(s):** [application.properties](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/resources/application.properties)
- **Current behavior:** Virtual threads are not explicitly enabled.
- **Risk if unfixed:** Misses out on lightweight concurrency benefits of Java 21 for blockable I/O (e.g. external TTS/STT and database connections).
- **Proposed minimal fix:** Add `spring.threads.virtual.enabled=true`.
- **Requires sign-off before fix?** Y (Spring configuration changes)
- **Test to add/extend before fixing:** Full integration test suite run.

### ## [SEVERITY: Low] Legacy `*ngIf` Directive in `tts.component.html`
- **Source skill:** `typescript-pro`
- **File(s):** [tts.component.html](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/tts/tts.component.html) (Line 87)
- **Current behavior:** Uses legcay directive `*ngIf="authService.currentPlanType() !== 'ENTERPRISE'"`.
- **Risk if unfixed:** Inconsistency with modern Angular 17+ control-flow syntax.
- **Proposed minimal fix:** Replace with modern control flow: `@if (authService.currentPlanType() !== 'ENTERPRISE') { ... }`.
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Check `TtsComponent` template compilation.

### ## [SEVERITY: Medium] RxJS Subscription Leak in queryParams Observables
- **Source skill:** `typescript-pro`
- **File(s):**
    - [tts.component.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/tts/tts.component.ts) (Lines 86-100)
    - [stt-page.component.ts](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/frontend/src/app/features/stt/pages/stt-page/stt-page.component.ts) (Lines 644-656)
- **Current behavior:** Observables are subscribed to without any cleanup or `takeUntilDestroyed()`.
- **Risk if unfixed:** Memory leaks; multiple triggers when user toggles workspace views.
- **Proposed minimal fix:** Use `takeUntilDestroyed(this.destroyRef)` (Angular 16+).
- **Requires sign-off before fix?** N
- **Test to add/extend before fixing:** Verify routing behavior doesn't trigger redundant logic.

---

## Phase 4 — Security Hardening (`security-scanning-security-hardening`)

### ## [SEVERITY: Medium] User Consent Audit Trail under DPDP Act 2023
- **Source skill:** `security-scanning-security-hardening`
- **File(s):** [User.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/user/entity/User.java)
- **Current behavior:** Consent check is only validated on the frontend registration page, but user model does not record the consent status/timestamp.
- **Risk if unfixed:** Compliance liability under DPDP Act 2023 and IT Act 2000 (missing audit trace for data processing consent).
- **Proposed minimal fix:** Add a boolean `consentAccepted` and `LocalDateTime consentTimestamp` to the User entity and schema.
- **Requires sign-off before fix?** Y (requires DB schema migration)
- **Test to add/extend before fixing:** Assert consent fields are non-null on newly created users.

---

## Phase 5 — Payment Integration Review (`payment-integration`)

### ## [SEVERITY: Low] Unconfigured Razorpay Webhook Secret handling
- **Source skill:** `payment-integration`
- **File(s):** [WebhookService.java](file:///home/cyberbully/Documents/Desktop/git-projects/speakit/backend/src/main/java/com/speakit/billing/service/WebhookService.java)
- **Current behavior:** Logs error but continues validation, leading to signature errors.
- **Risk if unfixed:** Ambiguous error tracing when keys are missing.
- **Proposed minimal fix:** Fail-fast with a distinct exception if the secret is not populated.
- **Requires sign-off before fix?** Y (touches billing context)
- **Test to add/extend before fixing:** Ensure validation fails clearly when key is empty.
