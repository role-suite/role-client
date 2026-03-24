# 2. Architecture

## High-Level Flow

```
UI (screens, drawer, dialogs)
  -> Riverpod providers/notifiers
  -> repositories
  -> data sources (local or remote)
  -> local files/shared preferences OR role-server REST API
```

## Core Components

### 1. App entry and shell

- `lib/main.dart`: Starts `ProviderScope`, creates `MaterialApp`, and wires theme mode.
- `lib/features/home/presentation/home_screen.dart`: Main workspace UI and interactions.

### 2. Data source state and config

- `lib/features/home/presentation/providers/data_source_providers.dart`:
  - Holds current data source mode (`local` or `api`).
  - Holds API config (`baseUrl`, optional `apiKey`).
- `lib/core/services/data_source_preferences_service.dart` persists this config in `SharedPreferences`.

### 3. API client layer

- `lib/core/services/relay_api/relay_api_client.dart`: interface used by remote data sources.
- `lib/core/services/relay_api/rest_relay_api_client.dart`: REST implementation backed by workspace GET/PUT.
- `lib/core/services/workspace_api/rest_workspace_client.dart`: low-level HTTP client for `/workspace`.

### 4. Repositories and data sources

- `lib/features/home/presentation/providers/repository_providers.dart` switches between local and remote implementations based on data source mode.
- Local data sources use `FileStorageService` and `WorkspaceService`.
- Remote data sources use `RelayApiClient`.

### 5. Sync to remote

- `lib/core/services/sync_to_remote_service.dart` pushes local collections, requests, and environments to the configured REST backend.
- Triggered from the drawer while in local mode.

## Data Flow Examples

### Local mode

1. UI asks providers for collections/requests/environments.
2. Providers resolve local repositories/data sources.
3. Data is read from files and returned to UI.

### API mode (REST)

1. User configures base URL (and optional API key), then switches to API mode.
2. Providers resolve remote repositories/data sources.
3. Remote data sources call `RestRelayApiClient`, which fetches and updates workspace data over REST.

### Sync local to remote

1. User taps "Sync to remote" in local mode.
2. App loads local collections/requests/environments.
3. `SyncToRemoteService` writes them to the configured REST backend.
