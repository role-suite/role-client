# 5. Data Model

The app works with **collections** (groups of requests), **requests** (API request definitions), and **environments** (named sets of variables). These are stored either **locally** (files + in-memory) or on the **backend** (role-server). The in-app models are defined in `lib/core/models/` and align with the server protocol where the backend is used.

## Core Models

### CollectionModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique id (e.g. UUID). |
| `name` | String | Display name. |
| `description` | String | Optional description. |
| `createdAt` | DateTime | Creation time (UTC). |
| `updatedAt` | DateTime | Last update time (UTC). |

Defined in `lib/core/models/collection_model.dart`. JSON: `toJson()` / `fromJson()`.

### ApiRequestModel

Represents a single HTTP request (method, URL, headers, body, etc.). Key fields include:

- `id`, `name`, `method` (e.g. GET, POST), `urlTemplate`, `headers`, `queryParams`, `body`, `bodyType`, `formDataFields`, `authType`, `authConfig`, `description`, `filePath`, `collectionId`, `environmentName`, `createdAt`, `updatedAt`.

Defined in `lib/core/models/api_request_model.dart`. Enums for method, body type, auth type live in `lib/core/models/request_enums.dart`.

### EnvironmentModel

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Environment name (e.g. "development", "production"). |
| `variables` | Map<String, String> | Variable name → value for substitution (`{{name}}`). |

Defined in `lib/core/models/environment_model.dart`.

### WorkspaceBundle

Full workspace snapshot for import/export and REST sync.

| Field | Type | Description |
|-------|------|-------------|
| `version` | int | Schema version (`WorkspaceBundle.currentVersion` = 1). |
| `exportedAt` | DateTime | Export time. |
| `source` | String? | Optional source identifier. |
| `collections` | List<CollectionBundle> | Collections with their requests. |
| `environments` | List<EnvironmentModel> | Environments. |

**CollectionBundle**: One collection plus its list of `ApiRequestModel`. Used inside `WorkspaceBundle.collections`.

Defined in `lib/core/models/workspace_bundle.dart`. JSON shape matches what role-server expects for GET/PUT `/workspace` and is used for local export/import (e.g. Postman import, sync to remote).

## Data Source Config

| Field | Type | Description |
|-------|------|-------------|
| `baseUrl` | String | API base URL. |
| `apiKey` | String? | Optional Bearer key (REST). |
| `apiStyle` | ApiStyle | `rest` or `serverpod`. |

Defined in `lib/core/models/data_source_config.dart`. `isValid` is true when `baseUrl.trim().isNotEmpty`.

## Local Storage

- **Preferences**: `SharedPreferences` stores data source mode, base URL, API key, API style (see [06-CONFIGURATION.md](06-CONFIGURATION.md)).
- **Workspace (local)**: Collections, requests, and environments are persisted under the app documents directory via `FileStorageService` and `WorkspaceService`. Exact layout is implementation-defined (e.g. one file per collection or a single workspace file). See `lib/features/home/data/datasources/request_local_data_source.dart` and `collection_local_data_source.dart` for how the app reads/writes.

## Alignment with Backend

When using the API (REST or Serverpod RPC), the app uses the same logical model as role-server. The **relay_server_client** package (from role-server) provides protocol types (`CollectionModel`, `ApiRequestModel`, `EnvironmentModel`, `WorkspaceBundle`); the app either uses these directly for RPC or maps to/from its own `lib/core/models` and the server JSON (see `ServerpodRelayApiClient` and `RestRelayApiClient` conversion helpers).
