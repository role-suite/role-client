# 9. Maintenance and Operations

## Adding a New Feature

1. Create `lib/features/<feature_name>/` with `data/`, `domain/`, and `presentation/` as needed.
2. Keep repository interfaces in domain and implementations in data.
3. Add provider wiring in presentation.
4. Add tests and update docs for user-facing or architectural changes.

## Riverpod Checklist

- Use `Provider` for dependencies.
- Use `NotifierProvider` / `AsyncNotifierProvider` for state.
- Keep async UI state in `AsyncValue`.
- Ensure provider overrides are test-friendly.

## Extending API Integration

- For new backend behavior, update `RelayApiClient` and `RestRelayApiClient`.
- Update data sources/repositories to consume new client methods.
- Keep `DataSourceConfig` and config dialog aligned with runtime requirements.

## Changing the Data Model

- Update model classes and JSON mapping in `lib/core/models/`.
- Update import/export and sync behavior when schema changes.
- Keep local storage compatibility in mind or add migration logic.

## Provider Regression Checks

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Verify local/API switching.
4. Verify collection/request/environment CRUD refresh behavior.

## Troubleshooting

### Could not connect to backend in API mode

- Ensure role-server is running and reachable (`curl http://localhost:8082/workspace`).
- Ensure base URL is correct and does not include `/workspace`.
- If server requires auth, ensure API key is configured.

### Data source config not persisting

- Verify `DataSourcePreferencesService.saveConfig` and `saveMode` are called after user changes.

## Updating Dependencies

- After dependency updates, run:

```bash
flutter pub get
flutter analyze
flutter test
```
