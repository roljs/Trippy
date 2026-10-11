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
   - Works seamlessly offline with local fallback seed data (`thailandia_2026_trip.json`).

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
| `trippy_create_activity` | Adds a scheduled activity stamped with `lastModifiedSource: "mcp"`. |
| `trippy_update_activity` | Updates an activity stamped with `lastModifiedSource: "mcp"`. |
| `trippy_delete_activity` | Deletes an activity from a trip. |
| `trippy_create_stay` | Adds a hotel, rental, or overnight flight stay. |
| `trippy_update_stay` | Updates a stay. |
| `trippy_delete_stay` | Deletes a stay. |
| `trippy_create_flight` | Adds a flight booking. |
| `trippy_update_flight` | Updates a flight booking. |
| `trippy_delete_flight` | Deletes a flight booking. |
| `trippy_authenticate` | Authenticates session with Google/Firebase Auth credentials. |
