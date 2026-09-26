# SpeakIT Application Security Assessment Report

## Executive Summary
This report details the findings of a comprehensive security assessment conducted on the SpeakIT repository (`github.com/Mohitur669/speakit`). The application demonstrates a strong foundational architecture utilizing Spring Boot 3, Angular 17, and AWS Polly. The implementation of JWT session invalidation, Bucket4j rate limiting, and an AWS Budget Kill Switch shows a proactive approach to security and FinOps. 

However, several critical and high-severity vulnerabilities were discovered. The most severe issues involve **Payment Verification Replay Attacks** allowing users to indefinitely extend premium subscriptions for free, and **Rate Limit IP Spoofing**, which defeats the primary defense against AWS cost exhaustion. Immediate remediation of the critical findings is required prior to production deployment.

### Overall Security Score: 62/100
### Risk Level: CRITICAL

### Findings Summary
*   **Critical Findings:** 2
*   **High Findings:** 3
*   **Medium Findings:** 2
*   **Low Findings:** 0

---

## Detailed Findings

### 1. Payment Verification Replay Attack leading to Infinite Subscription
**Severity:** Critical
**Location:** `backend/src/main/java/com/tts/service/RazorpayService.java` (Line ~83, `verifyPayment` method)

**Description:**
The payment verification logic properly validates the HMAC-SHA256 signature from Razorpay. However, it fails to verify whether the `Payment` object has *already* been processed and marked as `PaymentStatus.SUCCESS`. Because `activateSubscription` blindly adds `LocalDateTime.now().plusMonths(1)` to the subscription period, an attacker can replay a legitimately signed, successful payload indefinitely to extend their Pro plan.

**Attack Scenario:**
1. An attacker purchases a 1-month Pro plan.
2. The attacker intercepts the HTTP POST request to `/api/v1/payments/verify`.
3. The attacker writes a script to replay this exact JSON payload (containing the valid `razorpay_order_id`, `razorpay_payment_id`, and `razorpay_signature`) every 29 days.
4. The server successfully validates the signature and extends the subscription by another month indefinitely without charging the attacker.

**Proof of Concept:**
```bash
# Replay the exact payload captured from browser dev tools
curl -X POST https://api.speakit.com/api/v1/payments/verify \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"razorpayOrderId":"order_xyz", "razorpayPaymentId":"pay_xyz", "razorpaySignature":"valid_sig_abc123"}'
```

**Impact:**
Massive revenue loss. Attackers can gain permanent access to expensive AWS Polly Neural voices, leading to uncontrollable AWS API costs.

**Remediation:**
Check the payment status before processing the verification and reject already processed orders.

**Code Example:**
```java
Payment payment = paymentRepository.findByRazorpayOrderId(request.getRazorpayOrderId())
        .orElseThrow(() -> new RuntimeException("Payment record not found"));

if (payment.getStatus() == PaymentStatus.SUCCESS) {
    log.warn("Replay attempt detected for order: {}", request.getRazorpayOrderId());
    return true; // Already processed, do not extend subscription again
}

// ... proceed with setting status and activating subscription
```

---

### 2. Rate Limiting Bypass via IP Spoofing
**Severity:** Critical
**Location:** `backend/src/main/java/com/tts/aspect/RateLimitAspect.java` (Line ~94, `extractRealIp` method)

**Description:**
The `extractRealIp` method parses the `CF-Connecting-IP` and `X-Forwarded-For` headers to determine the client's IP address. The application unconditionally trusts these headers without verifying if the request actually originated from a trusted proxy (e.g., Cloudflare). If the application is accessible directly via its Render URL (bypassing Cloudflare), an attacker can supply arbitrary IP addresses.

**Attack Scenario:**
An attacker scripts a bot to abuse the `/api/tts/synthesize` endpoint. To bypass the Bucket4j limit, the script generates a random IP address for every request and injects it into the headers.

**Proof of Concept:**
```bash
# Attacker hits the Render URL directly, bypassing Cloudflare
curl -X POST https://text-to-speech-java-backend.onrender.com/api/tts/synthesize \
  -H "CF-Connecting-IP: 203.0.113.1" \
  -d '{"text": "Spam"}'
```

**Impact:**
Complete bypass of the rate-limiting mechanism. This enables unbounded requests to AWS Polly, leading to massive cost spikes, triggering the AWS Budget Kill Switch, and causing a Denial of Service (DoS) for all legitimate users.

**Remediation:**
Rely on Spring Boot's native `server.forward-headers-strategy=FRAMEWORK` and restrict direct access to the Render URL using Cloudflare Authenticated Origin Pulls, OR explicitly validate that the proxy headers come from trusted Cloudflare IP ranges.

**Code Example:**
```java
// Remove manual header parsing and rely on Spring's configured RemoteAddr
private String extractRealIp(HttpServletRequest request) {
    return request.getRemoteAddr(); 
}
```
*(Ensure `application.properties` contains `server.forward-headers-strategy=FRAMEWORK`)*

---

### 3. Unauthenticated Information Disclosure via System Parameters
**Severity:** High
**Location:** `backend/src/main/java/com/tts/controller/SystemParameterController.java` & `SecurityConfig.java`

**Description:**
In `SecurityConfig.java`, the endpoint `.requestMatchers("/api/system-parameters/**").permitAll()` is fully exposed to unauthenticated users. The `SystemParameterController` allows users to query any system parameter from the database by name. While currently only prices and limits are seeded, storing any sensitive data (like API keys) in this table in the future will result in immediate compromise.

**Attack Scenario:**
An attacker calls `/api/system-parameters/bulk?names=ELEVENLABS_API_KEY,RAZORPAY_SECRET` or iterates through common configuration names to extract secrets.

