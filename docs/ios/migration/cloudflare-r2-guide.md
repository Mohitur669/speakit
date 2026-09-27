# Cloudflare R2 Setup & Avatar Storage Architecture Guide

This document is the authoritative engineering guide for setting up and configuring **Cloudflare R2 Object Storage** (S3-compatible API) with CDN delivery, audit tracking, and configurable rate limiting for user profile avatars on the SpeakIT platform.

---

## 1. Overview & Architecture

### Why Cloudflare R2?
- **Zero Egress Fees:** Traditional AWS S3 charges $0.09/GB for outgoing internet bandwidth. Cloudflare R2 has zero data transfer fees, dramatically reducing operational costs for high-traffic avatar delivery.
- **S3-Compatible API:** Fully compatible with AWS SDK v2 (`software.amazon.awssdk:s3`), requiring no proprietary client SDKs.
- **Edge CDN Performance:** Seamless integration with Cloudflare's global edge network (300+ PoPs worldwide) with sub-30ms avatar latency.
- **Domain-Agnostic Object Keys:** Avatars are stored by relative `storage_key` (`avatars/u_{userId}_{timestamp}.jpg`), enabling zero-downtime CDN domain migrations and environment portability.
- **Cache-Busting Design:** Unique timestamped keys allow aggressive browser and CDN edge caching (`Cache-Control: public, max-age=31536000, immutable`).

### End-to-End Pipeline Diagram

```
┌─────────────────────────────────┐
│        iOS App (SwiftUI)        │
│  - PhotosPicker (PhotosUI)      │
│  - Center Square Crop 1:1       │
│  - Downsample to 512x512        │
│  - Compress JPEG 0.80           │
│  - Size: ~80 KB - 180 KB        │
└────────────────┬────────────────┘
                 │ Multipart Form POST /api/v1/users/avatar
                 ▼
┌─────────────────────────────────┐
│    Spring Boot Backend (Java)   │
│  - Validate MIME & 2MB cap      │
│  - Enforce Daily Limit (UTC)    │
│  - AvatarStorageService (R2/S3) │
│  - Insert user_avatar_history   │
│  - Update users.avatar_url      │
│  - Return minimal AvatarResponse│
└────────────────┬────────────────┘
                 │ S3-compatible PUT
                 ▼
┌─────────────────────────────────┐       Edge CDN Cache
│      Cloudflare R2 Bucket       │ ─────────────────────────► Global Users / iOS App
│     (e.g. speakit-avatars)      │   https://cdn.speakit.com  (NSCache + Disk Cache)
└─────────────────────────────────┘
```

---

## 2. Step 1: Create the Cloudflare R2 Bucket

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. In the left navigation sidebar, select **R2 Object Storage**.
3. If you haven't enabled R2 yet, click **Get Started** and activate R2 on your Cloudflare account.
4. Click **Create bucket**.
5. Bucket settings:
   - **Bucket name:** `speakit-avatars` (or your preferred production bucket name, e.g., `speakit-prod-avatars`).
   - **Location hint:** Select `Automatic` or choose the region closest to your primary database and backend compute (e.g., `APAC` or `WNAM`).
6. Click **Create Bucket**.

---

## 3. Step 2: Generate S3-Compatible API Credentials

Cloudflare R2 provides AWS S3-compatible Access Keys for backend applications.

