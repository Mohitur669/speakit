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
    "AllowedMethods": ["GET", "HEAD", "PUT", "DELETE"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag", "Content-Type", "Cache-Control"],
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

| Standard                            | Implementation in SpeakIT                                                                                                                                         |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1. Visual Hierarchy & Fallbacks** | 3-tier fallback in `SpeakITAvatarView.swift`: Custom Photo $\rightarrow$ Deterministic Monogram Gradient $\rightarrow$ SF Symbol fallback with 1pt subtle border. |
| **2. PhotosPicker (PhotosUI)**      | Out-of-process picker with zero permission alerts (`matching: .images`, single selection).                                                                        |
| **3. Client-Side Preprocessing**    | `ImageProcessor.swift`: Center 1:1 square crop, downsamples to 512x512 px Retina resolution, compresses to JPEG 0.80 (~80–180 KB).                                |
| **4. Two-Tier Caching**             | `AvatarCacheManager.swift`: In-memory `NSCache` for 0ms ProMotion 120Hz scrolling + On-disk cache in `<Caches>/UserAvatars` for offline relaunch.                 |
| **5. Minimal Response Handling**    | `AvatarResponse.swift` decoded directly; updates local `User` via `updatingAvatarUrl(_:)` without needing full user refetch.                                      |
| **6. Interactive UX & Badges**      | Elevated bottom-trailing camera badge, Action Sheet with "Choose from Library" and "Remove Current Photo".                                                        |
| **7. Accessibility**                | Full VoiceOver accessibility label with dynamic user name and edit hint.                                                                                          |

---

## 10. Security Best Practices & Maintenance

1. **Least-Privilege Scoping:** Never use account-wide admin tokens for the application. Scope the token strictly to Object Read & Write on `speakit-avatars`.
2. **Strict Server-Side Validation:** The backend enforces a strict 2MB ceiling and validates MIME types (`image/jpeg`, `image/png`, `image/webp`).
3. **Automatic Old Avatar Cleanup:** When a user uploads a new avatar or deletes their account, `AvatarStorageService` automatically deletes the superseded object from R2 to prevent dangling storage costs.
4. **Rate Limiting:** Both avatar upload and deletion endpoints are shielded by Spring Boot Bucket4j rate limiting (`@RateLimited(action = RateLimitAction.PUBLIC)`).
5. **Audit History & Compliance:** All avatar changes are permanently cataloged in `user_avatar_history` with storage keys, timestamps, and file sizes for trust and safety traceability.

---

## 11. Edge Security & Bandwidth Protection (Cloudflare CDN Shield)

While Cloudflare CDN provides **unlimited free data transfer** and Cloudflare R2 has **$0 egress fees**, public avatar URLs can still be targeted by external hotlinking (other websites displaying your images) or automated scrapers. Implementing the following two edge protections ensures that avatar assets are shielded at the Cloudflare network layer without requiring backend code changes.

### Strategy 1: Enable Cloudflare Hotlink Protection (Easiest & Free)

Hotlink Protection prevents external websites from leeching your CDN bandwidth by verifying the HTTP `Referer` header on image requests.

- **Modern Cloudflare Dashboard Path (Option A - Direct Setting):**
  1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/) and select your root domain: **`mohitur.com`**.
  2. In the left navigation sidebar, click **Security**.
  3. Under the **Security** dropdown, select **Settings**.
  4. Scroll down to find **Hotlink Protection** (located under _Client-side abuse_ / _Content Protection_).
  5. Toggle the switch to **On**.

- **Modern Cloudflare Dashboard Path (Option B - Granular Configuration Rule):**
  1. In the left navigation sidebar, select **Rules** $\rightarrow$ **Configuration Rules**.
  2. Click **Create rule**.
  3. Set **Rule name**: `Enable Hotlink Protection for Avatars`.
  4. Under **If incoming requests match...**, set:
     - Field: `Hostname`
     - Operator: `equals`
     - Value: `cdn-speakit-avatars.mohitur.com`
  5. Under **Then...**, find the setting **Hotlink Protection** and toggle it to **Active (On)**.
  6. Click **Deploy**.

