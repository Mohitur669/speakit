# SpeakIT v1.2 Security Audit & Remediation

This document outlines the security vulnerabilities identified during the v1.2 audit and the technical requirements for their resolution.

---

## 1. CRITICAL: Payment Logic IDOR / Logic Flaw
**Path:** `backend/src/main/java/com/tts/service/RazorpayService.java`
**Vulnerability:** The `verifyPayment` method takes a `User` object as an argument but does not verify that the `razorpay_order_id` being verified actually belongs to that user.
**Exploit Scenario:**
1.  User A creates an order (unpaid).
2.  User B (malicious) obtains User A's `razorpay_order_id`.
3.  User B performs a small valid transaction on their own account or uses a leaked signature to call `/verify` with User A's order ID.
4.  User B gets upgraded using User A's transaction metadata.
**Fix:** Add a check to ensure the `Payment` record fetched by `orderId` belongs to the `Principal` user.

## 2. HIGH: Polly Neural Authorization Bypass
**Path:** `backend/src/main/java/com/tts/service/PollyService.java`
**Vulnerability:** `getBestEngineForVoice` automatically returns `Engine.NEURAL` if the voice supports it, without checking if the user has a `PRO` plan.
**Exploit Scenario:** A `FREE` user can call `/synthesize` with a voice like "Joanna". The server will use the expensive NEURAL engine, incurring higher costs for the platform owner.
**Fix:** Pass the user's `PlanType` into the engine negotiation logic and fallback to `STANDARD` for non-premium users.

## 3. HIGH: Rate Limit Bypass via IP Spoofing
**Path:** `backend/src/main/java/com/tts/aspect/RateLimitAspect.java`
**Vulnerability:** The system relies on `HttpServletRequest.getRemoteAddr()`. When behind a proxy (like Render/Cloudflare), this might return the proxy IP or can be spoofed using `X-Forwarded-For` headers if the `server.forward-headers-strategy` is misconfigured.
**Exploit Scenario:** An attacker rotates `X-Forwarded-For` headers to obtain a fresh rate-limit bucket for every request.
**Fix:** Implement strict header validation and use a trusted proxy resolver.

## 4. MEDIUM: Information Disclosure in TTS Exceptions
**Path:** `backend/src/main/java/com/tts/controller/TtsController.java`
**Vulnerability:** The `synthesize` and `synthesizeStream` methods return `e.getMessage()` directly in the `ResponseEntity`.
**Exploit Scenario:** If a cloud service fails, the error might contain internal stack details, bucket names, or API structure information.
**Fix:** Use the standardized `ApiErrorResponse` and return a generic "Synthesis failed" message to the user while logging the detail internally.

## 5. MEDIUM: Potential Denial of Service (DOS)
**Paths:** 
- `UserRepository.java`: `findByPhoneNumberSuffix` uses `REPLACE` and `LIKE %suffix`, which prevents index usage (non-SARGable).
- `HistoryController.java`: `deleteSelected` accepts a `List<Long>` without size limits.
**Exploit Scenario:**
1.  Flood the `users` table and then trigger suffix searches to spike CPU/IO.
2.  Send a `DELETE` request with 100,000 IDs to crash the database connection pool.
**Fix:** 
- Index the normalized phone number column.
- Add a `@Size(max=100)` constraint to the deletion ID list.

---

### **Verification Status Report (v1.2 Final)**

| Vulnerability | Priority | Status | Fix Confirmation |
| :--- | :--- | :--- | :--- |
| **Payment Logic IDOR** | CRITICAL | **FIXED** | Ownership verified in `RazorpayService` via `Principal`. |
| **Polly Neural Auth Bypass** | HIGH | **FIXED** | `PollyService` strictly enforces fallback to STANDARD for non-premium users. |
| **Rate Limit IP Spoofing** | HIGH | **FIXED** | Hardened `FRAMEWORK` forwarding and explicit Tomcat proxy trust. |
| **TTS Info Disclosure** | MEDIUM | **FIXED** | `TtsController` returns generic messages; raw exceptions masked. |
| **Webhook Info Disclosure** | MEDIUM | **FIXED** | `WebhookController` sanitized to prevent internal system leak. |
| **History Deletion DOS** | MEDIUM | **FIXED** | `@Size(max = 100)` applied to batch deletion payloads. |
| **Contact Form Spam** | MEDIUM | **FIXED** | Intersection (IP+Email) limiting and Honeypot active. |

---

_Verification performed on 14/06/2026. All critical and high-priority risks resolved._
