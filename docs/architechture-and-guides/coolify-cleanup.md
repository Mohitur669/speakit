# SpeakIT: Coolify Zero-Trust Migration & Cleanup Runbook

This actionable runbook guides you through transitioning from a public DNS / webhook setup to the **Zero-Trust CI/CD over Tailscale (Pattern A)** deployment architecture.

By completing this cleanup, you eliminate all public exposure of your Coolify control plane, avoid Cloudflare WAF costs, and ensure all connectivity parameters (IPs, ports, UUIDs) are managed strictly via environment variables.

---

## Architecture Comparison

| Area | Old / Legacy Setup | Zero-Trust Tailscale Setup (New) |
| :--- | :--- | :--- |
| **Coolify DNS** | Public A Record `coolify.yourdomain.com` pointing to OCI IP | ❌ **Deleted** (No public DNS record) |
| **Control Plane Ingress** | Public Port 8000 / Traefik proxy | 🔒 **Zero public ingress** (Encrypted WireGuard only) |
| **CI/CD Trigger** | Public GitHub Webhook HTTP POST | 🛡️ **GitHub Action + Tailscale Ephemeral Connection** |
| **Cloudflare WAF** | Custom rules (Paid / Restricted) | 💰 **$0 / Not Needed** |
| **Secrets & IPs** | Hardcoded in scripts/configs | 🔑 **100% Parameterized in GitHub Secrets** |

---

## Phase 1: Cleanup Legacy / Insecure Configurations

Perform these steps first to eliminate public attack surface and avoid failing webhook errors:

