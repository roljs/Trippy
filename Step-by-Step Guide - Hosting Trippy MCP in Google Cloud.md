# Step-by-Step Guide: Hosting Trippy MCP in Google Cloud

> **Reference**: [Google Cloud Run Documentation: Host MCP servers on Cloud Run](https://docs.cloud.google.com/run/docs/host-mcp-servers)  
> **Target Project**: `trippy-prod-4524f` (Firebase & Google Cloud Platform)  
> **Server Image / Binary**: Built from [bin/trippy_mcp_server.dart](bin/trippy_mcp_server.dart) via [Dockerfile](Dockerfile)

---

## Architecture Overview

The **Trippy MCP Server** standardizes how AI agents (Claude, Antigravity IDE, ChatGPT Actions, Gemini, mobile/web clients) interact with your travel planner data.

```
┌─────────────────────────────────┐
│ AI Clients                      │
│ • Claude Desktop                │
│ • Antigravity IDE / Cursor      │
│ • ChatGPT Custom Actions        │
│ • Gemini Web & Mobile Apps      │
└───────────────┬─────────────────┘
                │
                │ Streamable HTTP (POST /mcp) or SSE (GET /sse)
                ▼
┌────────────────────────────────────────────────────────┐
│ Google Cloud Run (`trippy-mcp-server`)                 │
│                                                        │
│ • Port 8080 (auto-injected $PORT)                      │
│ • High-performance native compiled Dart binary         │
│ • 16 registered MCP tools                              │
│ • Itinerary translation engine                         │
│ • Pre-seeded fallback data + Firebase Auth integration │
└────────────────────────────────────────────────────────┘
```

- **Transport Types Supported**:
  - **Server-Sent Events (SSE)**: `GET /sse` (events) + `POST /messages` (incoming JSON-RPC).
  - **Streamable HTTP POST**: `POST /mcp` (standard JSON-RPC 2.0).
  - **Health & Info**: `GET /health` or `GET /`.
- **Cloud Run Advantage**: Automatic HTTPS, response streaming, scaling down to zero when idle, and managed Google IAM authentication.

---

## Step 1: Prepare Google Cloud & Enable Services

Make sure you have the [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install) installed, authenticated, and configured to your project:

```bash
# 1. Sign in to your Google Cloud account
gcloud auth login

# 2. Set the active project to Trippy
gcloud config set project trippy-prod-4524f

# 3. Enable Cloud Run, Cloud Build, and Artifact Registry APIs
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

---

## Step 2: Containerization ([Dockerfile](Dockerfile) & [.dockerignore](.dockerignore))

The repository includes a multi-stage [Dockerfile](Dockerfile) and [.dockerignore](.dockerignore) optimized for Cloud Run:

- **Stage 1 (Builder)**: Uses Google's official `dart:stable` image to download pure-Dart packages (`uuid`) and compiles [bin/trippy_mcp_server.dart](bin/trippy_mcp_server.dart) into a standalone native Linux executable using `dart compile exe`.
- **Stage 2 (Runtime)**: Copies only the compiled binary and `sample_trip.json` into a clean, minimal `debian:bookworm-slim` image (~30 MB) with SSL CA certificates installed.
- **Port Contract**: Listens on `0.0.0.0` on the port assigned by Cloud Run's `$PORT` environment variable (default `8080`).

---

## Step 3: Deploy to Cloud Run

Choose the deployment access level that matches your security and client needs:

### Option A: Private / IAM-Protected *(Recommended by Google for personal AI agents)*
Restricts access strictly to Google accounts and service accounts that have the `roles/run.invoker` role:

```powershell
gcloud run deploy trippy-mcp-server --source . --region us-central1 --port 8080 --no-allow-unauthenticated
```

### Option B: Public HTTPS with Personal Access Tokens (PATs) *(Recommended for Grok, Gemini, ChatGPT Actions)*
Deploys with public HTTPS access secured by Firestore-backed Personal Access Tokens (PATs):

```powershell
gcloud run deploy trippy-mcp-server `
  --source . `
  --region us-central1 `
  --port 8080 `
  --project trippy-prod-4524f `
  --allow-unauthenticated
```

#### Generating a Personal Access Token for Your AI Bots:
Run the bundled token generator:
```powershell
dart run bin/create_pat.dart --email roljs@hotmail.com --name "Grok Bot"
```
This stores a cryptographically hashed token in Cloud Firestore collection `mcp_api_keys` bound strictly to your account UID.

#### Understanding the Anti-Impersonation Architecture:
- **Zero Impersonation Vulnerability**:
  - Each PAT (e.g. `trippy_pat_...`) belongs to **exactly one user**.
  - When Grok Bot or Gemini connects with `?key=trippy_pat_...`, the server looks up the token hash in Firestore and authenticates as that user.
  - If a caller tries to specify someone else's email address, the request is **immediately rejected with a Security Violation**.
- **Instant Revocation**:
  - Tokens can be revoked anytime via the `trippy_revoke_pat` tool or by deleting the document in Firestore, without redeploying the Cloud Run container.
- **Default / Unauthenticated Sandbox**:
  - Requests without a valid PAT or token are quarantined in an in-memory sample sandbox (`sample_trip.json`). Changes never touch Cloud Firestore.

> Once deployment finishes, Cloud Run will print your public Service URL:  
> `https://trippy-mcp-server-xxxxxxxx-uc.a.run.app`

---

## Step 4: Connecting Clients to Your Hosted MCP Server

### 1. Local Clients (Claude Desktop, Antigravity IDE, Cursor) via Cloud Run Proxy
When deployed using **Option A (IAM-protected)**, launch the Google Cloud Run local proxy to route requests with your active Google credentials:

```bash
gcloud run services proxy trippy-mcp-server --region us-central1 --port=8080
```

Then in your client's MCP configuration (`claude_desktop_config.json` or `mcp_config.json`):

```json
{
  "mcpServers": {
    "trippy": {
      "url": "http://localhost:8080/sse"
    }
  }
}
```

*Or with `mcp-remote` if the client only accepts CLI command spawners:*

```json
{
  "mcpServers": {
    "trippy": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8080/sse"]
    }
  }
}
```

### 2. Cloud AI Clients (Grok Bot, Gemini, ChatGPT Actions)
When using **Option B**:
- **Base URL**: `https://<YOUR-CLOUD-RUN-URL>`
- **Secured Endpoint (URL Parameter)**: `https://<YOUR-CLOUD-RUN-URL>/mcp?key=YOUR_CHOSEN_PASSCODE&email=user@example.com`
- **SSE Endpoint**: `https://<YOUR-CLOUD-RUN-URL>/sse?key=YOUR_CHOSEN_PASSCODE`
- **Prompt Authentication**: If not included in the URL, prompt your AI model:
  > *"Authenticate with Trippy using user@example.com and passcode YOUR_CHOSEN_PASSCODE."*

---

## Step 5: Verification & Health Check

Test that your deployed service is active and responsive:

### 1. Check Service Health
```bash
curl https://<YOUR-CLOUD-RUN-URL>/health
```
**Expected Response**:
```json
{
  "status": "online",
  "server": "Trippy MCP Server",
  "version": "1.0.0",
  "project": "trippy-prod-4524f",
  "currentUser": "sample_user",
  "authenticated": false,
  "toolsCount": 16
}
```

### 2. Verify MCP Tool Discovery
```bash
curl -X POST https://<YOUR-CLOUD-RUN-URL>/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'
```
**Expected Response**:
JSON-RPC 2.0 response returning all 16 tools, including:
- `trippy_apply_suggested_itinerary`
- `trippy_list_trips`
- `trippy_get_trip_details`
- `trippy_create_activity`, `trippy_update_activity`, `trippy_delete_activity`
- `trippy_create_stay`, `trippy_update_stay`, `trippy_delete_stay`
- `trippy_create_flight`, `trippy_update_flight`, `trippy_delete_flight`
- `trippy_authenticate`

---

## Quick Reference Summary

| Task | Command |
|---|---|
| **Deploy to Cloud Run** | `gcloud run deploy trippy-mcp-server --source . --region us-central1 --port 8080` |
| **Start Local IAM Proxy** | `gcloud run services proxy trippy-mcp-server --region us-central1 --port=8080` |
| **View Service Logs** | `gcloud run services logs tail trippy-mcp-server --region us-central1` |
| **Update Service Config** | `gcloud run services update trippy-mcp-server --region us-central1` |
