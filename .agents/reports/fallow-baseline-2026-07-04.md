── Policy ─────────────────────────────────────

● Unused component inputs (2)
  src/app/features/tts/components/tts-input/tts-input.component.ts (2)
    :68 loading is declared but read nowhere in this component (remove it or use it)
    :69 voiceId is declared but read nowhere in this component (remove it or use it)
  An Angular @Input() / signal input() declaration read nowhere inside its own component (remove it or use it) — https://docs.fallow.tools/explanations/dead-code#unused-component-inputs

● Unused component outputs (2)
  src/app/features/tts/components/tts-input/tts-input.component.ts
    :72 convert is declared but emitted nowhere in this component (remove it or emit it)
  src/app/features/user/profile-settings/components/profile-form/profile-form.component.ts
    :118 selectedCountryChange is declared but emitted nowhere in this component (remove it or emit it)
  An Angular @Output() / signal output() declaration emitted nowhere inside its own component (remove it or emit it) — https://docs.fallow.tools/explanations/dead-code#unused-component-outputs

● Duplicates (6 clone groups)

     14 lines  2 instances  dup:6c382a59
    src/app/features/auth/verify-email/verify-email.component.ts:126-138
    src/app/features/user/profile-settings/components/verify-profile/verify-profile.component.ts:174-187

     13 lines  2 instances  dup:f14bfcc9
    src/app/features/auth/verify-email/verify-email.component.ts:146-158
    src/app/features/user/profile-settings/components/verify-profile/verify-profile.component.ts:217-229

     12 lines  2 instances  dup:52c87ee3
    src/app/features/stt/components/transcript-card/transcript-card.component.ts:252-263
    src/app/features/stt/pages/stt-page/stt-page.component.ts:560-571

     11 lines  2 instances  dup:212fa1ca
    src/app/features/auth/reset-password/reset-password.component.ts:149-159
    src/app/features/auth/verify-email/verify-email.component.ts:106-116

      8 lines  2 instances  dup:697319a6
    src/app/features/stt/services/stt.service.ts:22-29
    src/app/features/stt/services/stt.service.ts:41-48

      5 lines  2 instances  dup:747fc13b
    src/app/features/stt/pages/stt-page/stt-page.component.ts:759-763
    src/app/features/stt/pages/stt-page/stt-page.component.ts:767-771

  Identical code blocks detected via suffix-array analysis — https://docs.fallow.tools/explanations/duplication#clone-groups

● Clone families (1 with multiple groups)

  2 groups, 27 lines across src/app/features/auth/verify-email/verify-email.component.ts, src/app/features/user/profile-settings/components/verify-profile/verify-profile.component.ts
    → Extract shared function (13 lines) from verify-email.component.ts, verify-profile.component.ts
    → Extract shared function (14 lines) from verify-email.component.ts, verify-profile.component.ts

  Groups of related clones across the same files — https://docs.fallow.tools/explanations/duplication#clone-families

■ Metrics: 12,467 LOC · dead files 0.0% · dead exports 0.0% · avg cyclomatic 2.5 · p90 cyclomatic 5 · maintainability 92.3 (good) · 0 churn hotspots (since 6 months)

  Function size: 83% low · 8% medium · 4% high · 4% very high  (1-15 / 16-30 / 31-60 / >60 LOC)
  Parameters:    98% low · 1% medium · 0% high · 0% very high  (0-2 / 3-4 / 5-6 / >=7 params)

● Large functions (10 shown, 24 total)
  src/app/shared/components/navbar/navbar.component.ts
    :22 <template>  533 lines
  src/app/features/stt/pages/stt-page/stt-page.component.ts
    :22 <template>  484 lines
  src/app/features/user/chat-history/chat-history.component.ts
    :16 <template>  349 lines
  src/app/features/tts/components/voice-selector/voice-selector.component.ts
    :15 <template>  328 lines
  src/app/features/tts/tts.component.html
    :66 <template>  251 lines
  src/app/features/user/payment-history/payment-history.component.ts
    :8 <template>  230 lines
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :17 <template>  196 lines
  src/app/features/auth/signup/signup.component.ts
    :24 <template>  191 lines
  src/app/features/user/profile-settings/components/password-form/password-form.component.ts
    :6 <template>  181 lines
  src/app/features/marketing/blog/blog-list/blog-list.component.ts
    :8 <template>  133 lines
  Functions exceeding 60 lines of code (very high risk): https://docs.fallow.tools/explanations/health#unit-size
  use --top 24 to see all

