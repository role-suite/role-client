# 3. Connecting to the Backend

The app can use a remote role-server instance to store collections, requests, and environments.

## Data Source Modes

| Mode | Description |
|------|-------------|
| `Local` | Data is stored on device (files + `SharedPreferences`). |
| `API` | Data is read from and written to role-server over REST. |

Mode is selected in the drawer and persisted by `DataSourcePreferencesService`.

## API Configuration

When using API mode, configure:

1. **Base URL**: server root, for example `http://localhost:8082`
2. **API key** (optional): sent as Bearer token when server requires it

Configuration is edited from the drawer via `DataSourceConfigDialog` and saved through `DataSourcePreferencesService.saveConfig()`.

## REST Behavior

- Base URL must be non-empty (`baseUrl.trim().isNotEmpty`).
- Workspace is loaded with GET `/workspace`.
- Workspace updates are sent with PUT `/workspace`.
- If `apiKey` is set, requests include `Authorization: Bearer <apiKey>`.

## Code References

- Config model: `lib/core/models/data_source_config.dart`
- Data source mode: `lib/core/constants/data_source_mode.dart`
- Config persistence: `lib/core/services/data_source_preferences_service.dart`
- API config UI: `lib/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart`
- Drawer integration: `lib/features/home/presentation/widgets/home_drawer.dart`