### 1.1 Delete Public Coolify DNS in Cloudflare
1. Log into your **[Cloudflare Dashboard](https://dash.cloudflare.com/)** > Select your domain (`yourdomain.com`).
2. Go to **DNS** > **Records**.
3. Locate the **A Record** named **`coolify`** pointing to your OCI public IP.
4. Click **Edit** > **Delete**.
5. *Why*: Internet scanners (Shodan, Censys) will no longer be able to resolve your OCI IP to a Coolify control panel.

### 1.2 Remove Cloudflare WAF Custom Rules (If Created)
1. In Cloudflare, go to **Security** > **WAF** > **Custom Rules**.
2. If you created a rule to block non-webhook paths (e.g. `Lockdown Coolify Dashboard`), **Delete** or **Disable** it.
3. *Why*: Since `coolify.yourdomain.com` is no longer routed through Cloudflare, WAF rules for this hostname are obsolete.

### 1.3 Clean Up Legacy GitHub Webhooks
1. Open your GitHub Repository > **Settings** > **Webhooks**.
2. If there is an existing webhook pointing to `https://coolify.yourdomain.com/...`:
   * Click **Delete** (or disable it).
3. If you configured a GitHub App in your GitHub Account Developer Settings:
   * Go to **Settings** > **Developer Settings** > **GitHub Apps** > Select your app.
   * Under **Webhook**, uncheck **Active** (or delete the app if replacing with GitHub Actions).
4. *Why*: Eliminates repeated failed webhook delivery attempts (red `403`/`404` badges in GitHub).

### 1.4 Verify Inbound Firewall Rules on OCI & UFW
1. **OCI VCN Ingress Rules**:
   * Open **OCI Console** > **Networking** > **Virtual Cloud Networks** > Click your VCN > **Security Lists**.
   * Verify that **Port 8000** (Coolify UI) has **NO** `0.0.0.0/0` ingress rule.
   * Verify that **Database Ports (3000, 3001, 5432, 6001, 6002)** have **NO** `0.0.0.0/0` ingress rules.
   * Only ports **80** (HTTP) and **443** (HTTPS) should be open to `0.0.0.0/0` for public application traffic (`api.yourdomain.com`).
2. **Linux UFW Firewall** (on the OCI server terminal):
   ```bash
   sudo ufw status verbose
   ```
   *Ensure port 8000 and database ports are not allowed from `Anywhere`.*

---

## Phase 2: Tailscale ACL & Authentication Setup

### 2.1 Update Tailscale Policy File (ACL)
Any automated machine node (like GitHub Actions runners via OIDC, OAuth, or tagged Auth Keys) must have an owner defined in Tailscale's access control policy.

1. Open **[Tailscale Admin Console > Settings > Policy file management](https://login.tailscale.com/admin/settings/policy)**.
2. In your policy JSON:
   * **Uncomment / Define `tagOwners`**: Grant your admin group permission to manage `tag:ci`.
   * **(Optional) Add Host Alias**: Under `"hosts"`, add your Coolify server's private Tailscale IP.
   * **Add Ingress Rule in `acls`**: Allow `tag:ci` to communicate with Coolify on port `8000`.

```jsonc
{
  // Declare static groups of users.
  "groups": {
    "group:admin":  ["<YOUR_ADMIN_EMAIL>"],
    "group:family": ["<YOUR_FAMILY_EMAIL>"],
  },

  "hosts": {
    "homeserver": "<YOUR_HOMESERVER_TAILSCALE_IP>",
    // Replace with your OCI server Tailscale IP (find with 'tailscale ip')
    "coolify":    "<YOUR_SERVER_TAILSCALE_IP>",
  },

  // 1. Define tag owners (MANDATORY for OIDC, OAuth, and Machine Tags)
  "tagOwners": {
    "tag:ci": ["group:admin"],
  },

  "acls": [
    // 1. Admins have access to EVERYTHING
    {
      "action": "accept",
      "src":    ["group:admin"],
      "dst":    ["*:*"],
    },

    // 2. Family members access
    {
      "action": "accept",
      "src":    ["group:family"],
      "dst": [
        "homeserver:53",
        "homeserver:7575",
        "homeserver:8080",
        "homeserver:8081",
        "homeserver:8082",
        "homeserver:8083",
        "homeserver:8096",
      ],
    },

    // 3. Allow GitHub Actions CI/CD to access Coolify API port only
    {
      "action": "accept",
      "src":    ["tag:ci"],
      "dst":    ["coolify:8000"],
    },
  ],

  "grants": [],

  // Define users and devices that can use Tailscale SSH.
  "ssh": [
    {
      "action": "check",
      "src":    ["autogroup:member"],
      "dst":    ["autogroup:self"],
      "users":  ["autogroup:nonroot", "root"],
    },
  ],
}
```
3. Click **Save** in Tailscale Policy file management.

---

### 2.2 Configure Coolify API Access & Scoped Deploy Token

Because Coolify's deploy webhook is an API endpoint (`/api/v1/deploy?...`), Coolify requires instance-level API access to be enabled:

1. **Enable API Access in Coolify**:
   * Open your Coolify dashboard over Tailscale: `http://<YOUR_SERVER_TAILSCALE_IP>:<COOLIFY_PORT>`.
   * Navigate to **Settings** > **Advanced** (under **Access and API** > **API and MCP**).
   * **API access**: Toggle from **Disabled** to **Enabled**.
   * **Allowed IPs**:
     * **Leave blank / empty** (recommended, since Coolify is already restricted to private Tailscale), OR
     * Set to Tailscale's CGNAT CIDR: **`100.64.0.0/10`**.
     * ⚠️ *Important*: Do NOT leave the example placeholder (`192.168.1.100, 10.0.0.0/8`), or your GitHub Actions runner (connecting via Tailscale `100.x.y.z`) will be rejected with HTTP `403 Forbidden`.
   * Click **Save**.

2. **Generate Deploy API Token**:
   * In the main sidebar, navigate to **Keys & Tokens** > **API tokens** (or click your profile > **API Tokens**).
   * Click **Create Token** / **New Token**:
     * **Description**: `github-actions-deploy`
     * **Permissions**: Check **`deploy`** (grants permission exclusively to trigger application builds).
   * Click **Create** and **copy the generated token** immediately.

3. **Retrieve Application Deploy Webhook**:
   * Navigate to your project > **`speakit-prod-backend`**.
   * In the application details header / settings, locate the **Deploy Webhook**.
   * Note the format:
     ```text
     http://<YOUR_SERVER_TAILSCALE_IP>:<COOLIFY_PORT>/api/v1/deploy?uuid=<YOUR_APP_UUID>&force=false
     ```
     *(Keep this URL confidential — it contains your private app UUID).*

---

### 2.3 Choose Your Authentication Method for GitHub Actions

#### Option A: Workload Identity Federation / OIDC (Industry Gold Standard — Keyless)
Tailscale supports OpenID Connect (OIDC) across all tiers (including the Free tier). This eliminates static long-lived keys:
1. In Tailscale Admin Console, go to **Settings > Trust credentials**.
2. Click **Add credential** / **Create OIDC credential**:
   * **Step 1: Settings**:
     * **Description**: `speakit-github-coolify-deploy`
     * **Issuer**: `GitHub`
     * **Issuer URL**: `https://token.actions.githubusercontent.com`
     * **Subject**: `repo:Mohitur669/speakit:*`
     * **Custom claims**: Leave empty / unconfigured.
     * Click **Next** to proceed to Scopes.
   * **Step 2: Scopes**:
     * Under **Keys**, click **Auth Keys** > select **Write** (or Read & Write).
     * Under **Devices**, click **Core** > select **Write** (or Read & Write).
     * In the **Tags** selector that appears, choose **`tag:ci`**.
     * Click **Create credential** (or **Save**).
3. Copy the generated **Client ID** / **Audience**.
4. Add to GitHub Secrets:
   * **`TS_OIDC_CLIENT_ID`**: Your Tailscale OIDC client ID.

#### Option B: OAuth Client (Under Trust Credentials)
1. In Tailscale Admin Console, go to **Settings > Trust credentials** (or **OAuth Clients**).
2. Click **Generate OAuth Client**.
3. Roles / Permissions: Select **Devices (Write)** and/or **Auth keys (Write)**.
4. Tags: Assign `tag:ci`.
5. Add to GitHub Secrets:
   * **`TS_OAUTH_CLIENT_ID`**
   * **`TS_OAUTH_SECRET`**

#### Option C: Ephemeral Auth Key (Simplest Single-Secret Setup)
1. In Tailscale Admin Console, go to **Settings > Keys**.
2. Click **Generate auth key...**:
   * **Reusable**: ✅ Checked.
   * **Ephemeral**: ✅ Checked.
   * **Pre-authorized**: ✅ Checked.
   * **Tags**: Assign `tag:ci`.
3. Add to GitHub Secrets:
   * **`TAILSCALE_AUTHKEY`**: `tskey-auth-...`

---

### 2.4 Store Secrets in GitHub Repository
In your GitHub repository > **Settings** > **Secrets and variables** > **Actions** > Click **New repository secret**:

| Secret Name | Value | Description |
| :--- | :--- | :--- |
| **`TAILSCALE_AUTHKEY`** *(or `TS_OIDC_CLIENT_ID`)* | `tskey-auth-...` | Tailscale Ephemeral Auth Key or OIDC Client ID. |
| **`COOLIFY_PROD_DEPLOY_URL`** | `http://<YOUR_SERVER_TAILSCALE_IP>:<COOLIFY_PORT>/api/v1/deploy?uuid=<YOUR_APP_UUID>&force=false` | Private deploy webhook URL. |
| **`COOLIFY_FQDN_HOST`** | `<YOUR_COOLIFY_FQDN>` (e.g. `coolify.yourdomain.com`) | Injected as `Host:` header for internal proxy routing. |
| **`COOLIFY_API_TOKEN`** | *[Optional]* | Bearer token if API authentication is enabled. |

---

## Phase 3: Add the GitHub Actions Deployment Workflow

Create the automated deployment workflow in your repository at **`.github/workflows/coolify-deploy.yml`**:

```yaml
name: Coolify Auto-Deploy

on:
  push:
    branches:
      - master
    paths:
      - 'backend/**'
      - 'pom.xml'
      - '.github/workflows/coolify-deploy.yml'
  workflow_dispatch:

jobs:
  deploy:
    name: Trigger Coolify Deployment over Tailscale
    runs-on: ubuntu-latest
    timeout-minutes: 5

    # Required for OIDC Workload Identity Federation
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Connect to Tailscale via OIDC
        uses: tailscale/github-action@v3
        with:
          oauth-client-id: ${{ secrets.TS_OIDC_CLIENT_ID }}
          tags: tag:ci

      - name: Trigger Coolify Backend Deployment
        env:
          COOLIFY_DEPLOY_URL: ${{ secrets.COOLIFY_PROD_DEPLOY_URL }}
          COOLIFY_HOST_HEADER: ${{ secrets.COOLIFY_FQDN_HOST }}
          COOLIFY_TOKEN: ${{ secrets.COOLIFY_API_TOKEN }}
        run: |
          echo "Dispatching private deployment trigger to Coolify..."
          
          if [ -z "$COOLIFY_DEPLOY_URL" ]; then
            echo "Error: COOLIFY_PROD_DEPLOY_URL secret is not configured!"
            exit 1
          fi
          
          HOST_HEADER_PARAM=""
          if [ -n "$COOLIFY_HOST_HEADER" ]; then
            HOST_HEADER_PARAM="-H Host: $COOLIFY_HOST_HEADER"
          fi
          
          AUTH_HEADER_PARAM=""
          if [ -n "$COOLIFY_TOKEN" ]; then
            AUTH_HEADER_PARAM="-H Authorization: Bearer $COOLIFY_TOKEN"
          fi
          
          HTTP_STATUS=$(curl -s -o response.json -w "%{http_code}" -X POST "$COOLIFY_DEPLOY_URL" \
            $HOST_HEADER_PARAM \
            $AUTH_HEADER_PARAM \
            -H "Content-Type: application/json")
          
          echo "Coolify HTTP Response Code: $HTTP_STATUS"
          cat response.json
          
          if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
            echo "Deployment successfully triggered in Coolify!"
          else
            echo "Failed to trigger deployment in Coolify!"
            exit 1
          fi
```

---

## Phase 4: Configure Coolify Application Settings

Access Coolify locally over Tailscale (**`http://<YOUR_SERVER_TAILSCALE_IP>:<COOLIFY_PORT>`**) and verify:

1. **Watch Paths**:
   * Under **Settings** > **Watch Paths**, ensure it is set to:
     ```text
     backend/**
     ```
   * *Why*: Prevents frontend commits from triggering Java container rebuilds.
2. **Pre-deployment Commands**:
   * Ensure `php artisan migrate` is **deleted** and left empty.
3. **Internal Port**:
   * Ensure **Ports Exposes** is set to **`8080`**.
   * Ensure **Port Mappings** is left **empty** (no host port binding).

---

## Phase 5: Verification & End-to-End Test

1. **Trigger a Test Deploy**:
   * Push a commit to `master` touching any file in `backend/` or trigger `.github/workflows/coolify-deploy.yml` manually via GitHub Actions UI (**Run workflow**).
2. **Check GitHub Actions Runner Logs**:
   * Navigate to your GitHub repository > **Actions** tab > Click the workflow run.
   * Expand **Trigger Coolify Backend Deployment**:
   * It should log:
     ```text
     Dispatching private deployment trigger to Coolify...
     Coolify HTTP Response Code: 200
     {"message":"Deployment queued."}
     Deployment successfully triggered in Coolify!
     ```
3. **Check Live Coolify Build Logs**:
   * In your browser, open Coolify over Tailscale:
     ```text
     http://<YOUR_SERVER_TAILSCALE_IP>:<COOLIFY_PORT>
     ```
   * Open **`speakit-prod-backend`** > **Deployments**.
   * A new deployment should be running, displaying live Maven compile and Docker packaging logs.

---

## Cross-Reference & Synchronization Note

This runbook acts as the fast-track operational checklist. For full deep-dive architectural context (Docker namespace isolation, PostgreSQL bind mounts, Oracle S3 backups, and DBeaver SSH tunneling), consult:
* [COOLIFY_DEPLOYMENT_GUIDE.md](file:///Users/mohitur/Desktop/git-projects/speakit/docs/architechture-and-guides/COOLIFY_DEPLOYMENT_GUIDE.md)
