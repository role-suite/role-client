# 1. Project Overview

## Purpose

**role-client** (Röle) is a cross-platform API testing client built with Flutter. It provides:

- **Request editing and execution**: Compose and send HTTP requests (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS), view responses, and track history.
- **Collections and environments**: Organize requests into collections; use environments with variables (e.g. `{{baseUrl}}`) for URLs, headers, and bodies.
- **Dual data source**: Work with data **locally** (device storage) or from an **API** backend (role-server). In API mode, the app syncs collections, requests, and environments with the server via REST.
- **Import/export**: Import Postman collections and environments; export the full workspace as JSON. Sync to remote when in local mode using the configured API.

The app does **not** host or run a server; it is a client that either reads/writes local files or talks to a configured role-server instance.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Dart 3.9+ (Flutter SDK) |
| UI | [Flutter](https://flutter.dev) (Material Design 3) |
| State | [Riverpod](https://riverpod.dev) 3.x |
| HTTP (requests) | [Dio](https://pub.dev/packages/dio) |
| Backend API | REST client built on [Dio](https://pub.dev/packages/dio) |
| Local storage | [path_provider](https://pub.dev/packages/path_provider), [shared_preferences](https://pub.dev/packages/shared_preferences), file system (collections/requests/environments) |

## Repository Layout

```
role-client/
├── docs/                    # This documentation
├── lib/
│   ├── main.dart           # App entry, ProviderScope, MaterialApp
│   ├── core/               # Shared code
│   │   ├── constants/      # ApiStyle, DataSourceMode, app constants
│   │   ├── models/         # DataSourceConfig, ApiRequestModel, CollectionModel, etc.
│   │   ├── services/       # Relay API clients, workspace API, sync, preferences
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

- **core**: Models, services (relay API, workspace API, sync, data source preferences), and shared UI.
- **features**: Feature-based modules (home, collection_runner, request_chain), each with data/domain/presentation where applicable.

## Key Concepts

- **Data source mode**: **Local** = read/write from device storage. **API** = use a remote backend (role-server); requires base URL and optionally API key.
- **Workspace**: The full set of collections (with their requests) and environments. In local mode it is stored as files; in API mode it is synced with the server via REST.
- **Authentication**: Optional API key authentication is configured in app settings. See [04-AUTHENTICATION.md](04-AUTHENTICATION.md).
