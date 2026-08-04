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
| `lib/main.dart` | Entrypoint, `ProviderScope`, `MaterialApp`, theme wiring |
| `lib/core/` | Constants, models, services, theme, utils, shared widgets/layout |
| `lib/features/home/` | Main UI and local collection/request/environment workflows |
| `lib/features/collection_runner/` | Collection runner feature |
| `lib/features/request_chain/` | Request chain feature |

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

## Analyze and Tests

```bash
flutter analyze
flutter test
```

Fix analyzer warnings before committing. Add or update tests when behavior changes.
