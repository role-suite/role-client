# 7. Maintenance and Operations

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

## Changing the Data Model

- Update model classes and JSON mapping in `lib/core/models/`.
- Update import/export and sync behavior when schema changes.
- Keep local storage compatibility in mind or add migration logic.

## Provider Regression Checks

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Verify collection/request/environment CRUD refresh behavior.

## Updating Dependencies

- After dependency updates, run:

```bash
flutter pub get
flutter analyze
flutter test
```
