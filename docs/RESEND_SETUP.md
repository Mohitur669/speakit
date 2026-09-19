# Resend Email Integration Setup Guide

This document provides a detailed, step-by-step guide to setting up and configuring the Resend API for delivering One-Time Password (OTP) emails in the SpeakIT backend.

## Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Step 1: Create a Resend Account & Add Domain](#step-1-create-a-resend-account--add-domain)
3. [Step 2: Verify Your Domain (DNS Setup)](#step-2-verify-your-domain-dns-setup)
4. [Step 3: Generate an API Key](#step-3-generate-an-api-key)
5. [Step 4: Configure Local Environment](#step-4-configure-local-environment)
6. [Step 5: Configure Production / Staging](#step-5-configure-production--staging)
7. [Step 6: Testing the Integration](#step-6-testing-the-integration)
8. [Rollback Procedure (Emergency)](#rollback-procedure-emergency)

---

## 1. Prerequisites
- Access to the domain's DNS provider (e.g., Cloudflare, Route53, GoDaddy) to add TXT and MX records.
- A registered [Resend](https://resend.com) account.

---

## Step 1: Create a Resend Account & Add Domain
1. Go to [Resend.com](https://resend.com) and log in or sign up.
2. In the left-hand navigation menu, click on **Domains**.
3. Click the **Add Domain** button.
4. Enter the domain you plan to send emails from (e.g., `speakit.com`).
5. Choose a region closest to your primary user base (e.g., `us-east-1` or `eu-west-1`).
6. Click **Add**.

---

## Step 2: Verify Your Domain (DNS Setup)
To ensure high deliverability and avoid spam folders, you must prove you own the domain by setting up SPF and DKIM records.

1. After adding your domain, Resend will display a set of DNS records (usually 1 MX record and 2-3 TXT records).
2. Open a new tab and log in to your DNS provider (e.g., Cloudflare).
3. Navigate to the **DNS Management** page for your domain.
4. Add each record exactly as specified by Resend:
   - **Type:** (MX or TXT)
   - **Name/Host:** (e.g., `bounces`, `_dmarc`, or `default._domainkey`)
   - **Value/Target:** (Copy the exact string from Resend)
   - **TTL:** Auto or 3600
5. Once all records are added to your DNS provider, return to the Resend dashboard and click **Verify DNS Records**.
   > **Note:** DNS propagation can take anywhere from a few minutes to 24 hours. Resend will display a "Verified" badge once it successfully detects the records.

---

## Step 3: Generate an API Key
1. In the Resend dashboard, navigate to **API Keys** in the left sidebar.
2. Click **Create API Key**.
3. Name your key (e.g., `SpeakIT-Production-OTP` or `SpeakIT-Local`).
4. **Permissions:** Set to `Sending access`.
5. **Domain:** Restrict this key to the specific domain you just verified (recommended for security).
6. Click **Add**.
7. **CRITICAL:** Copy the generated API key immediately and store it securely (e.g., in a password manager). You will not be able to view it again.

---

## Step 4: Configure Local Environment
1. In the root of the `backend` directory, open your `.env` file (create one from `.env.example` if it doesn't exist).
2. Add the following variables:
   ```env
   # Resend OTP Configuration
   RESEND_API_KEY=re_your_api_key_here
   RESEND_FROM_ADDRESS=noreply@yourdomain.com
   OTP_PROVIDER=resend
   ```
3. Restart your local Spring Boot application.

> **Important for Local Testing:** If your domain is **not yet verified**, Resend operates in a sandbox mode. You can ONLY send emails to the email address associated with your Resend account. 

---

## Step 5: Configure Production / Staging
You must add the exact same environment variables to your hosting provider (e.g., Render, AWS ECS, Heroku).

1. Go to your provider's dashboard.
2. Find the **Environment Variables** or **Secrets** section for the SpeakIT backend service.
3. Add the keys:
   - `RESEND_API_KEY` (Your production key)
   - `RESEND_FROM_ADDRESS` (e.g., `security@speakit.com`)
   - `OTP_PROVIDER` (Set to `resend`)
4. Trigger a new deployment for the changes to take effect.

---

## Step 6: Testing the Integration
1. Ensure your Spring Boot backend is running.
2. Navigate to the frontend or use an API tool like Postman.
3. Trigger an action that requires an OTP (e.g., **Sign Up** or **Forgot Password**).
4. Verify the response is successful (HTTP 200).
5. Check your inbox for the OTP email.
6. Check the backend logs for a success message: 
   `Successfully sent OTP email via Resend API to: us**@domain.com`

---

## Rollback Procedure (Emergency)
If Resend experiences an outage, or if your domain gets blacklisted, the application is designed to instantly fall back to the legacy AWS SES / SMTP email sender.

To execute a rollback **without deploying any new code**:
1. Go to your deployment environment (or local `.env`).
2. Change the `OTP_PROVIDER` variable:
   ```env
   OTP_PROVIDER=legacy
   ```
3. Restart the backend service.
4. OTP emails will now immediately resume using the `EmailService` legacy logic.
