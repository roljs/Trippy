# Trippy Model Context Protocol (MCP) Server

The **Trippy MCP Server** enables conversational AI models (Claude, ChatGPT, Gemini, Antigravity, Cursor, and mobile/web clients) to interact directly with your Trippy travel itineraries, stays, flights, and activities.

---

## Key Capabilities

1. **AI Daily Itinerary Translation (`trippy_apply_suggested_itinerary`)**:
   - Ask an LLM to propose a complete daily itinerary for any day or destination.
   - Once approved, the LLM translates the plan directly into Trippy activities, lodgings, and flights for that day.
2. **Read & Write Operations**:
   - List trips, inspect day-by-day schedules, view flights and stays.
   - Create, update, or remove activities, stays, flights, and day locations.
3. **Modification Source & Last-Modified Tracking**:
   - All objects created or edited via MCP are automatically stamped with `lastModifiedSource: "mcp"` and `lastModifiedAt: <timestamp>`.
   - Trippy UI displays a distinct purple robot badge (`MCP Server • <time>`) on all cards and detail sheets when modified via MCP, or a slate badge (`Trippy UI • <time>`) when modified in the app.
4. **Google & Firebase Authentication**:
   - Authenticates with Google accounts controlling Firebase access in project `trippy-prod-4524f`.
   - Supports Bearer ID tokens via HTTP headers, environment variable (`TRIPPY_AUTH_TOKEN`), or the `trippy_authenticate` tool.
   - Works seamlessly offline with in-memory sample sandbox data (`sample_trip.json`).

---

## Running the Server

### 1. Standard I/O (Claude Desktop, Antigravity IDE, Cursor)
```bash
dart run bin/trippy_mcp_server.dart
```

### 2. HTTP & Server-Sent Events (ChatGPT Actions, Gemini, Web & Mobile)
```bash
dart run bin/trippy_mcp_server.dart --port 8080
```
- **MCP JSON-RPC Endpoint**: `POST http://localhost:8080/mcp`
- **SSE Stream Endpoint**: `GET http://localhost:8080/sse`
- **Health Check**: `GET http://localhost:8080/health`

---

## Client Configuration

### Claude Desktop
Add to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "trippy": {
      "command": "dart",
      "args": ["run", "bin/trippy_mcp_server.dart"],
      "cwd": "C:/Users/roljs/repos/Trippy",
      "env": {
        "TRIPPY_PROJECT_ID": "trippy-prod-4524f"
      }
    }
  }
}
```

### Antigravity IDE & Cursor
Use the included `mcp_config.json`:
```json
{
  "mcpServers": {
    "trippy": {
      "command": "dart",
      "args": ["run", "bin/trippy_mcp_server.dart"],
      "env": {
        "TRIPPY_PROJECT_ID": "trippy-prod-4524f"
      }
    }
  }
}
```

### Remote Cloud Run Endpoints
- **Streamable HTTP POST**: `https://trippy-mcp-server-392329008088.us-central1.run.app/mcp`
- **Server-Sent Events (SSE)**: `https://trippy-mcp-server-392329008088.us-central1.run.app/sse`
- **Health Check**: `https://trippy-mcp-server-392329008088.us-central1.run.app/health`

### Gemini (Web, Mobile & AI Studio)
- **URL**: `https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=YOUR_PERSONAL_ACCESS_TOKEN`
- **Transport**: HTTP POST (JSON-RPC 2.0)
- **Authentication**: **Automatic!** When the `key` parameter is set in the URL or query parameters, Gemini is pre-authenticated for every request. You do not need to ask Gemini to authenticate. You can immediately ask:
  - *"What trips do I have in Trippy?"*
  - *"Show my itinerary for Thailand"*
  - *(Optional)* If you do prompt *"Authenticate me with Trippy"*, the server uses the configured key and verifies your email automatically.

### ChatGPT (Custom GPTs / Actions)
- **Connector / Action URL**: `https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=YOUR_PERSONAL_ACCESS_TOKEN` (or `/sse?key=YOUR_PERSONAL_ACCESS_TOKEN`)

### Mobile Clients (iOS & Android MCP Apps)
- In **Chatbox Mobile**, **LibreChat Mobile**, or **TypingMind**:
  - Add server with URL: `https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=YOUR_PERSONAL_ACCESS_TOKEN`
  - All calls are pre-authenticated with your personal access token bound to your account.

---

## Exposed MCP Tools

| Tool Name | Description |
|---|---|
| `trippy_apply_suggested_itinerary` | **Main Use Case**: Direct translation of an approved daily itinerary into Trippy activities, stays, and flights with `lastModifiedSource: "mcp"`. |
| `trippy_list_trips` | Lists all trips with destinations, dates, and item counts. |
| `trippy_get_trip_details` | Returns full details (itinerary, stays, flights, locations) for a trip. |
| `trippy_create_trip` | Creates a new trip. |
| `trippy_update_trip` | Updates trip details and metadata. |
| `trippy_set_day_locations` | Updates the city/neighborhood locations planned for a specific date. |
| `trippy_create_activity` | Adds a scheduled activity with ticketUrl, links, and attachments. |
| `trippy_update_activity` | Updates an activity (supports notes, cost, ticketUrl, links/addLinks, attachments/addAttachments). |
| `trippy_delete_activity` | Deletes an activity from a trip. |
| `trippy_create_stay` | Adds a hotel, rental, or overnight flight stay with links and attachments. |
| `trippy_update_stay` | Updates a stay (supports dates, times, notes, address, links/addLinks, attachments/addAttachments). |
| `trippy_delete_stay` | Deletes a stay. |
| `trippy_create_flight` | Adds a flight booking with links and attachments. |
| `trippy_update_flight` | Updates a flight booking (supports seats, gates, terminals, notes, links/addLinks, attachments/addAttachments). |
| `trippy_delete_flight` | Deletes a flight booking. |
| `trippy_add_link` | Adds a reference link or attachment URL to any stay, activity, or flight. Supports all web URLs (including Expedia, Booking, Airbnb, or session-protected links) without external validation. |
| `trippy_authenticate` | Authenticates session with Google/Firebase Auth credentials. |

---

## Hosting on Google Cloud Run

To host the Trippy MCP Server on Google Cloud Run with streamable HTTP and SSE transport per the [Google Cloud MCP Server Hosting Guide](https://docs.cloud.google.com/run/docs/host-mcp-servers):

```bash
# 1. Select the Firebase/GCP project
gcloud config set project trippy-prod-4524f

# 2. Deploy directly using the included Dockerfile
gcloud run deploy trippy-mcp-server \
  --source . \
  --region us-central1 \
  --port 8080

# 3. Connect local AI clients securely via Cloud Run proxy
gcloud run services proxy trippy-mcp-server --region us-central1 --port=8080
```

