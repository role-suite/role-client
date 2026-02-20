# 8. Development

## Prerequisites

- **Flutter SDK** 3.9+ ([flutter.dev](https://flutter.dev)).
- **Dart** 3.9+ (included with Flutter).
- **role-server** (for `relay_server_client`): The app depends on the generated client via a path dependency. Clone or open the role-server repo so that the path in `pubspec.yaml` (e.g. `../role-server/relay_server_client`) resolves. If the server protocol or endpoints change, run `dart run serverpod generate` (and any migrations) from the server package, then return to the client.

## Local Setup

1. **Clone and open the client:**

   ```bash
   cd role-client
   ```

2. **Ensure the Serverpod client is available:**

   ```bash
   # From role-client root; adjust path if your role-server is elsewhere
  ls ../role-server/relay_server_client
   ```

   If the server is in a different location, edit `pubspec.yaml` and set the correct path under `relay_server_client`.

3. **Install dependencies:**

   ```bash
   flutter pub get
   ```

4. **Run the app:**

   ```bash
   flutter run -d macos   # or windows, linux, android, ios
   ```

   Pick a device with `flutter devices` if needed.

## Running the App

- **Desktop**: `flutter run -d macos`, `flutter run -d windows`, `flutter run -d linux`.
- **Mobile**: `flutter run -d android`, `flutter run -d ios` (iOS requires a Mac).
- **Web**: `flutter run -d chrome` (if the project supports web; not all features may be tested on web).

Hot reload is available during development. State (e.g. data source mode, theme) is persisted, so restarting the app keeps user choices.

## Code Layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entrypoint, `ProviderScope`, `MaterialApp`, theme from provider. |
| `lib/core/` | Constants, models, services (relay API, workspace API, sync, preferences), theme, utils, shared widgets/layout. |
| `lib/features/auth/` | Sign-in screen (email, Serverpod). |
| `lib/features/home/` | Home screen, collections, requests, environments, request runner, drawer, dialogs, providers, repositories, data sources. |
| `lib/features/collection_runner/` | Run collections sequentially. |
| `lib/features/request_chain/` | Request chains and configuration. |

Within a feature:

- **data**: Data sources (local/remote), repository implementations.
- **domain**: Repository interfaces, use cases, domain models if any.
- **presentation**: Screens, widgets, providers, controllers.

## Key Packages

- **flutter_riverpod**: State and dependency injection (providers).
- **relay_server_client**: Generated Serverpod client (path to role-server).
- **serverpod_flutter**: Serverpod Flutter utilities (e.g. connectivity monitor).
- **serverpod_auth_idp_flutter**: Email sign-in UI and session manager.
- **dio**: HTTP client for sending API requests and for REST workspace client.
- **shared_preferences**: Data source and theme preferences.
- **path_provider**: Local file paths for workspace storage.

## Analyze and Tests

```bash
flutter analyze
flutter test
```

Fix analyzer issues before committing. Add or update tests when changing behavior.

## Connecting to a Local Backend

1. Start role-server (see role-server `docs/08-DEVELOPMENT.md`). For example, in-memory: from `relay_server_server/`, `dart bin/main.dart` (with development_local config). With DB: start Postgres/Redis, apply migrations, then run the server.
2. In the app, open the drawer, switch to **API** mode, set **base URL** (e.g. `http://localhost:8082` for web server or `http://localhost:8080` for Serverpod API, depending on how your client is configured), choose REST or Serverpod RPC, and optionally set API key (REST) or sign in (Serverpod).
3. Collections, requests, and environments will then be loaded from and saved to the server.
