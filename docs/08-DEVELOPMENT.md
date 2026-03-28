# 8. Development

## Prerequisites

- Flutter SDK 3.9+ ([flutter.dev](https://flutter.dev))
- Dart 3.9+ (included with Flutter)
- role-server is optional unless you want to test API mode locally

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
| `lib/features/home/` | Main UI and data-source workflows |
| `lib/features/collection_runner/` | Collection runner feature |
| `lib/features/request_chain/` | Request chain feature |

## Key Packages

- `flutter_riverpod`: state and dependency injection
- `dio`: HTTP for request execution and workspace REST sync
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

## Connecting to a Local Backend

1. Start role-server.
2. In app drawer, switch to `API` mode.
3. Configure base URL (for example `http://localhost:8082`) and optional API key.
4. Collections, requests, and environments are then loaded from and saved to role-server over REST.
