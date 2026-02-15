# 1. Project Overview

## Purpose

**role-client** (Röle) is a cross-platform API testing client built with Flutter. It provides:

- **Request editing and execution**: Compose and send HTTP requests (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS), view responses, and track history.
- **Collections and environments**: Organize requests into collections; use environments with variables (e.g. `{{baseUrl}}`) for URLs, headers, and bodies.
- **Dual data source**: Work with data **locally** (device storage) or from an **API** backend (role-server). In API mode, the app syncs collections, requests, and environments with the server via REST or Serverpod RPC.
- **Import/export**: Import Postman collections and environments; export the full workspace as JSON. Sync to remote when in local mode using the configured API.

The app does **not** host or run a server; it is a client that either reads/writes local files or talks to a configured role-server instance.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Dart 3.9+ (Flutter SDK) |
| UI | [Flutter](https://flutter.dev) (Material Design 3) |
| State | [Riverpod](https://riverpod.dev) 3.x |
| HTTP (requests) | [Dio](https://pub.dev/packages/dio) |
| Backend API | [Serverpod](https://serverpod.dev) client 3.2.x, [serverpod_auth_idp_flutter](https://pub.dev/packages/serverpod_auth_idp_flutter) for email sign-in |
| Local storage | [path_provider](https://pub.dev/packages/path_provider), [shared_preferences](https://pub.dev/packages/shared_preferences), file system (collections/requests/environments) |
| Backend protocol | [relay_server_client](https://github.com/...) (path dependency to role-server) |

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
│       ├── auth/           # Sign-in screen (email, Serverpod)
│       ├── home/            # Collections, requests, environments, request runner
│       ├── collection_runner/  # Run collections sequentially
│       └── request_chain/   # Request chains and config
├── assets/
├── pubspec.yaml
└── README.md
```

- **core**: Models, services (relay API, workspace API, sync, data source preferences), and shared UI. Relay/workspace clients abstract REST vs Serverpod RPC.
- **features**: Feature-based modules (auth, home, collection_runner, request_chain), each with data/domain/presentation where applicable.

## Key Concepts

- **Data source mode**: **Local** = read/write from device storage. **API** = use a remote backend (role-server); requires base URL and optionally API style (REST or Serverpod RPC) and API key (REST).
- **API style**: **REST** = single workspace via GET/PUT with optional API key. **Serverpod RPC** = CRUD endpoints plus optional email sign-in; uses a shared Serverpod client with `FlutterAuthSessionManager`.
- **Workspace**: The full set of collections (with their requests) and environments. In local mode it is stored as files; in API mode it is synced with the server (REST blob or RPC CRUD).
- **Sign-in**: When using Serverpod RPC, users can sign in with email (register, verify, login) so that requests are authenticated. See [04-AUTHENTICATION.md](04-AUTHENTICATION.md).