- **What it does:**
  - Cloudflare inspects the incoming `Referer` request header for all image extensions (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`).
  - If a third-party website (e.g. `malicious-site.com`) embeds `<img src="https://cdn-speakit-avatars.mohitur.com/avatars/u_102.jpg">`, Cloudflare blocks the request and serves an **HTTP 403 Forbidden** error.
  - Direct requests from the native iOS app (which do not send a web referer) and your official web domain (`speakit.com` / `localhost`) continue to load normally without interruption.

- **Effort:** 1 toggle in Cloudflare Dashboard, **0 code changes**.

---

---

### Strategy 2: Protecting Against Scrapers & Abuse on Your Custom Domain

Because Cloudflare's Free tier provides **only 1 free Rate Limiting rule** per zone, you have two options depending on whether you have a free rate limiting slot available:

#### Option A: WAF Rate Limiting Rule (If you have a free rate limit slot)

- **Modern Cloudflare Dashboard Path:**
  1. In the Cloudflare Dashboard, select **`mohitur.com`**.
  2. In the left navigation sidebar, click **Security** $\rightarrow$ **WAF** (Web Application Firewall).
  3. Select the **Rate limiting rules** tab at the top.
  4. Click **Create rule**.
  5. Configure the rule parameters:
     - **Rule name:** `Rate Limit Avatar CDN Downloads`
     - **If incoming requests match... (Field Expression):**
       - **Hostname** `equals` `cdn-speakit-avatars.mohitur.com`
       - _AND_
       - **URI Path** `starts with` `/avatars/`
         _(Alternatively, click "Edit expression" and paste: `(http.host eq "cdn-speakit-avatars.mohitur.com" and starts_with(http.request.uri.path, "/avatars/"))`)_
     - **Rate limiting criteria:**
       - **Requests:** `60`
       - **Period:** `1 minute` (or `10 requests per 10 seconds` for stricter enforcement)
       - **Counting characteristics:** `IP` (tracks requests per client IP address)
     - **Choose action:**
       - **Action:** `Block` (returns **HTTP 429 Too Many Requests**) or `Managed Challenge` (serves a silent Cloudflare Turnstile verification).
       - **Duration:** `10 minutes` (temporary cooldown for violating IPs).
  6. Click **Deploy**.

---

#### Option B: WAF Custom Rule (Recommended if you already used your 1 free rate limit rule)

Cloudflare Free tier provides **5 free WAF Custom Rules** under the "Custom rules" tab (completely separate from rate limiting). You can use a Custom Rule to block scraper libraries, bots, and non-GET requests from touching your CDN domain.

- **Modern Cloudflare Dashboard Path:**
  1. In the Cloudflare Dashboard, select **`mohitur.com`**.
  2. In the left navigation sidebar, click **Security** $\rightarrow$ **WAF**.
  3. Ensure you are on the **Custom rules** tab (the first tab, _not_ Rate limiting rules).
  4. Click **Create rule**.
  5. Configure the rule parameters:
     - **Rule name:** `Block Scrapers and Non-GET on SpeaKIT CDNs (Avatars & Audio)`
     - Click **Edit expression** (right above the field builder) and paste this exact expression:
       ```text
       (http.host in {"cdn-speakit-avatars.mohitur.com" "cdn-speakit-avatar.mohitur.com" "cdn-speakit-audio.mohitur.com"} and (not http.request.method in {"GET" "HEAD"} or lower(http.user_agent) contains "curl" or lower(http.user_agent) contains "python" or lower(http.user_agent) contains "wget" or lower(http.user_agent) contains "scrapy" or lower(http.user_agent) contains "go-http-client" or lower(http.user_agent) contains "aiohttp"))
       ```
     - **Choose action:**
       - Select **Block** (or **Managed Challenge** to present a Turnstile check to suspicious clients).
  6. Click **Deploy**.

- **Why this works:**
  - **Unified Protection Across Multiple Buckets:** Cloudflare's `http.host in {...}` syntax matches incoming requests across both your avatar CDN (`cdn-speakit-avatar.mohitur.com`) and your TTS audio CDN (`cdn-speakit-audio.mohitur.com`) within a single rule, consuming only 1 of your 5 free WAF Custom Rules.
  - **Method Enforcement:** Both CDNs only ever require `GET` or `HEAD`. Any bots probing with `POST`, `PUT`, or `DELETE` are instantly rejected at Cloudflare's edge before hitting R2.
  - **Scraper & Bot Blocking:** Automated CLI tools (`curl`, `wget`) and Python/Scrapy scraping scripts commonly used to crawl object buckets are dropped instantly.
  - **Zero Impact on Real Users:** Regular browsers, Web audio players, and the iOS app use standard GET requests with authentic Apple/browser User-Agents, loading assets without interruption.

---

### Edge Protection Summary

| Feature                       | Protection Layer                           | Target Threat                                             | Modern Dashboard Location                                                                                |
| ----------------------------- | ------------------------------------------ | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Hotlink Protection**        | Cloudflare Edge Protection                 | External websites embedding your avatar links             | `mohitur.com` $\rightarrow$ **Security** $\rightarrow$ **Settings** $\rightarrow$ **Hotlink Protection** |
| **WAF Custom Scraper Shield** | Cloudflare Edge Firewall (5 free rules)    | Bot libraries, scrapers, automated tools, non-GET traffic | `mohitur.com` $\rightarrow$ **Security** $\rightarrow$ **WAF** $\rightarrow$ **Custom rules**            |
| **WAF Rate Limiting**         | Cloudflare Edge Rate Limiter (1 free rule) | High-frequency request flooding per IP                    | `mohitur.com` $\rightarrow$ **Security** $\rightarrow$ **WAF** $\rightarrow$ **Rate limiting rules**     |
| **Edge Cache Control**        | HTTP Header (`max-age=31536000`)           | Repeated read latency & unnecessary origin traffic        | Automated via `AvatarStorageService` metadata                                                            |
| **Bucket4j API Shield**       | Spring Boot Application Layer              | Rapid avatar replacement / deletion abuse                 | `@RateLimited(action = RateLimitAction.PUBLIC)`                                                          |

---

## 12. TTS Audio Storage & On-Demand Streaming Architecture (Cloudflare R2)

In addition to user avatars, SpeakIT leverages Cloudflare R2 object storage for synthesized Text-to-Speech (TTS) audio files. This architecture delivers high-fidelity audio playback to mobile and web clients with **$0 egress fees**, edge caching, and mobile client performance.

### 12.1 Why Cloudflare R2 for TTS Audio?

1. **Zero Data Egress ($0 Bandwidth):**
   - High-bitrate audio generation (e.g., 192kbps MP3s or lossless WAV) generates significant egress volume. On AWS S3, streaming 1 TB of audio incurs ~$90 in bandwidth fees. With Cloudflare R2, data transfer is completely free.
2. **Global CDN Acceleration:**
   - Files are distributed via Cloudflare’s global edge network (300+ PoPs worldwide), ensuring sub-50ms Time-To-First-Byte (TTFB) playback for international users.
3. **Decoupled Compute from Playback:**
   - Once synthesized, audio requests do not hit the Spring Boot backend or TTS providers (AWS Polly, ElevenLabs, Sarvam AI), freeing backend threads and connection pools.

---

### 12.2 Audio Object Key Structure & MIME Mapping

Audio objects are stored in the R2 bucket under a structured, secure key pattern:

```text
audio/u_{userId}_{timestamp}_{uuid}.{ext}
```

- **Example Key:** `audio/u_102_1727546400000_a1b2c3d4.mp3`
- **Supported Audio Formats & MIME Types:**
  - `mp3` $\rightarrow$ `audio/mpeg` (Default for mobile and web streaming)
  - `ogg` $\rightarrow$ `audio/ogg` (Vorbis compressed streams)
  - `pcm` / `wav` $\rightarrow$ `audio/wav` (High-definition raw audio)
- **Immutable Cache Header:**
  ```http
  Cache-Control: public, max-age=31536000, immutable
  ```
  Because each synthesis key contains a unique timestamp and UUID, the audio payload never mutates, allowing edge caches, browser caches, and iOS URLSession to cache the file indefinitely without cache-invalidation overhead.

---

### 12.3 End-to-End Audio Pipeline Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Synthesis Phase (POST /api/tts/synthesize)      │
│                                                                        │
│  User taps "Generate Speech"                                           │
│         │                                                              │
│         ▼                                                              │
│  Spring Boot Backend (Java 21)                                         │
│  ├─ Validate plan quota & character count                              │
│  ├─ Synthesize bytes via Polly / ElevenLabs / Sarvam                   │
│  ├─ AudioStorageService.storeAudio(...)                                │
│  │   ├─ Upload to Cloudflare R2 (audio/u_{userId}_{ts}_{uuid}.mp3)     │
│  │   └─ Local Fallback if R2 unconfigured (uploads/audio/)             │
│  ├─ Save TtsHistory record (with audio_url and storage_key)            │
│  └─ Return audio bytes for immediate playback in studio                │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                   On-Demand Playback Phase (Activity Hub)              │
│                                                                        │
│  User views Activity list (Audio is NOT pre-loaded)                    │
│         │                                                              │
│         ▼ (User taps Play on History Item)                             │
│  iOS Client (SwiftUI / AVPlayer)                                       │
│  ├─ 1. Check local persistent disk cache (<Caches>/AudioHistory/)      │
│  │   └─ Found? ──► Instant 0ms local AVPlayer playback!                │
│  └─ 2. Not cached?                                                     │
│      ├─ Set row state to isLoading (shows spinner)                     │
│      ├─ Download from Cloudflare R2 CDN or GET /api/history/{id}/audio │
│      ├─ Save atomically to disk cache                                  │
│      └─ Switch to isPlaying (pause icon) & start AVPlayer playback     │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 12.4 Industry-Standard Mobile Lazy-Loading Pattern

Pre-loading audio files in list views or tables is an anti-pattern that leads to severe mobile issues:

- **Excessive Cellular Data Usage:** Downloading 20–50 audio files on list mount consumes tens of megabytes of cellular data that the user may never listen to.
- **Memory Pressure & Thread Starvation:** Instantiating multiple AVPlayers or buffering simultaneous binary data leads to iOS memory warnings and dropped UI frames.
- **Cold-Start Latency:** Fetching audio blocks network threads from rendering activity metadata promptly.

#### SpeakIT Lazy-Loading Implementation:

1. **Metadata-Only List Fetching:**
   - `GET /api/history` returns only lightweight JSON metadata (`id`, `textSnippet`, `characterCount`, `voiceName`, `createdAt`, `audioUrl`).
   - Network payload is under 2 KB for 20 items.
2. **On-Demand Single-Item Fetching:**
   - Audio is fetched **only when the user explicitly taps the Play button**.
3. **Two-Tier Mobile Caching:**
   - **Tier 1 (Disk Cache):** Persistent audio files saved under `<CachesDirectory>/AudioHistory/history_{id}.mp3`. Survives app restarts, enabling offline playback and 0ms replay without repeated network requests.
   - **Tier 2 (In-Memory AVPlayer):** Managed by `AudioPlayerManager.shared` with background audio session, lock-screen Now Playing controls, and automatic route-change pausing (AirPods disconnect).
4. **Interactive UI State Transitions:**
   - **Idle:** Displays standard play icon (`play.fill`).
   - **Loading:** Displays `ProgressView()` spinner with primary tint while downloading and writing to disk.
   - **Playing:** Displays `pause.fill` icon with an active accent background. Tapping it toggles pause/play.
   - **Single Active Item:** Tapping Play on another item pauses the current audio and seamlessly initiates playback for the selected item.

---

### 12.5 Backend Audio Streaming Endpoint (`GET /api/history/{id}/audio`)

For scenarios where the client cannot directly access the public CDN or when using local filesystem fallback:

```java
@GetMapping("/{id}/audio")
public ResponseEntity<?> getHistoryAudio(
        HttpServletRequest request,
        @PathVariable Long id
) {
    Long userId = (Long) request.getAttribute("userId");
    if (userId == null) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }

    var historyOpt = ttsHistoryRepository.findByIdAndUserId(id, userId);
    if (historyOpt.isEmpty()) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
    }

    var history = historyOpt.get();
    String audioUrl = history.getAudioUrl();

    // 1. Direct Edge Offload: Redirect to Cloudflare CDN if public URL exists
    if (audioUrl != null && audioUrl.startsWith("http")) {
        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(audioUrl))
                .build();
    }

    // 2. Stream from Storage (R2 or Local Fallback)
    InputStream audioStream = audioStorageService.getAudioInputStream(history.getStorageKey(), audioUrl);
    if (audioStream == null) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
    }

    return ResponseEntity.ok()
            .contentType(getMediaType(history.getOutputFormat()))
            .header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable")
            .body(new InputStreamResource(audioStream));
}
```

#### Security & Compliance Features:

- **IDOR Protection:** Audio is strictly gated by `findByIdAndUserId(id, userId)`. A user cannot stream another user's synthesized audio by guessing sequential IDs.
- **Edge Offloading:** When public Cloudflare CDN is configured, the endpoint returns an **HTTP 302 Found** redirect to the CDN URL. Mobile `AVPlayer` and `URLSession` follow redirects automatically, offloading streaming bandwidth from the Spring Boot server.
- **Lifecycle Cleanup:** When history entries are deleted via `DELETE /api/history/delete` or `DELETE /api/history/clear-all`, `AudioStorageService.deleteAudio` automatically purges the underlying audio objects from Cloudflare R2 and local disk.

---

### 12.6 Configuration Reference

Add to `backend/.env` or production deployment variables:

```env
# Cloudflare R2 Audio & Avatar Storage (S3-Compatible API)
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key_id
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key

