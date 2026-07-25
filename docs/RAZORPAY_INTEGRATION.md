# SpeakIT: Razorpay Recurring Subscription & Payment Integration Guide

This document provides a comprehensive operational guide to the Razorpay Subscription integration in the SpeakIT SaaS application. The system has been upgraded from one-time orders to recurring monthly subscription plans.

---

## 1. Razorpay Account Setup for Subscriptions

To accept recurring payments, you must create **Subscription Plans** in your Razorpay Dashboard and register their corresponding Plan IDs in the SpeakIT system parameters.

### Step 1: Create Subscription Plans in Razorpay Dashboard
1.  Log in to your [Razorpay Dashboard](https://dashboard.razorpay.com/).
2.  Switch to **Test Mode** (for development/testing) or **Live Mode** (for production) in the top-right corner.
3.  Navigate to **Subscriptions** > **Plans** in the left sidebar.
4.  Click **+ Create Plan**.
5.  Configure the **Pro Plan**:
    -   **Plan Name**: `SpeakIT Pro Plan`
    -   **Billing Frequency**: `Monthly`
    -   **Billing Interval**: `1` (every 1 month)
    -   **Amount**: Enter your monthly price (e.g., `499` INR)
    -   **Description**: `SpeakIT Pro Plan Monthly Recurring Subscription`
    -   Click **Create Plan**.
6.  Once created, copy the generated **Plan ID** (starts with `plan_`, e.g., `plan_Nabc12345XYZ`).
7.  Configure the **Pro Plus Plan**:
    -   **Plan Name**: `SpeakIT Pro Plus Plan`
    -   **Billing Frequency**: `Monthly`
    -   **Billing Interval**: `1`
    -   **Amount**: Enter your monthly price (e.g., `1999` INR)
    -   **Description**: `SpeakIT Pro Plus Plan Monthly Recurring Subscription`
    -   Click **Create Plan**.
8.  Copy the generated Plan ID (starts with `plan_`, e.g., `plan_Ndef67890ABC`).

### Step 2: Configure System Parameters in Database
Insert or update the generated Razorpay Plan IDs in the SpeakIT `system_parameters` database table. Run the following SQL queries in your database shell or query console:

```sql
-- Update Pro Plan Razorpay ID
UPDATE system_parameters 
SET parameter_value = 'plan_YOUR_PRO_PLAN_ID_FROM_RAZORPAY' 
WHERE parameter_name = 'PRO_PLAN_ID_RAZORPAY';

-- Update Pro Plus Plan Razorpay ID
UPDATE system_parameters 
SET parameter_value = 'plan_YOUR_PRO_PLUS_PLAN_ID_FROM_RAZORPAY' 
WHERE parameter_name = 'PRO_PLUS_PLAN_ID_RAZORPAY';

-- (Optional) Update Default Subscription Cycles (e.g. 60 cycles = 5 years)
UPDATE system_parameters 
SET parameter_value = '60' 
WHERE parameter_name = 'RAZORPAY_SUBSCRIPTION_BILLING_CYCLES';
```

### Step 3: Configure Webhooks
Webhooks are critical to handle renewal charges, subscription activations, and remote cancellations.
1.  Navigate to **Settings** > **Webhooks** in the Razorpay Dashboard.
2.  Click **+ Add New Webhook**.
3.  Enter the Webhook URL:
    -   Local Dev (using ngrok): `https://YOUR_SUBDOMAIN.ngrok.io/api/v1/webhooks/razorpay`
    -   Production: `https://api.yourdomain.com/api/v1/webhooks/razorpay`
4.  Enter a secure **Webhook Secret** and save it as `RAZORPAY_WEBHOOK_SECRET` in your environment variables.
5.  Select the following **Active Events**:
    -   `subscription.activated` — Triggered when a subscription moves to an active state.
    -   `subscription.charged` — Triggered when a recurring billing charge is successfully processed (essential for first-time activation and subsequent renewals).
    -   `subscription.cancelled` — Triggered when a subscription is cancelled remotely or naturally expires.
6.  Click **Create Webhook**.

---

## 2. Integration Architecture

### Frontend Checkout Flow (Angular)
1.  **Initiate Checkout**: When the user clicks "Upgrade" on the UI, `razorpay.service.ts` sends a POST request to `/api/v1/payments/create-order` with the selected plan type.
2.  **Create Subscription**: The backend calls Razorpay to create a subscription with the matching `plan_id` and returns the `subscriptionId`.
3.  **Checkout Modal**: The frontend calls Razorpay Checkout by passing `subscription_id` instead of `order_id` in the configuration options.
4.  **Verification**: After successful card authorization, Razorpay returns a `razorpay_payment_id`, `razorpay_subscription_id`, and `razorpay_signature`. The frontend sends these parameters to `/api/v1/payments/verify` for instant activation.

### Backend Execution & Verification (Spring Boot)
-   **Plan Configuration**: Plan IDs are fetched dynamically from System Parameters (`PRO_PLAN_ID_RAZORPAY` and `PRO_PLUS_PLAN_ID_RAZORPAY`).
-   **Manual Signature Check**: Because subscription signature verification matches `payment_id + "|" + subscription_id`, signature validation uses a secure local HMAC-SHA256 generation function verifying against the `razorpay_signature` to guarantee authentication.
-   **Security/IDOR check**: The user verifying the subscription must own the corresponding payment record.
-   **Idempotency**: All webhook requests are processed transactionally and tracked in `webhook_events` to ensure exactly-once execution.

---

## 3. Environment Variables Configuration

Ensure the following variables are present in your backend's `.env` or application config:
```properties
# Razorpay Credentials
razorpay.key.id=rzp_test_YOUR_KEY_ID
razorpay.key.secret=YOUR_KEY_SECRET
razorpay.webhook.secret=YOUR_WEBHOOK_SECRET
```

---

## 4. Local Development & Testing Guide

1.  **Use Sandbox Details**: Always test with Sandbox credentials first.
2.  **Use Test Cards**: In Test Mode, complete checkouts using the official [Razorpay Test Cards](https://razorpay.com/docs/payments/payments/test-card-details/).
3.  **Use ngrok**: Run `ngrok http 8080` to route webhook callbacks to your local machine.

---

*SpeakIT Payment & Operations Engineering — 2026*
