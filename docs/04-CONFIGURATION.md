# 4. Configuration

The app is configured through **in-app preferences** (persisted locally) and **compile-time constants**. There are no YAML or environment files for the Flutter app at runtime (except what the OS provides), and there is no backend or account configuration.

## Theme

- **Theme mode** (light / dark / system) is stored via `themeModeProvider` (`lib/state/settings_providers.dart`), persisted via `SharedPreferences` so the choice survives restarts. Defaults to dark.
- **Design system** lives in `lib/core/theme/`: `app_colors.dart` (neutral scale + semantic method/status colors), `app_tokens.dart` (spacing/radius/sizing), `app_typography.dart` (sans for chrome, monospace for URLs/headers/bodies), assembled into `ThemeData` in `app_theme.dart`. `RoleApp` (`lib/app.dart`) wires `themeModeProvider` into `MaterialApp`.

## App Constants

Defined in `lib/core/constants.dart`:

| Constant | Default | Description |
|----------|---------|-------------|
| `appName` | Röle | App display name. |
| `defaultConnectTimeout` | 15 s | HTTP connection timeout. |
| `defaultReceiveTimeout` | 30 s | HTTP receive timeout. |
| `maxHistoryEntriesPerRequest` | 20 | Max history entries per request. |
| `defaultCollectionId` | `default` | Id of the seeded first collection. |

Changing these requires a rebuild. Variable syntax (`{{name}}`) is a fixed regex in `lib/core/network/template_resolver.dart`, not a constant.

## Platform

- **Paths**: Workspace files live under `path_provider`'s `getApplicationSupportDirectory()` (see `lib/core/storage/json_store.dart`). No config file for paths.
- **Network**: Timeouts and behavior are controlled by Dio (`lib/core/network/http_client.dart`) and the constants above; no separate network config file.
- **File access**: Import/export uses `file_picker`'s native save/open dialogs. On macOS this requires the sandbox entitlements `com.apple.security.files.user-selected.read-write` and `com.apple.security.files.downloads.read-write` (see `macos/Runner/*.entitlements`).
