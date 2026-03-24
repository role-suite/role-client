# 4. Authentication

Authentication in role-client is REST API key based.

## Overview

- Authentication is optional and only applies in `API` mode.
- Users provide an API key in the data source configuration dialog.
- The key is stored locally and attached as a Bearer token to backend requests.

## How It Works

1. User opens API configuration in the drawer.
2. User sets base URL and optional API key.
3. `DataSourcePreferencesService` persists this config.
4. `RestWorkspaceClient` includes `Authorization: Bearer <apiKey>` when key is set.

## Storage and Security

- API key is stored in `SharedPreferences` under `data_source_api_key`.
- Avoid logging or hardcoding API keys.
- Use HTTPS in production to protect credentials in transit.

## Code References

- `lib/core/models/data_source_config.dart`
- `lib/core/services/data_source_preferences_service.dart`
- `lib/core/services/workspace_api/rest_workspace_client.dart`
- `lib/features/home/presentation/widgets/dialogs/data_source_config_dialog.dart`
