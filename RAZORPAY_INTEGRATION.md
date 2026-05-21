# SpeakIT: Razorpay Payment Integration & Operational Guide

This document provides a comprehensive guide to the Razorpay payment integration implemented in the SpeakIT SaaS application.

---

## 1. Razorpay Account Setup

### Step-by-step Dashboard Setup
1.  **Account Creation**: Sign up at [Razorpay](https://razorpay.com/).
2.  **KYC Activation**: Complete the KYC process to accept live payments. For development, use **Test Mode**.
3.  **API Keys**:
    -   Go to **Settings** > **API Keys**.
    -   Generate **Key ID** and **Key Secret**. Save them securely.
4.  **Webhook Configuration**:
    -   Go to **Settings** > **Webhooks**.
    -   Add a new webhook URL (e.g., `https://api.yourdomain.com/api/v1/webhooks/razorpay`).
    -   Select events: `payment.captured`, `payment.failed`, `subscription.activated`.
    -   Set a **Webhook Secret**.

---

## 2. Backend Implementation (Spring Boot)

### Dependencies
Added `com.razorpay:razorpay-java:1.4.8` to `pom.xml`.

### Architecture
-   **`RazorpayConfig`**: Injects environment variables and provides a `RazorpayClient` bean.
-   **`RazorpayService`**: 
    -   `createOrder()`: Communicates with Razorpay API to create a unique Order ID.
    -   `verifyPayment()`: Uses Razorpay SDK's `Utils.verifyPaymentSignature` to prevent spoofing.
    -   `activateSubscription()`: Upgrades the user's `hasNaturalVoiceAccess` flag and creates a `Subscription` record.
-   **`WebhookService`**: 
    -   Verifies the webhook signature using the configured secret.
    -   Implements idempotency by tracking `event_id` in the `webhook_events` table.
-   **`PaymentController`**: Exposed endpoints for order creation and verification.
-   **`WebhookController`**: Secure endpoint for Razorpay callbacks.

### Configuration
Set the following environment variables:
-   `RAZORPAY_KEY_ID`
-   `RAZORPAY_KEY_SECRET`
-   `RAZORPAY_WEBHOOK_SECRET`

---

## 3. Frontend Implementation (Angular)

### Razorpay Service (`razorpay.service.ts`)
-   Dynamically loads the Razorpay script from `https://checkout.razorpay.com/v1/checkout.js`.
-   `initiatePayment()`: Orchestrates the flow from backend order creation to opening the Razorpay Checkout modal.
-   `verifyPayment()`: Calls the backend verification API after the user completes the payment in the modal.

### UI Components
-   **`PricingComponent`**: A responsive pricing page with Plan Cards (Basic, Pro, Enterprise).
-   **Navbar**: Updated to include a "Pricing" link and dynamic user badges showing the "Pro" status.

---

## 4. Database Schema

The implementation uses a standalone table approach for high auditability:
-   **`subscriptions`**: Tracks the user's current plan, status, and period.
-   **`payments`**: Records every transaction attempt, linking them to users and subscriptions.
-   **`webhook_events`**: An audit log for all received webhooks, ensuring idempotent processing.

---

## 5. Security Best Practices

1.  **Server-Side Verification**: Never trust the frontend's payment success callback. Always verify the signature on the backend using the `razorpay_signature`.
2.  **Webhook Verification**: Every webhook request is verified against the `RAZORPAY_WEBHOOK_SECRET`.
3.  **Secret Management**: Secrets are never hardcoded and are managed via system environment variables.
4.  **Idempotency**: We store `razorpay_order_id` and `event_id` to prevent double-billing or multiple activations for the same event.
5.  **Audit Logs**: All payment attempts (INITIATED, SUCCESS, FAILED) are logged in the `payments` table.

---

## 6. Local Development Guide

### Sandbox Testing
-   Use your **Test Key ID** and **Test Key Secret**.
-   Razorpay provides test card numbers (e.g., `4111 1111 1111 1111`).

### Webhook Debugging
Since webhooks need a public URL, use **ngrok**:
1.  Install ngrok: `npm install -g ngrok`.
2.  Expose your local backend: `ngrok http 8080`.
3.  Update the Webhook URL in Razorpay Dashboard to the ngrok URL (e.g., `https://xyz.ngrok.io/api/v1/webhooks/razorpay`).

---

## 7. Production Deployment Guide

1.  **Switch to Live Mode**: In the Razorpay dashboard, switch to Live Mode and generate new keys.
2.  **Update Environment Variables**: Set the Live Key ID, Secret, and Webhook Secret in your production environment (e.g., Render, AWS, Heroku).
3.  **HTTPS**: Ensure your backend uses HTTPS. Razorpay will not send webhooks to non-secure endpoints in Live Mode.
4.  **Monitoring**: Monitor the `webhook_events` table for any `FAILED` statuses to debug integration issues.

---

## 8. Go-Live Checklist

- [ ] Razorpay account activated and in Live Mode.
- [ ] Live API keys configured in environment variables.
- [ ] Webhook URL configured with Live Webhook Secret.
- [ ] HTTPS enabled on all endpoints.
- [ ] Log levels set appropriately (e.g., `INFO`).
- [ ] Test transaction performed in Live Mode using a real card (small amount).
- [ ] Webhook receipt verified in production logs.

---
*Created by SpeakIT Engineering Team - 2026*