● High complexity findings (44)
  CRAP scores are estimated from export references; run `fallow health --coverage <coverage-final.json>` for exact scores.
  src/app/shared/components/navbar/navbar.component.ts
    :626 <component> (component rollup) CRITICAL
          42 cyclomatic   74 cognitive  571 lines
         rolled up: 11cyc 18cog on `navbar.component.handleKeyDown` + 31cyc 56cog on src/app/shared/components/navbar/navbar.component.ts
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :303 <component> (component rollup) HIGH
          37 cyclomatic   39 cognitive  212 lines
         rolled up: 19cyc 18cog on `transcript-card.component.getLanguageName` + 18cyc 21cog on src/app/features/stt/components/transcript-card/transcript-card.component.ts
  src/app/features/stt/pages/stt-page/stt-page.component.ts
    :583 <component> (component rollup) CRITICAL
          34 cyclomatic   63 cognitive  505 lines
         rolled up: 6cyc 5cog on `stt-page.component.updateNarratorOptions` + 28cyc 58cog on src/app/features/stt/pages/stt-page/stt-page.component.ts
  src/app/features/stt/models/sarvam-voices.config.ts
    :57 normalizeLanguageCode CRITICAL
          33 cyclomatic   23 cognitive   16 lines
         1122.0 CRAP
  src/app/shared/components/navbar/navbar.component.ts
    :22 <template> (template complexity) CRITICAL
          31 cyclomatic   56 cognitive  533 lines
         238.6 CRAP
  src/app/features/stt/pages/stt-page/stt-page.component.ts
    :22 <template> (template complexity) CRITICAL
          28 cyclomatic   58 cognitive  484 lines
         812.0 CRAP
  src/app/features/auth/signup/signup.component.ts
    :302 <component> (component rollup)
          28 cyclomatic   18 cognitive  232 lines
         rolled up: 10cyc 5cog on `signup.component.onSubmit` + 18cyc 13cog on src/app/features/auth/signup/signup.component.ts
  src/app/features/tts/components/voice-selector/voice-selector.component.ts
    :15 <template> (template complexity) CRITICAL
          26 cyclomatic   52 cognitive  328 lines
         172.0 CRAP
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :303 getLanguageName CRITICAL
          19 cyclomatic   18 cognitive   16 lines
         380.0 CRAP
    :17 <template> (template complexity) CRITICAL
          18 cyclomatic   21 cognitive  196 lines
         342.0 CRAP
  src/app/features/auth/signup/signup.component.ts
    :24 <template> (template complexity) CRITICAL
          18 cyclomatic   13 cognitive  191 lines
         342.0 CRAP
  src/app/features/user/profile-settings/profile-settings.component.ts
    :165 <component> (component rollup)
          18 cyclomatic   16 cognitive  147 lines
         rolled up: 7cyc 7cog on `profile-settings.component.ngOnInit` + 11cyc 9cog on src/app/features/user/profile-settings/profile-settings.component.ts
  src/app/features/user/chat-history/chat-history.component.ts
    :16 <template> (template complexity) CRITICAL
          13 cyclomatic   18 cognitive  349 lines
         182.0 CRAP
  src/app/features/user/payment-history/payment-history.component.ts
    :8 <template> (template complexity) CRITICAL
          12 cyclomatic   16 cognitive  230 lines
         156.0 CRAP
  src/app/features/user/profile-settings/components/password-form/password-form.component.ts
    :6 <template> (template complexity) CRITICAL
          12 cyclomatic   17 cognitive  181 lines
         156.0 CRAP
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :268 ngOnInit CRITICAL
          12 cyclomatic   12 cognitive   34 lines
         156.0 CRAP
    :388 error CRITICAL
          12 cyclomatic   13 cognitive   21 lines
         156.0 CRAP
  src/app/features/tts/tts.component.html
    :66 <template> (template complexity)
          12 cyclomatic   10 cognitive  251 lines
          43.1 CRAP  (inherited from src/app/features/tts/tts.component.ts)
  src/app/shared/components/otp-input/otp-input.component.ts
    :76 onKeyDown
          12 cyclomatic   14 cognitive   32 lines
          43.1 CRAP
  src/app/shared/components/navbar/navbar.component.ts
    :626 handleKeyDown
          11 cyclomatic   18 cognitive   38 lines
          37.1 CRAP
  src/app/features/user/profile-settings/profile-settings.component.ts
    :14 <template> (template complexity) CRITICAL
          11 cyclomatic    9 cognitive  106 lines
         132.0 CRAP
  src/app/shared/directives/only-numbers.directive.ts
    :9 onKeyDown
          11 cyclomatic    8 cognitive   28 lines
          37.1 CRAP
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :430 speak CRITICAL
          10 cyclomatic   13 cognitive   78 lines
         110.0 CRAP
  src/app/features/user/profile-settings/components/verify-profile/verify-profile.component.ts
    :11 <template> (template complexity) CRITICAL
          10 cyclomatic   11 cognitive  109 lines
         110.0 CRAP
  src/app/features/auth/signup/signup.component.ts
    :302 onSubmit CRITICAL
          10 cyclomatic    5 cognitive   41 lines
         110.0 CRAP
  src/app/features/auth/verify-email/verify-email.component.ts
    :10 <template> (template complexity) HIGH
           9 cyclomatic    9 cognitive   81 lines
          90.0 CRAP
  src/app/features/auth/reset-password/reset-password.component.ts
    :11 <template> (template complexity) HIGH
           9 cyclomatic    4 cognitive  115 lines
          90.0 CRAP
  src/app/features/auth/login/login.component.ts
    :216 error HIGH
           7 cyclomatic    6 cognitive    9 lines
          56.0 CRAP
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :519 fallbackSpeak HIGH
           7 cyclomatic   11 cognitive   22 lines
          56.0 CRAP
  src/app/features/auth/signup/components/password-field-group/password-field-group.component.ts
    :6 <template> (template complexity) HIGH
           7 cyclomatic    6 cognitive  116 lines
          56.0 CRAP
  src/app/features/user/profile-settings/profile-settings.component.ts
    :165 ngOnInit HIGH
           7 cyclomatic    7 cognitive   41 lines
          56.0 CRAP
  src/app/features/stt/components/transcript-card/transcript-card.component.ts
    :364 translateText
           6 cyclomatic    4 cognitive   47 lines
          42.0 CRAP
  src/app/features/stt/pages/stt-page/stt-page.component.ts
    :583 updateNarratorOptions
           6 cyclomatic    5 cognitive   21 lines
          42.0 CRAP
  src/app/shared/components/password-policy-modal/password-policy-modal.component.ts
    :5 <template> (template complexity)
           6 cyclomatic    9 cognitive   85 lines
          42.0 CRAP
  src/app/features/stt/components/audio-recorder/audio-recorder.component.ts
    :290 cleanupStream
           6 cyclomatic    5 cognitive   15 lines
          42.0 CRAP
  src/app/shared/components/custom-dropdown/custom-dropdown.component.ts
    :132 checkDirection
           6 cyclomatic    6 cognitive   27 lines
          42.0 CRAP
  src/app/features/stt/components/upload-area/upload-area.component.ts
    :4 <template> (template complexity)
           6 cyclomatic    4 cognitive   59 lines
          42.0 CRAP
  src/app/features/stt/pages/stt-page/stt-page.component.ts
    :774 seekAudio
           5 cyclomatic    6 cognitive   11 lines
          30.0 CRAP
    :845 error
           5 cyclomatic    4 cognitive   14 lines
          30.0 CRAP
  src/app/features/stt/components/audio-recorder/audio-recorder.component.ts
    :152 <arrow>
           5 cyclomatic    3 cognitive   13 lines
          30.0 CRAP
    :4 <template> (template complexity)
           5 cyclomatic    8 cognitive   87 lines
          30.0 CRAP
  src/app/shared/components/custom-dropdown/custom-dropdown.component.ts
    :17 <template> (template complexity)
           5 cyclomatic    4 cognitive   59 lines
          30.0 CRAP
  src/app/features/marketing/contact/contact.component.ts
    :302 ngOnInit
           5 cyclomatic    6 cognitive   24 lines
          30.0 CRAP
  src/app/shared/components/confirm-modal/confirm-modal.component.ts
    :4 <template> (template complexity)
           5 cyclomatic    4 cognitive   69 lines
          30.0 CRAP
  Functions and synthetic template or component entries exceeding cyclomatic, cognitive, or CRAP thresholds (https://docs.fallow.tools/explanations/health#complexity-metrics)
  To suppress HTML templates: <!-- fallow-ignore-file complexity -->
  To suppress inline templates: // fallow-ignore-next-line complexity (above @Component)
  To suppress a <component> rollup: suppress the worst class method (// fallow-ignore-next-line complexity above it hides both)
  To suppress: // fallow-ignore-next-line complexity

● File health scores (57 files) · sorted by triage concern

   85.6    src/app/features/stt/models/sarvam-voices.config.ts  risk
             87 LOC    2 fan-in    0 fan-out    0% dead  0.48 density  >999 risk

   85.8    src/app/features/stt/pages/stt-page/stt-page.component.ts  risk
            871 LOC    1 fan-in   13 fan-out    0% dead  0.12 density  812.0 risk

   85.6    src/app/features/stt/components/transcript-card/transcript-card.component.ts  risk
            552 LOC    1 fan-in    6 fan-out    0% dead  0.22 density  380.0 risk

   88.1    src/app/features/auth/signup/signup.component.ts  risk
            344 LOC    1 fan-in    7 fan-out    0% dead  0.12 density  342.0 risk

   92.9    src/app/shared/components/navbar/navbar.component.ts  risk
            712 LOC   19 fan-in    2 fan-out    0% dead  0.09 density  238.6 risk

   90.1    src/app/features/user/chat-history/chat-history.component.ts  risk
            525 LOC    1 fan-in    5 fan-out    0% dead  0.09 density  182.0 risk

   91.1    src/app/features/tts/components/voice-selector/voice-selector.component.ts  risk
            559 LOC    1 fan-in    2 fan-out    0% dead  0.15 density  172.0 risk

   92.7    src/app/features/user/payment-history/payment-history.component.ts  risk
            287 LOC    1 fan-in    3 fan-out    0% dead  0.06 density  156.0 risk

   95.1    src/app/features/user/profile-settings/components/password-form/password-form.component.ts  risk
            219 LOC    1 fan-in    1 fan-out    0% dead  0.07 density  156.0 risk

   87.9    src/app/features/user/profile-settings/profile-settings.component.ts  risk
            255 LOC    1 fan-in    8 fan-out    0% dead  0.11 density  132.0 risk

  ... and 47 more files (--format json for full list)

  Sorted by triage concern: the larger of low-MI concern and CRAP risk. The risk / structure tag marks which one placed each file. MI reflects complexity, coupling, and dead code; risk reflects untested complexity (CRAP) and can diverge from MI. Risk: low <15, moderate 15-30, high >=30. CRAP estimated from export references (85% direct, 40% indirect, 0% untested). Run `fallow health --coverage <coverage-final.json>` for exact scores. https://docs.fallow.tools/explanations/health#file-health-scores

● Refactoring targets (4)
  4 high
    score = quick-win ROI (higher = better) · pri = absolute priority

    9.4  pri:28.1    src/app/core/auth/auth.service.ts
         high impact · effort:high · confidence:medium  Split high-impact file (311 LOC), 15 dependents amplify every change
         importers: src/app/core/guards/auth.guard.ts (AuthService); src/app/core/interceptors/auth.interceptor.ts (AuthService); src/app/core/services/razorpay.service.ts (AuthService); src/app/features/auth/forgot-password/forgot-password.component.ts (AuthService); src/app/features/auth/login/login.component.ts (AuthService)

    6.4  pri:19.2    src/app/shared/components/navbar/navbar.component.ts
         complexity · effort:high · confidence:high  Extract <template> (cognitive: 56) in 712-LOC file into smaller functions
         importers: src/app/features/auth/forgot-password/forgot-password.component.ts (NavbarComponent); src/app/features/auth/login/login.component.ts (NavbarComponent); src/app/features/auth/reset-password/reset-password.component.ts (NavbarComponent); src/app/features/auth/signup/signup.component.ts (NavbarComponent); src/app/features/auth/verify-email/verify-email.component.ts (NavbarComponent)

    4.9  pri:14.6    src/app/features/stt/pages/stt-page/stt-page.component.ts
         complexity · effort:high · confidence:high  Extract <template> (cognitive: 58) in 871-LOC file into smaller functions
         importers: src/app/app.config.ts (SttPageComponent)
         clones: src/app/features/stt/components/transcript-card/transcript-card.component.ts:252-263 dup:52c87ee3; src/app/features/stt/pages/stt-page/stt-page.component.ts:759-763 dup:747fc13b; src/app/features/stt/pages/stt-page/stt-page.component.ts:767-771 dup:747fc13b

    2.3  pri:7.0    src/app/features/tts/components/voice-selector/voice-selector.component.ts
         complexity · effort:high · confidence:high  Extract <template> (cognitive: 52) in 559-LOC file into smaller functions
         importers: src/app/features/tts/tts.component.ts (VoiceSelectorComponent)

  Prioritized refactoring recommendations based on complexity, churn, and coupling signals: https://docs.fallow.tools/explanations/health#refactoring-targets

