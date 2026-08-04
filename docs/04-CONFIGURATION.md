# 4. Configuration

The app is configured through **in-app preferences** (persisted locally) and **compile-time constants**. There are no YAML or environment files for the Flutter app at runtime (except what the OS provides), and there is no backend or account configuration.

## Theme

- **Theme mode** (light / dark / system) is stored via a theme notifier provider (e.g. `themeModeNotifierProvider` in `lib/features/home/presentation/providers/theme_providers.dart`), persisted via `SharedPreferences` so the choice survives restarts.
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

## Platform

- **Paths**: Local workspace files use `path_provider` (e.g. `getApplicationDocumentsDirectory()`). No config file for paths.
- **Network**: Timeouts and behavior are controlled by Dio and the constants above; no separate network config file.
