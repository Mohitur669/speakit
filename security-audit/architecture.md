# SpeakIT Security Architecture & Trust Model

## 1. Application Overview
**SpeakIT** is an AI-powered voice generation and transcription SaaS application.
- **Frontend**: Standalone Angular 21 Single Page Application styled with Tailwind CSS, utilizing Signals and Supabase auth client helper libraries.
- **Backend**: Spring Boot 3.5.11 (Java 21) REST API handling user profiles, TTS (Amazon Polly, ElevenLabs, Sarvam AI), STT, system parameters, payments (Razorpay), and email notifications.
- **Database**: PostgreSQL (hosted on Supabase) storing user registry, active subscription state, transactional history, and dynamic configuration keys.

---

## 2. Tech Stack & Environment
- **Framework**: Spring Boot 3.5.11 / Spring Security 6.x
- **Token Handling**: JWT (jjwt 0.12.6) for stateless authentication.
- **Database**: PostgreSQL 16
- **External Integrations**:
  - AWS Polly (TTS synthesis)
  - AWS SES (Email transactions)
  - ElevenLabs API (Neural/Natural speech engine)
  - Sarvam AI API (Indian language voices)
  - Razorpay (Subscription billing and webhook synchronization)
- **Rate Limiting**: Bucket4j in-memory token bucket implementation (`ConcurrentHashMap`).

---

## 3. Trust Boundaries & Access Control
- **Entry Points**:
  - Unauthenticated REST endpoints: `/api/auth/login`, `/api/auth/register`, `/api/auth/verify-email`, `/api/auth/forgot-password`, `/api/auth/reset-password`, `/api/auth/ping`, `/api/contact`, `/api/v1/webhooks/**`, `/api/system-parameters/**`.
  - Authenticated REST endpoints: Protected via `JwtAuthenticationFilter` or `ApiKeyAuthenticationFilter` checking header signatures against the user registry or hashed developer credentials.
- **Authorization**: Role-based access (FREE, PRO, PRO_PLUS, ENTERPRISE tiers) configured via system parameter thresholds (e.g., daily character counts, max file sizes for STT uploads) checked dynamic-style on each resource request.
- **Developer API Gateway**: Exposed via `/api/v1/tts/generate` protected by `X-API-Key` headers, verified against hashed records in `developer_api_keys`, rate-limited based on dynamic plan quotas, and checking specific API permission scopes.

---

## 4. Input Surfaces
1. **HTTP JSON Payloads**: REST endpoints mapping request payloads directly to DTOs.
2. **Multipart File Uploads**: Speech-To-Text (STT) audio file ingestion.
3. **Webhooks**: Unauthenticated endpoint `/api/v1/webhooks/razorpay` validating requests via Razorpay header signature.
4. **WebSocket Connection**: Exposed via `/ws/**` with `setAllowedOriginPatterns("*")` mapping to backend messaging.
