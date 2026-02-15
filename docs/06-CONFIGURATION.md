# 6. Configuration

The app is configured through **in-app preferences** (persisted locally) and **compile-time constants**. There are no YAML or environment files for the Flutter app at runtime (except what the OS provides).

## Data Source Preferences

Stored via `DataSourcePreferencesService` (SharedPreferences). Keys:

| Key | Type | Description |
|-----|------|-------------|
| `data_source_mode` | String | `"local"` or `"api"`. |
| `data_source_api_base_url` | String | Base URL when mode is API. |
| `data_source_api_key` | String? | Optional API key (REST). |
| `data_source_api_style` | String | `"rest"` or `"serverpod"`. |

- **Load**: `DataSourcePreferencesService.loadMode()`, `loadConfig()`.
- **Save**: `saveMode(mode)`, `saveConfig(config)` (e.g. from the data source config dialog).

See [03-CONNECTING-TO-BACKEND.md](03-CONNECTING-TO-BACKEND.md) for how these are used.

## Theme

- **Theme mode** (light / dark / system) is stored via a theme notifier provider (e.g. `themeModeNotifierProvider` in `lib/features/home/presentation/providers/theme_providers.dart`). Implementation may use SharedPreferences or another persistent store so the choice survives restarts.
- **Themes** themselves are defined in `lib/core/theme/app_theme.dart` (e.g. `AppTheme.lightTheme`, `AppTheme.darkTheme`). `MaterialApp` in `main.dart` uses `themeMode` from the provider.

## App Constants

Defined in `lib/core/constants/app_constants.dart`. Used for defaults and UI text:

| Constant | Default | Description |
|----------|---------|-------------|
| `appName` | Röle | App display name. |
| `defaultConnectTimeout` | 15 s | HTTP connection timeout. |
| `defaultReceiveTimeout` | 30 s | HTTP receive timeout. |
| `maxHistoryEntriesPerRequest` | 20 | Max history entries per request. |
| `variableStart` / `variableEnd` | `{{` / `}}` | Environment variable syntax in URLs/headers/body. |
| `httpMethods` | GET, POST, … | Supported HTTP methods. |

Changing these requires a rebuild.

## Backend / Server

The app does not read server-side configuration. The **base URL** (and optional API key, API style) are entered by the user in the app and stored as above. The server must be run and configured separately (see role-server `docs/06-CONFIGURATION.md`).

## Platform

- **Paths**: Local workspace files use `path_provider` (e.g. `getApplicationDocumentsDirectory()`). No config file for paths.
- **Network**: Timeouts and behavior are controlled by Dio and the constants above; no separate network config file.