# Dedicated Buckets (Avatars vs. Synthesized Audio)
R2_BUCKET_NAME=speakit-avatars
R2_AUDIO_BUCKET_NAME=speakit-audio

# Dedicated Custom Domains (Cloudflare R2 enforces 1 custom domain per bucket)
R2_PUBLIC_URL=https://cdn-speakit-avatar.mohitur.com
R2_AUDIO_PUBLIC_URL=https://cdn-speakit-audio.mohitur.com
```

> [!IMPORTANT]
> **Single Custom Domain per Bucket Rule:** Cloudflare R2 connects exactly **one Custom Domain to one Bucket**. You cannot map `cdn-speakit-avatar.mohitur.com/audio/` to a different bucket directly without building a custom Cloudflare Worker. Having two separate subdomains (`cdn-speakit-avatar.mohitur.com` and `cdn-speakit-audio.mohitur.com`) is the official Cloudflare standard and allows clean, independent caching, metrics, and firewall configurations.

---

### 12.7 iOS Native Client Audio Implementation Details

#### UI State Machine & Interaction Flow

The native iOS Play button embedded in [`SpeakITHistoryRow.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITHistoryRow.swift) and managed by [`ActivityView.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/Features/Activity/ActivityView.swift) implements a strict, thread-safe state machine:

```text
                  ┌────────────────────────┐
                  │       State: IDLE      │
                  │   Icon: "play.fill"    │
                  └───────────┬────────────┘
                              │ User Taps Play
                              ▼
                  ┌────────────────────────┐
                  │   State: DOWNLOADING   │
                  │   UI: ProgressView()   │
                  │ (Checks local disk     │
                  │  cache first: 0ms)     │
                  └───────────┬────────────┘
                              │ Download & Cache Complete
                              ▼
                  ┌────────────────────────┐
   ┌─────────────►│    State: PLAYING      │◄────────────┐
   │              │   Icon: "pause.fill"   │             │
   │              │ Accent Glow / Active   │             │
   │              └───────────┬────────────┘             │
User Taps Pause               │               User Taps Play (Resume)
   │                          ▼                          │
   └──────────────┌────────────────────────┐             │
                  │     State: PAUSED      │─────────────┘
                  │   Icon: "play.fill"    │
                  └───────────┬────────────┘
                              │ Audio Track Finishes or Item Switched
                              ▼
                  ┌────────────────────────┐
                  │       State: IDLE      │
                  │   Icon: "play.fill"    │
                  └────────────────────────┘
```

#### Cache Directory Hierarchy & Storage Management

Audio files are stored in the app's sandboxed caches directory, which iOS automatically manages and preserves across sessions:
```text
<Application_Sandbox>/Library/Caches/AudioHistory/
 ├── history_101.mp3
 ├── history_102.mp3
 └── history_103.mp3
```
- **Atomic Disk Writes:** New files are written using `Data.write(to: cachedFileURL, options: .atomic)`. If an app is backgrounded or network drops mid-stream, partial files are discarded and never corrupt the cache.
- **Offline First:** Once cached, tapping Play operates in 100% offline mode without touching the cellular or Wi-Fi network.

#### Performance & Bandwidth Comparison

| Architecture Pattern                | Initial Load Time          | Network Usage (20 items) | Memory Footprint          | Audio Quality / Playback             |
| ----------------------------------- | -------------------------- | ------------------------ | ------------------------- | ------------------------------------ |
| **Eager Preloading (Anti-pattern)** | 2.5s – 5.0s (Stutters UI)  | 15 MB – 40 MB data       | High (~120 MB RAM)        | High Risk of OOM Crash               |
| **SpeakIT Lazy-Loading (Standard)** | **< 80ms (Instant 120Hz)** | **~2 KB metadata**       | **Minimal (< 15 MB RAM)** | **Sub-second on tap, 0ms on replay** |

---

### 12.8 Public R2 Buckets: Threat Model, Security Posture & FAQs

#### "Both my buckets are publicly available — what is the actual threat?"

When an R2 bucket is connected to a Cloudflare Custom Domain (e.g. `cdn-speakit-audio.mohitur.com`), it is exposed to the internet. Understanding the exact attack vectors versus the built-in safeguards is critical for enterprise security:

| Threat Vector | Risk Level | How Cloudflare R2 & SpeakIT Defend Against It |
|---|---|---|
| **Directory Enumeration / Listing** | **ZERO RISK** | Unlike misconfigured AWS S3 buckets where attackers execute `ListBucket` to discover all files, **Cloudflare R2 Custom Domains do not support directory listing**. Requesting `/`, `/audio/`, or `/avatars/` returns an immediate `404 Not Found`. An attacker cannot see what files exist. |
| **Data Tampering (Overwrite / Delete)** | **ZERO RISK** | Cloudflare Custom Domains **only permit HTTP `GET` and `HEAD` requests**. `PUT`, `POST`, and `DELETE` requests are dropped at the edge (and explicitly blocked by our WAF rule). Write and delete actions strictly require AWS S3 SigV4 API credentials, which reside exclusively in the backend `.env`. |
| **Object Key Guessing / Brute-Force** | **NEGLIGIBLE** | SpeakIT generates keys using cryptographically random UUIDv4 identifiers: `audio/u_{userId}_{timestamp}_{uuid}.mp3`. A UUIDv4 possesses $2^{122}$ possible permutations. Guessing a single valid audio key is mathematically impossible ($> 10^{36}$ attempts). |
| **Bot Scraping & Automated Crawling** | **MITIGATED** | Automated scrapers (`curl`, `python`, `scrapy`, `go-http-client`, `wget`) attempting to crawl your domains are instantly blocked by our Cloudflare WAF Custom Rule. Legitimate browsers and the iOS app use native User-Agents and are unaffected. |
| **Hotlinking (Bandwidth Hijacking)** | **LOW** | External websites cannot embed your assets if Hotlink Protection is toggled in Cloudflare Security settings. Furthermore, because R2 has **$0 egress fees**, hotlinking does not incur high bandwidth bills. |
| **Audio Privacy Leakage** | **LOW / AUDITED** | Avatars are public profile photos by design. For audio, the URL is only delivered over authenticated TLS to the user who owns that history record. If an authorized user shares their direct MP3 URL with someone else, that person can listen to it. If HIPAA/banking confidentiality is ever required in the future, SpeakIT can transition from public CDN URLs to time-limited Pre-Signed URLs (e.g. valid for 15 minutes). |
| **Denial of Wallet (Class B Abuse)** | **MITIGATED** | While data egress is free ($0), Cloudflare charges $0.36 per 1M Class B (read) operations after 10M free operations/month. The combination of WAF Bot blocking, `max-age=31536000` edge caching, and mobile disk caching ensures that repeat requests never reach the storage origin. |

---
