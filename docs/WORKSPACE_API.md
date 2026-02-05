# Workspace API contract (API data source)

When the user selects **API** as the data source in the app, the client loads and saves workspace data (collections, requests, environments) from a remote server instead of local files.

## Base URL and auth

- The user configures a **base URL** (e.g. `https://api.example.com`) and optionally an **API key**.
- The client sends the API key as a header: `Authorization: Bearer <apiKey>`.
- All requests use the path **`/workspace`** relative to the base URL (e.g. `GET https://api.example.com/workspace`).

## Endpoints

### GET /workspace

Returns the full workspace as a single JSON object in **Relay workspace export format** (same as Export Workspace in the app).

**Response body** (application/json):

- `version` (number): schema version, use `1`
- `exportedAt` (string): ISO 8601 date
- `source` (string, optional): e.g. `"relay"`
- `collections` (array): each item is a **collection bundle** with:
  - `collection`: object with `id`, `name`, `description`, `createdAt`, `updatedAt`
  - `requests`: array of request objects (same shape as in Relay export)
- `environments` (array): each item has `name` and `variables` (map of string to string)

Example minimal response:

```json
{
  "version": 1,
  "exportedAt": "2025-02-05T12:00:00.000Z",
  "source": "relay",
  "collections": [
    {
      "collection": {
        "id": "default",
        "name": "Default",
        "description": "",
        "createdAt": "2025-02-05T12:00:00.000Z",
        "updatedAt": "2025-02-05T12:00:00.000Z"
      },
      "requests": []
    }
  ],
  "environments": []
}
```

Request/collection and environment shapes match the app’s export format (see `WorkspaceBundle` and related models in the codebase, or export a workspace from the app to see a full example).

### PUT /workspace

Accepts the same JSON structure as above and replaces the workspace on the server (full replace). Optional: if your backend is read-only, you can implement only GET; the app will still work for loading, but create/update/delete will fail when it tries to PUT.

## Summary

| Method | Path     | Purpose                    |
|--------|----------|----------------------------|
| GET    | /workspace | Load full workspace       |
| PUT    | /workspace | Save full workspace (optional) |

The client uses this to **feed the application from the API** when “API” is selected, and optionally to push changes back when the user creates or edits collections, requests, or environments.
