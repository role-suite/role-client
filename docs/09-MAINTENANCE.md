# 9. Maintenance and Operations

## Adding a New Feature (Feature Module)

1. Create a folder under `lib/features/<feature_name>/` with subfolders as needed: `data/`, `domain/`, `presentation/`.
2. **data**: Data sources (local/remote), repository implementations. Follow the pattern of `home`: e.g. `*_local_data_source.dart`, `*_remote_data_source.dart`, `*_repository_impl.dart`.
3. **domain**: Repository interfaces (abstract classes), use cases if needed. Keep domain independent of Flutter and external packages where possible.
4. **presentation**: Screens, widgets, Riverpod providers. Use `ConsumerWidget` or `ConsumerStatefulWidget` and `ref.watch` / `ref.read` for providers.
5. Register navigation (e.g. new route or push from drawer) in the appropriate place (e.g. `home_screen.dart` or drawer).
6. Add tests and update docs (e.g. [01-OVERVIEW.md](01-OVERVIEW.md), [02-ARCHITECTURE.md](02-ARCHITECTURE.md)) if the feature is user-facing or architectural.

### Riverpod checklist for new features

- Add dependency providers with `Provider` (services/repositories/use-cases).
- Add state owners with `NotifierProvider` / `AsyncNotifierProvider` (avoid `StateNotifierProvider`).
- Keep async UI state as `AsyncValue` instead of manual loading/error flags.
- Add derived providers for view shaping instead of doing filter/map logic directly in widgets.
- Ensure provider overrides are straightforward in tests.

## Adding a New Data Source or API Client

- **New backend type**: If you add another API style (e.g. GraphQL), extend `ApiStyle` in `lib/core/constants/api_style.dart`, add a new branch in `_createRelayApiClient` in `repository_providers.dart`, and implement a new `RelayApiClient` (and optionally `WorkspaceApiClient`) in `lib/core/services/`. Wire the new style in `DataSourceConfig` and the data source config dialog.
- **New endpoint usage**: If the Serverpod server adds endpoints, regenerate the client (`dart run serverpod generate` in role-server), then call the new endpoint from the appropriate service or repository (e.g. a new method on `ServerpodRelayApiClient` or a dedicated service).

## Changing the Data Model

- **App-only models** (e.g. in `lib/core/models/`): Update the class, `toJson`/`fromJson`, and all call sites. If the format is used for import/export or sync, ensure the workspace bundle version or format is documented and, if necessary, bumped (see `WorkspaceBundle.currentVersion`).
- **Models shared with server**: If the server protocol changes (e.g. new fields in `CollectionModel`), update the server first, regenerate `relay_server_client`, then update the app’s mapping in `ServerpodRelayApiClient` and any app-side models that mirror the protocol. Keep local storage format compatible or add a migration path for existing files.

## Authentication Changes

- **Current auth provider flow**:
  - availability/client: `serverpodSignInAvailabilityProvider`, `serverpodSignInClientProvider`
  - sign-in view state: `serverpodSignInUiStateProvider`
  - session state: `serverpodAuthSessionStateProvider`
  - sign-out action: `signOutServerpodCurrentDeviceProvider`
- **Add sign-out**: Prefer wiring through `signOutServerpodCurrentDeviceProvider` so sign-out behavior stays centralized and testable.
- **Another IdP**: If the server adds another identity provider (e.g. Google), add the corresponding Flutter package and UI (e.g. a button that triggers that flow). The shared client’s `authSessionManager` may already support multiple providers depending on Serverpod auth setup; follow the package docs.

## Provider Regression Checks

When changing provider graphs or notifier logic:

1. Run `flutter analyze` and resolve all provider/lint findings.
2. Run `flutter test` (provider unit tests + widget tests).
3. Verify no `flutter_riverpod/legacy.dart` imports were introduced.
4. Verify key flows manually:
   - local/API data source switching
   - sign-in availability and sign-out action
   - collection/request/environment CRUD refresh behavior

## Troubleshooting

### App won’t build: relay_server_client not found

- If using default standalone setup, ensure `pubspec.yaml` points to a resolvable remote source (package version or public git ref).
- If using local contributor override, verify your `pubspec_overrides.yaml` path is correct (e.g. `../role-server/relay_server_client`).
- From the server package (only when regenerating client), run `dart pub get` and `dart run serverpod generate`.

### “Could not connect to server” or RPC errors when using API mode

- Verify the backend is running and reachable (e.g. `curl http://localhost:8082/workspace` or the Serverpod port).
- Check base URL in the app (no trailing path like `/workspace` for the base URL; use the server root).
- For Serverpod RPC, ensure the base URL points to the Serverpod API server (e.g. 8080) if that’s what the client is configured to use.
- If the server requires API key (REST) or sign-in (Serverpod), ensure the app is configured or signed in.

### Data source mode or API config not persisting

- Preferences are stored via `SharedPreferences`. On some platforms or after reinstall, they may be cleared. Check that `DataSourcePreferencesService.saveConfig` / `saveMode` are called after user changes (e.g. in the config dialog and when switching mode in the drawer).

### Sign-in screen shows “Switch to API mode…” but I’m already in API mode

- Ensure API style is **Serverpod RPC** (not REST) and base URL is non-empty. The sign-in screen is only relevant for Serverpod RPC; for REST, auth is via API key in the config dialog.

## Updating Dependencies

- **Flutter**: Upgrade following [flutter.dev](https://flutter.dev) guidance. Run `flutter pub get` and `flutter analyze` after upgrading.
- **relay_server_client**:
  - normal path: bump package version or git ref when server protocol/endpoints change.
  - contributor path: use local `pubspec_overrides.yaml` to test unreleased protocol changes.
  - after updates, run `flutter pub get`, `flutter analyze`, and `flutter test`.
- **serverpod_* / dio / riverpod**: Check changelogs for breaking changes. Update usages (e.g. provider APIs, auth APIs) and run tests.
