# 3. Data Model

The app works with **collections** (groups of requests), **requests** (API request definitions), and **environments** (named sets of variables). All are stored locally on-device. The in-app models are defined in `lib/core/models/`.

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

Full workspace snapshot used for import/export.

| Field | Type | Description |
|-------|------|-------------|
| `version` | int | Schema version (`WorkspaceBundle.currentVersion` = 1). |
| `exportedAt` | DateTime | Export time. |
| `source` | String? | Optional source identifier. |
| `collections` | List<CollectionBundle> | Collections with their requests. |
| `environments` | List<EnvironmentModel> | Environments. |

**CollectionBundle**: One collection plus its list of `ApiRequestModel`. Used inside `WorkspaceBundle.collections`.

Defined in `lib/core/models/workspace_bundle.dart`. Used for local export/import (Röle and Postman-style JSON).

## Local Storage

- **Preferences**: `SharedPreferences` stores app-level preferences such as theme mode (see [04-CONFIGURATION.md](04-CONFIGURATION.md)).
- **Workspace**: Collections, requests, and environments are persisted under the app documents directory via `FileStorageService` and `WorkspaceService`. See `lib/features/home/request/data/datasources/request_local_data_source.dart` and `collection_local_data_source.dart` for how the app reads/writes.