**Impact:**
Potential exposure of highly sensitive credentials leading to complete infrastructure compromise.

**Remediation:**
Secure the endpoint to require `ROLE_ADMIN`, or strictly whitelist which parameter keys can be read publicly (e.g., `SYSTEM_STATUS`, `FREE_PLAN_SYNTHESIZE_LIMIT`).

---

### 4. Insecure Default Webhook Secret leading to Signature Bypass
**Severity:** High
**Location:** `backend/src/main/resources/application.properties` & `WebhookService.java`

**Description:**
The property `razorpay.webhook.secret=${RAZORPAY_WEBHOOK_SECRET:placeholder_webhook_secret}` defines a hardcoded fallback string. If a production environment neglects to define this ENV var, attackers can easily sign forged webhook payloads (like `payment.captured`) using `placeholder_webhook_secret` and arbitrarily grant themselves `PRO` or `ENTERPRISE` plans without paying.

**Impact:**
Account privilege escalation and revenue theft.

**Remediation:**
Remove the default fallback for production secrets. The application should fail to start if critical secrets are missing.

**Code Example:**
```properties
# Remove the :placeholder_webhook_secret fallback
razorpay.webhook.secret=${RAZORPAY_WEBHOOK_SECRET}
```

---

### 5. User Enumeration and Denial of Service via Unrated Endpoints
**Severity:** High
**Location:** `backend/src/main/java/com/tts/controller/AuthController.java`

**Description:**
The endpoints `/check-username`, `/check-email`, and `/check-phone` lack the `@RateLimited(action = RateLimitAction.PUBLIC)` annotation. An attacker can brute-force the user database without restriction.

**Attack Scenario:**
An attacker scripts a loop to check millions of email addresses against `/api/auth/check-email?email=target@example.com` to enumerate registered users, simultaneously overwhelming the PostgreSQL database.

**Impact:**
Privacy violation (identifying registered users) and Database DoS.

**Remediation:**
Apply the `@RateLimited` annotation to all public endpoints.

**Code Example:**
```java
@RateLimited(action = RateLimitAction.PUBLIC)
@GetMapping("/check-email")
public ResponseEntity<Boolean> checkEmail(@RequestParam String email) { ... }
```

---

### 6. JWT Token Exposure in WebSocket URL
**Severity:** Medium
**Location:** `backend/src/main/java/com/tts/config/WebSocketConfig.java` (Line 52)

**Description:**
The WebSocket authentication mechanism accepts the JWT via query parameters (`ws://.../ws/logout?token=eyJ...`). Query parameters are often logged in plaintext by reverse proxies, WAFs, and browser histories, leading to token leakage.

**Remediation:**
Pass the JWT token via the `Sec-WebSocket-Protocol` subprotocol header, or immediately exchange a short-lived, single-use ticket for the WebSocket connection instead of the long-lived JWT.

---

### 7. Potential XSS via Angular bypassSecurityTrustHtml
**Severity:** Medium
**Location:** `frontend/src/app/features/marketing/blog/blog-detail/blog-detail.component.ts` (Line 118)

**Description:**
The Angular frontend uses `this.sanitizer.bypassSecurityTrustHtml(this.post.content)` to render blog content. While the current data source is static and trusted (`blog.data.ts`), this is a fragile pattern. If SpeakIT later migrates to a dynamic CMS, this bypass will create a severe Stored XSS vulnerability.

**Remediation:**
Use a dedicated Markdown/HTML sanitization library (like `DOMPurify`) before bypassing Angular's security, or strictly rely on Angular's default HTML sanitization by binding directly to `[innerHTML]="post.content"`.

---

## Security Architecture Assessment

*   **Authentication Architecture:** **Good**. The dual-layer JWT + Session Versioning system effectively handles global logout without requiring a Redis cache. 
*   **Authorization Architecture:** **Needs Improvement**. Critical endpoints (like system parameters) are left publicly accessible. A proper `@PreAuthorize` layer is missing on configuration routes.
*   **API Security:** **Poor**. The reliance on client-provided headers for IP tracking defeats the Bucket4j rate limiter.
*   **Data Protection:** **Good**. Jsoup sanitization on TTS inputs effectively neutralizes prompt injection and XSS attempts against the processing engine.
*   **DevSecOps Maturity:** **Excellent**. Implementing AWS Budgets tied to a Lambda IAM kill switch is an outstanding defense-in-depth mechanism for FinOps security.

---

## Quick Wins (Fixes within 1 Day)
1. **1 Hour:** Apply `@RateLimited(action = RateLimitAction.PUBLIC)` to the `check-*` auth endpoints.
2. **1 Hour:** Add the `payment.getStatus() == PaymentStatus.SUCCESS` check to `RazorpayService.java` to stop the replay attack.
3. **1 Hour:** Remove the `placeholder_webhook_secret` fallback from `application.properties`.
4. **1 Day:** Refactor `RateLimitAspect.java` to stop manually parsing proxy headers. Enforce Cloudflare routing to the Render backend via Authenticated Origin Pulls to secure the IP chain.

---

## Final Verdict

**Production Readiness Score:** 45/100
**Deployment Recommendation:** **DO NOT DEPLOY** until the Critical and High findings are resolved.

**Must Fix Before Launch:**
1. The Payment Replay Attack.
2. The Rate Limiter IP Spoofing bypass.
3. Securing the System Parameters endpoint.

**Recommended Security Roadmap:**
Once the immediate vulnerabilities are patched, the team should focus on migrating WebSocket authentication to use ticketing systems rather than URL parameters, and implementing strict WAF rules on Cloudflare to drop requests bypassing the `mohitur.com` domain.
