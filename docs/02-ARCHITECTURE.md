# 2. Architecture

## High-Level Flow

```
UI (screens, drawer, dialogs)
  -> Riverpod providers/notifiers
  -> repositories
  -> local data sources
  -> local files/shared preferences
```

## Core Components

### 1. App entry and shell

- `lib/main.dart`: Starts `ProviderScope`, creates `MaterialApp`, and wires theme mode.
- `lib/features/home/presentation/home_screen.dart`: Main workspace UI and interactions.

### 2. HTTP client

- `lib/core/services/relay_http_client.dart`: thin Dio-based HTTP client used to send test requests.
- `lib/core/services/api_service.dart`: wraps the HTTP client for the request runner.

### 3. Repositories and data sources

- `lib/features/home/presentation/providers/repository_providers.dart` wires collection/request/environment repositories directly to local data sources.
- Local data sources use `FileStorageService` and `WorkspaceService`.

## Data Flow Example

1. UI asks providers for collections/requests/environments.
2. Providers resolve local repositories/data sources.
3. Data is read from files and returned to UI.
