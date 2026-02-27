# 8. Development

## Prerequisites

- **Flutter SDK** 3.9+ ([flutter.dev](https://flutter.dev)).
- **Dart** 3.9+ (included with Flutter).
- `role-server` is **optional** for normal client development/build.
  - Required only when you want to regenerate `relay_server_client` from server protocol changes.

## Local Setup

1. **Clone and open the client:**

   ```bash
   cd role-client
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Run the app:**

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
- **relay_server_client**: Generated Serverpod client (resolved via pinned remote source by default; local override optional).
- **serverpod_flutter**: Serverpod Flutter utilities (e.g. connectivity monitor).
- **serverpod_auth_idp_flutter**: Email sign-in UI and session manager.
- **dio**: HTTP client for sending API requests and for REST workspace client.
- **shared_preferences**: Data source and theme preferences.
- **path_provider**: Local file paths for workspace storage.

## Riverpod Development Standard

This project uses modern Riverpod APIs (no legacy imports/patterns).

- Prefer `Provider` for pure dependencies (services, repositories, use cases).
- Prefer `NotifierProvider` for synchronous mutable state.
- Prefer `AsyncNotifierProvider` for asynchronous state (collections, requests, environments, data source config, auth session).
- Do not import `flutter_riverpod/legacy.dart`.
- Keep provider logic in provider/notifier files; avoid orchestration-heavy widgets.
- Use derived providers for UI transformations (for example request filtering) instead of recomputing in widgets.

### Provider naming and organization

- Keep providers close to the feature under `lib/features/<feature>/presentation/providers/`.
- Use clear suffixes:
  - `...Provider` for dependency/derived providers
  - `...NotifierProvider` for state owners
- Keep provider dependencies explicit and override-friendly for tests.

### UI usage conventions

- Use `ref.watch(...)` for render state.
- Use `ref.read(...)` for user-triggered actions (button taps, commands).
- Use `ref.listen(...)` only for side effects (snackbars, dialogs, navigation).
- Minimize repeated nested watches in leaf widgets; watch once higher in the tree and pass data down.

### Auth provider conventions

- `serverpodSignInAvailabilityProvider`: whether sign-in is possible from current data source config.
- `serverpodSignInClientProvider`: resolves Serverpod client for sign-in flow.
- `serverpodSignInUiStateProvider`: UI-ready sign-in state.
- `serverpodAuthSessionStateProvider`: signed-in vs signed-out session state for drawer/actions.

## Riverpod Testing Patterns

- Unit-test providers/notifiers with `ProviderContainer` and provider overrides.
- Use in-memory fake repositories for domain-heavy async notifier tests.
- Widget tests must run under `ProviderScope` via `test/test_helpers/pump_app.dart`.
- Keep at least one test per critical provider path:
  - success path
  - loading path (if async)
  - error path
  - override behavior where applicable

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

## Optional: Local `role-server` Override for Contributors

If you are developing both repos together and want to test a locally generated `relay_server_client`, create an untracked `pubspec_overrides.yaml` in the client root:

```yaml
dependency_overrides:
  relay_server_client:
    path: ../role-server/relay_server_client
```

You can copy from `pubspec_overrides.yaml.example` and rename it to `pubspec_overrides.yaml`.
Do not commit your local `pubspec_overrides.yaml`.
