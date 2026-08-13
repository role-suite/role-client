# 6. Development

## Prerequisites

- Flutter SDK 3.9+ ([flutter.dev](https://flutter.dev))
- Dart 3.9+ (included with Flutter)

## Local Setup

1. Open the repository:

   ```bash
   cd role-client
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run -d macos   # or windows, linux, android, ios
   ```

## Code Layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entrypoint: inits `SharedPreferences`, runs `ProviderScope` |
| `lib/app.dart` | `MaterialApp` + theme wiring |
| `lib/core/` | Models, local JSON storage, HTTP execution (`network/`), import/export (`io/`), theme, utils, constants |
| `lib/state/` | Riverpod notifiers — workspace, environments, history, runs, flows, settings, workbench UI state. This is the data/business-logic layer; there is no separate repository/usecase layer. |
| `lib/ui/` | Widgets, organized by workbench section: `shell/`, `sidebar/`, `request/`, `environments/`, `history/`, `runner/`, `flows/`, `widgets/` |

See [02-ARCHITECTURE.md](02-ARCHITECTURE.md) for the full architecture writeup.

## Key Packages

- `flutter_riverpod`: state and dependency injection
- `dio`: HTTP for request execution
- `shared_preferences`: persistent app preferences
- `path_provider`: local storage paths

## Riverpod Development Standard

- Prefer `Provider` for pure dependencies.
- Prefer `NotifierProvider` for synchronous mutable state.
- Prefer `AsyncNotifierProvider` for asynchronous state.
- Avoid legacy Riverpod APIs.
- Keep provider orchestration out of widgets where possible.

## Formatting, Analysis, and Tests

```bash
dart format .
flutter analyze
flutter test
```

Fix analyzer warnings before committing. Add or update tests when behavior changes.
`.editorconfig` at the repo root keeps indentation/line-ending/charset consistent across
editors; `analysis_options.yaml` configures the analyzer and linter (including
`custom_lint`/`riverpod_lint`).

## Continuous Integration

Every push/PR to `main` runs (see `.github/workflows/`):

- **`ci.yml`**: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`
- **`build-check.yml`**: compile-only builds for macOS, Windows, and Linux
- **`pr-title.yml`**: enforces a Conventional Commit-style PR title

Pushing a `v*.*.*` tag triggers `release.yml`, which builds and publishes signed macOS,
Windows, and Linux artifacts to a GitHub Release. Android and iOS are distributed through
their app stores and are not built by this pipeline. See `.github/workflows/README.md` for
required release secrets.
