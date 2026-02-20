# 3. Connecting to the Backend

The app can use a remote backend (role-server) as the data source for collections, requests, and environments. This document describes how to configure and use it.

## Data Source Mode

| Mode | Description |
|------|-------------|
| **Local** | Data is stored on the device (files + SharedPreferences). No server required. |
| **API** | Data is read from and written to a role-server instance. Requires a valid base URL and, for REST, optionally an API key. |

Mode is selected in the **drawer** (filter chips “Local” / “API”). The choice is persisted via `DataSourcePreferencesService` (SharedPreferences keys: `data_source_mode`, `data_source_api_base_url`, `data_source_api_key`, `data_source_api_style`).

## API Configuration

When in **API** mode, the user must configure:

1. **Base URL** — The root URL of the server (e.g. `http://localhost:8082` for the role-server web server, or `http://localhost:8080` for Serverpod API if the client talks to the API server directly). The app typically uses the **web server** URL (e.g. `http://localhost:8082`) so that a single base URL works for both REST and Serverpod (Serverpod client can use the same host with a different path). In practice, for Serverpod RPC the generated client uses the given base URL as the host; ensure it points to the Serverpod API server (e.g. `http://localhost:8080`) if your server exposes RPC there, or the web server if it proxies. See role-server docs for ports.
2. **API style** — **REST** or **Serverpod RPC**.
3. **API key** (REST only) — Optional Bearer token when the server has `RELAY_API_KEYS` set. Ignored for Serverpod RPC (auth is email or none).

Configuration is edited via the drawer: “Configure API” / “Change API URL” opens `DataSourceConfigDialog`, which saves via `DataSourcePreferencesService.saveConfig()`.

## REST vs Serverpod RPC

| Aspect | REST | Serverpod RPC |
|--------|------|----------------|
| **Protocol** | HTTP GET/PUT `/workspace` (single JSON blob) | Serverpod RPC: `pullWorkspace`/`pushWorkspace`, and CRUD for collections, requests, environments |
| **Auth** | Optional API key: `Authorization: Bearer <key>` | Optional email sign-in (JWT). Shared client built with `FlutterAuthSessionManager`. |
| **Client** | `RestWorkspaceClient` + `RestRelayApiClient` | `ServerpodWorkspaceClient` + `ServerpodRelayApiClient`; optional shared `Client` from `serverpodClientProvider` |
| **When to use** | Simple integration, single workspace blob | Fine-grained CRUD, email login, same protocol as Serverpod backend |

The app uses **one** of these at a time based on `DataSourceConfig.apiStyle` (saved as `data_source_api_style`).

## Base URL and Validation

- **Valid config**: `baseUrl.trim().isNotEmpty`. Trailing slashes are normalized when building clients.
- **REST**: Base URL is the web server root (e.g. `http://localhost:8082`). Workspace is fetched with GET `/workspace` and updated with PUT `/workspace`.
- **Serverpod**: Base URL must point to the Serverpod server (API or web, depending on how the client is generated). The shared client is created once per base URL and reused for all RPC and auth.

## Code References

- **Config model**: `lib/core/models/data_source_config.dart` — `DataSourceConfig(baseUrl, apiKey, apiStyle)`.
- **Constants**: `lib/core/constants/api_style.dart` (e.g. `ApiStyle.rest`, `ApiStyle.serverpod`), `lib/core/constants/data_source_mode.dart`.
- **Persistence**: `lib/core/services/data_source_preferences_service.dart`.
- **UI**: `lib/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart`, drawer section in `lib/features/home/presentation/widgets/home_drawer.dart`.