1. Navigate to **R2 Object Storage** in the Cloudflare Dashboard.
2. Under the Account details panel on the right, click **Manage R2 API Tokens**.
3. Click **Create API token**.
4. Configure the token:
   - **Token name:** `speakit-backend-uploader`
   - **Permissions:** Select **Object Read & Write**.
   - **Bucket scope:** Choose **Specific bucket** and select `speakit-avatars`.
   - **TTL:** Leave as `Forever` (or set according to your organization's key rotation policy).
5. Click **Create API Token**.
6. **Save the generated credentials securely** (Cloudflare displays them only once):
   - **Account ID:** Found in the dashboard URL or R2 overview (e.g., `a1b2c3d4e5f67890abcdef1234567890`).
   - **Access Key ID:** (e.g., `1234567890abcdef1234567890abcdef`).
   - **Secret Access Key:** (e.g., `fedcba0987654321fedcba0987654321...`).
   - **Endpoint URL:** `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`.

---

## 4. Step 3: Configure CORS Policy

To ensure both web applications (Angular) and native clients can access avatars and perform HEAD/GET requests:

1. In the Cloudflare Dashboard, open the `speakit-avatars` bucket.
2. Click the **Settings** tab.
3. Scroll down to the **CORS Policy** section and click **Add CORS rule** (or edit existing).
4. Paste the following JSON CORS configuration:

```json
[
  {
    "AllowedOrigins": [
      "https://speakit.com",
      "https://*.speakit.com",
      "http://localhost:4200",
      "http://localhost:8080"
    ],
    "AllowedMethods": [
      "GET",
      "HEAD",
      "PUT",
      "DELETE"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag",
      "Content-Type",
      "Cache-Control"
    ],
    "MaxAgeSeconds": 86400
  }
]
```
5. Click **Save**.

---

## 5. Step 4: Connect a Custom Domain or Public CDN URL

By default, R2 buckets are private. To allow fast image downloads, attach a public domain or development URL.

### Option A: Production Custom Domain (Recommended)
1. On the `speakit-avatars` bucket page, click **Settings**.
2. Scroll to **Public Access** and find **Custom Domains**.
3. Click **Connect Domain**.
4. Enter your custom subdomain (e.g., `cdn.speakit.com` or `avatars.speakit.com`).
5. Click **Continue** and confirm the DNS record creation (Cloudflare will automatically manage TLS and CNAME routing).
6. Your public avatar URL will be:
   ```
   https://cdn.speakit.com/avatars/...
   ```

### Option B: R2 Dev URL (For Staging & Local Testing)
1. In the **Public Access** section of your bucket Settings, find **R2.dev subdomain**.
2. Click **Allow Access**.
3. A public development URL will be assigned (e.g., `https://pub-abc123456789.r2.dev`).
4. Note: `r2.dev` has a Cloudflare rate limit of 300 requests/minute, ideal for development but not high-scale production.

---

## 6. Step 5: Backend Configuration & Environment Variables

### A. Environment Variables (`backend/.env` or Coolify / Render / Docker)

Add the following environment variables to your deployment environment:

```env
# Cloudflare R2 / S3-compatible Object Storage for Avatars
R2_ACCOUNT_ID=your_cloudflare_account_id_here
R2_ACCESS_KEY_ID=your_r2_access_key_id_here
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key_here
R2_BUCKET_NAME=speakit-avatars
R2_PUBLIC_URL=https://cdn.speakit.com

# Daily Avatar Update Quota (default: 2 changes per user per UTC day)
AVATAR_DAILY_LIMIT=2
```

> **Resilient Fallback Mode:**  
> If `R2_ACCOUNT_ID` or credentials are left empty (e.g. during offline local development), SpeakIT's `AvatarStorageService` automatically falls back to saving files locally under `uploads/avatars/` served via Spring's `WebMvcConfig`. The application will NEVER crash or fail to boot if R2 credentials are missing.

### B. Spring Boot Properties (`application.properties`)

```properties
# Cloudflare R2 / S3-compatible Object Storage for Avatars
cloudflare.r2.account-id=${R2_ACCOUNT_ID:}
cloudflare.r2.access-key-id=${R2_ACCESS_KEY_ID:}
cloudflare.r2.secret-access-key=${R2_SECRET_ACCESS_KEY:}
cloudflare.r2.bucket-name=${R2_BUCKET_NAME:}
cloudflare.r2.public-url=${R2_PUBLIC_URL:}

# Avatar Daily Rate Limiting (Configurable via AVATAR_DAILY_LIMIT)
avatar.daily-limit=${AVATAR_DAILY_LIMIT:2}
```

### C. Maven Dependency (`backend/pom.xml`)

```xml
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>s3</artifactId>
    <version>2.42.3</version>
    <scope>compile</scope>
</dependency>
```

---

## 7. Step 6: Database Architecture & Quota Tracking

To maintain a high-performance primary `users` table and adhere to UGC compliance standards, avatar state and metrics are structured into two complementary layers:

### A. Core `users` Table (Fast Profile Lookups)
Retains only the active avatar URL reference:
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(512);
```

### B. `user_avatar_history` Table (Audit & Quota Calculation)
Stores an immutable log of avatar operations, file sizes, MIME types, and storage keys:

```sql
CREATE SEQUENCE IF NOT EXISTS user_avatar_history_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS user_avatar_history (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    avatar_url VARCHAR(512),
    storage_key VARCHAR(255),
    action VARCHAR(20) NOT NULL,          -- 'UPLOAD' or 'DELETE'
    file_size_bytes BIGINT,
    mime_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    version BIGINT DEFAULT 0,
    CONSTRAINT fk_avatar_history_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_avatar_history_user_date 
ON user_avatar_history(user_id, action, created_at);
```

### C. Automatic UTC Daily Quota Calculation
Daily change limits are calculated dynamically directly from the audit log without requiring cron jobs or state synchronization:

```sql
SELECT COUNT(*) 
FROM user_avatar_history 
WHERE user_id = :userId 
  AND action = 'UPLOAD' 
  AND created_at >= CURRENT_DATE AT TIME ZONE 'UTC';
```
- At `00:00:00 UTC`, the quota resets automatically.
- Deletions (`action = 'DELETE'`) are logged for auditing but do not consume the user's upload quota.

---

## 8. Step 7: Minimal API Contracts (Zero Data Leakage)

Avatar endpoints return dedicated, minimal DTOs (`AvatarResponse`) instead of whole user records, minimizing mobile bandwidth and preventing sensitive auth/billing data exposure.

### A. Upload Avatar (`POST /api/v1/users/avatar`)

```bash
# Upload a JPEG/PNG/WebP avatar with Bearer Token
curl -X POST "http://localhost:8080/api/v1/users/avatar" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/test-photo.jpg;type=image/jpeg"
```

**Minimal Response (200 OK):**
```json
{
  "avatarUrl": "https://cdn.speakit.com/avatars/u_102_1727438400000.jpg",
  "storageKey": "avatars/u_102_1727438400000.jpg",
  "action": "UPLOAD",
  "dailyLimit": 2,
  "remainingChangesToday": 1,
  "updatedAt": "2026-09-27T09:30:00"
}
```

**Error Response When Daily Limit Exceeded (400 Bad Request):**
```json
{
  "error": "Daily avatar change limit reached. You can only change your profile picture 2 times per day. Resets at 00:00 UTC."
}
```

### B. Delete Avatar (`DELETE /api/v1/users/avatar`)

```bash
curl -X DELETE "http://localhost:8080/api/v1/users/avatar" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Minimal Response (200 OK):**
```json
{
  "avatarUrl": null,
  "storageKey": null,
  "action": "DELETE",
  "dailyLimit": 2,
  "remainingChangesToday": 1,
  "updatedAt": "2026-09-27T09:35:00"
}
```

---

## 9. Step 8: iOS Implementation Standards

The iOS client adheres to the 6 core profile avatar standards:

| Standard | Implementation in SpeakIT |
|---|---|
| **1. Visual Hierarchy & Fallbacks** | 3-tier fallback in `SpeakITAvatarView.swift`: Custom Photo $\rightarrow$ Deterministic Monogram Gradient $\rightarrow$ SF Symbol fallback with 1pt subtle border. |
| **2. PhotosPicker (PhotosUI)** | Out-of-process picker with zero permission alerts (`matching: .images`, single selection). |
| **3. Client-Side Preprocessing** | `ImageProcessor.swift`: Center 1:1 square crop, downsamples to 512x512 px Retina resolution, compresses to JPEG 0.80 (~80–180 KB). |
| **4. Two-Tier Caching** | `AvatarCacheManager.swift`: In-memory `NSCache` for 0ms ProMotion 120Hz scrolling + On-disk cache in `<Caches>/UserAvatars` for offline relaunch. |
| **5. Minimal Response Handling** | `AvatarResponse.swift` decoded directly; updates local `User` via `updatingAvatarUrl(_:)` without needing full user refetch. |
| **6. Interactive UX & Badges** | Elevated bottom-trailing camera badge, Action Sheet with "Choose from Library" and "Remove Current Photo". |
| **7. Accessibility** | Full VoiceOver accessibility label with dynamic user name and edit hint. |

---

## 10. Security Best Practices & Maintenance

1. **Least-Privilege Scoping:** Never use account-wide admin tokens for the application. Scope the token strictly to Object Read & Write on `speakit-avatars`.
2. **Strict Server-Side Validation:** The backend enforces a strict 2MB ceiling and validates MIME types (`image/jpeg`, `image/png`, `image/webp`).
3. **Automatic Old Avatar Cleanup:** When a user uploads a new avatar or deletes their account, `AvatarStorageService` automatically deletes the superseded object from R2 to prevent dangling storage costs.
4. **Rate Limiting:** Both avatar upload and deletion endpoints are shielded by Spring Boot Bucket4j rate limiting (`@RateLimited(action = RateLimitAction.PUBLIC)`).
5. **Audit History & Compliance:** All avatar changes are permanently cataloged in `user_avatar_history` with storage keys, timestamps, and file sizes for trust and safety traceability.
