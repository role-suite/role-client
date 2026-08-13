# 7. Maintenance and Operations

## Adding a New Feature

There is no `features/<name>/data|domain|presentation` split — Röle is local-only, and a
Riverpod notifier over `JsonStore` already is the data/business-logic layer. To add a
feature:

1. **Model** (if it introduces new persisted data): add a class under `lib/core/models/`,
   plus JSON `toJson`/`fromJson`. Update `lib/core/models/workspace_bundle.dart` and
   `lib/core/io/workspace_io.dart` if it needs to be included in import/export.
2. **State**: add or extend a `Notifier`/`AsyncNotifier` in `lib/state/`, reading/writing
   through `JsonStore` (`lib/core/storage/json_store.dart`).
3. **UI**: add widgets under `lib/ui/<section>/`. If it's a new workbench section, wire it
   into `WorkspaceSection`, the left rail (`ui/shell/side_rail.dart`), and the sidebar
   dispatch (`ui/shell/sidebar_panel.dart`); if it's a new tab kind, wire it into
   `ui/shell/workbench_tab_content.dart`.
4. Add tests and update [docs/](.) for user-facing or architectural changes.

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

1. Run `dart format --output=none --set-exit-if-changed .`.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Verify collection/request/environment CRUD refresh behavior.

These same checks run in CI on every push/PR (`.github/workflows/ci.yml`).

## Updating Dependencies

- After dependency updates, run:

```bash
flutter pub get
flutter analyze
flutter test
```
