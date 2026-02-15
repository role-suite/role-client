# 2. Architecture

## High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              role-client (Röle)                               │
│                                                                               │
│  ┌─────────────────┐     ┌──────────────────┐     ┌───────────────────────┐  │
│  │ UI (Screens,    │────►│ Providers        │────►│ Repositories          │  │
│  │ Drawer, Dialogs)│     │ (Riverpod)       │     │ (Collection, Request,  │  │
│  └─────────────────┘     └────────┬─────────┘     │  Environment)          │  │
│                                   │               └───────────┬─────────────┘  │
│                                   │                           │               │
│                                   ▼                           ▼               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Data source mode (Local vs API) → Data sources                            │ │
│  │   • Local: CollectionLocalDataSource, RequestLocalDataSource (files)     │ │
│  │   • API:   CollectionRemoteDataSource, RequestRemoteDataSource           │ │
│  │            → RelayApiClient (REST or Serverpod RPC)                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                   │                                           │
└───────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────────┐
            │ Local storage │               │ role-server       │
            │ (files,       │               │ REST /workspace   │
            │  SharedPrefs) │               │ or Serverpod RPC  │
            └───────────────┘               └───────────────────┘
```

## Components

### 1. Entrypoint and App

- **`lib/main.dart`**: `runApp(ProviderScope(child: MyApp()))`. `MyApp` is a `ConsumerWidget` that watches `themeModeNotifierProvider` and builds `MaterialApp` with `HomeScreen` as home.
- **`lib/features/home/presentation/home_screen.dart`**: Main screen: collection selector, request list, request runner, drawer. Uses Riverpod for collections, requests, environments, data source state.

### 2. Data Source and API Clients

- **`lib/features/home/presentation/providers/data_source_providers.dart`**: `DataSourceStateNotifier` holds current mode (local vs API) and `DataSourceConfig` (baseUrl, apiKey, apiStyle). Loaded/saved via `DataSourcePreferencesService` (SharedPreferences).
- **`lib/core/services/relay_api/`**: `RelayApiClient` interface; implementations:
  - **RestRelayApiClient**: Uses `RestWorkspaceClient` (Dio) for GET/PUT workspace; implements list/get/create/update/delete for collections, environments, requests by calling workspace and merging.
  - **ServerpodRelayApiClient**: Uses generated `relay_server_client`; can use an optional shared `Client` (with auth) from `serverpodClientProvider`.
- **`lib/core/services/relay_api/serverpod_client_provider.dart`**: `serverpodClientProvider` (FutureProvider.family by baseUrl) builds a Serverpod `Client` with `FlutterAuthSessionManager`, calls `client.auth.initialize()`, and returns it. Used so that all Serverpod RPC calls share the same authenticated client.
- **`lib/core/services/workspace_api/`**: `WorkspaceApiClient` (getWorkspace, putWorkspace). REST: `RestWorkspaceClient`. Serverpod: `ServerpodWorkspaceClient` (pullWorkspace/pushWorkspace RPC).

### 3. Repositories and Data Sources

- **Providers** (`lib/features/home/presentation/providers/repository_providers.dart`): `collectionDataSourceProvider`, `requestDataSourceProvider`, and `environmentRepositoryProvider` switch on data source mode and config: local → local data sources; API → remote data sources built from `_createRelayApiClient(config, serverpodClient)`. When API style is Serverpod, the shared client from `serverpodClientProvider(baseUrl)` is passed in so auth is applied.
- **Local data sources**: `CollectionLocalDataSource`, `RequestLocalDataSource` use `FileStorageService` and `WorkspaceService` (files under app documents directory).
- **Remote data sources**: `CollectionRemoteDataSource`, `RequestRemoteDataSource` wrap `RelayApiClient`. Environment repository has a remote impl that uses the same client.

### 4. Authentication (Client)

- **Sign-in screen**: `lib/features/auth/presentation/sign_in_screen.dart`. Shown when data source is API + Serverpod RPC. Watches `serverpodClientProvider(baseUrl)` and displays `EmailSignInWidget` (serverpod_auth_idp_flutter) with the shared client. On success, pops the screen; session is stored by `FlutterAuthSessionManager`.
- **Drawer**: When in API + Serverpod mode, a “Sign in” button opens the sign-in screen. Sync to remote (when in local mode) and all Serverpod RPC calls use the same client, so once signed in, requests are authenticated. See [04-AUTHENTICATION.md](04-AUTHENTICATION.md).

### 5. Sync to Remote

- **`lib/core/services/sync_to_remote_service.dart`**: Pushes local collections, requests, and environments to the configured remote. Used from the drawer when in local mode. Accepts an optional `serverpodClient` so that when the user has signed in and the config is Serverpod, sync uses the authenticated client.

### 6. Request Execution

- **Request runner**: Dio sends the HTTP request; URL, headers, and body support `{{variableName}}` substitution from the selected environment. Response and timing are shown in the UI. History is stored per request (local or via backend when in API mode, depending on where the request entity lives).

## Data Flow Examples

### Local mode: Load collections

1. User has mode = Local. `collectionDataSourceProvider` returns `CollectionLocalDataSource`.
2. `CollectionsNotifier` (or equivalent) calls repository → `CollectionLocalDataSource.getAllCollections()`.
3. Data is read from files via `FileStorageService` / `WorkspaceService`.

### API mode (Serverpod): Load collections after sign-in

1. User sets mode = API, style = Serverpod RPC, base URL. `serverpodClientProvider(baseUrl)` builds a `Client` with `FlutterAuthSessionManager` and `auth.initialize()`.
2. `collectionDataSourceProvider` watches that provider and passes the client into `ServerpodRelayApiClient(serverUrl: config.baseUrl, client: client)`.
3. Repository uses `CollectionRemoteDataSource(api)` where `api` is that relay client. List collections calls `client.collections.list()` with the same client that has the JWT attached by the auth session manager.

### Sync to remote (local → API)

1. User is in local mode; taps “Sync to remote” in the drawer. Drawer loads `DataSourceConfig` (and for Serverpod, awaits `serverpodClientProvider(config.baseUrl).future`).
2. `SyncToRemoteService.sync(config, ..., serverpodClient: client)` builds a `RelayApiClient` (REST or Serverpod with optional client) and pushes each local collection, request, and environment to the remote.
