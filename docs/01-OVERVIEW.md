# 1. Project Overview

## Purpose

**role-client** (Röle) is a cross-platform, local-only API testing client built with Flutter. It provides:

- **Request editing and execution**: Compose and send HTTP requests (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS), view responses, and track history.
- **Collections and environments**: Organize requests into collections; use environments with variables (e.g. `{{baseUrl}}`) for URLs, headers, and bodies.
- **Local storage**: All collections, requests, and environments are stored on-device. There is no account, no sign-in, and no backend server.
- **Import/export**: Import Postman collections and environments; export the full workspace as JSON.

The app does not connect to any backend service. Everything you create lives on your device.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Dart 3.9+ (Flutter SDK) |
| UI | [Flutter](https://flutter.dev) (Material Design 3) |
| State | [Riverpod](https://riverpod.dev) 3.x |
| HTTP (requests) | [Dio](https://pub.dev/packages/dio) |
| Local storage | [path_provider](https://pub.dev/packages/path_provider), [shared_preferences](https://pub.dev/packages/shared_preferences), file system (collections/requests/environments) |

## Repository Layout

```
role-client/
├── docs/                    # This documentation
├── lib/
│   ├── main.dart           # App entry, ProviderScope, MaterialApp
│   ├── core/               # Shared code
│   │   ├── constants/      # App constants
│   │   ├── models/         # ApiRequestModel, CollectionModel, etc.
│   │   ├── services/       # Local storage, workspace, import/export, HTTP client
│   │   ├── theme/          # App theme (light/dark)
│   │   ├── utils/          # Logger, UUID, request helpers
│   │   └── presentation/   # Shared layout and widgets
│   └── features/
│       ├── home/            # Collections, requests, environments, request runner
│       ├── collection_runner/  # Run collections sequentially
│       └── request_chain/   # Request chains and config
├── assets/
├── pubspec.yaml
└── README.md
```

- **core**: Models, services (local storage, workspace import/export), and shared UI.
- **features**: Feature-based modules (home, collection_runner, request_chain), each with data/domain/presentation where applicable.

## Key Concepts

- **Workspace**: The full set of collections (with their requests) and environments, stored as files on-device.
- **No accounts, no sync**: There is no authentication, no remote data source, and no team/workspace-sharing functionality.
