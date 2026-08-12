# 1. Project Overview

## Purpose

**role-client** (Röle) is a cross-platform, local-only API testing client built with Flutter. It provides:

- **Request editing and execution**: Compose and send HTTP requests (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS), view responses, and track history.
- **Collections and environments**: Organize requests into collections; use environments with variables (e.g. `{{baseUrl}}`) for URLs, headers, and bodies.
- **Collection Runner**: Run every request in a collection sequentially and inspect pass/fail run reports.
- **Flows**: Chain requests together sequentially, optionally passing the previous response into the next request.
- **Local storage**: All collections, requests, environments, history, runs, and flows are stored on-device as JSON. There is no account, no sign-in, and no backend server.
- **Import/export**: Import Postman v2.x collections and environments, or a Röle workspace bundle; export the full workspace as JSON.

The app does not connect to any backend service. Everything you create lives on your device.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Runtime | Dart 3.9+ (Flutter SDK) |
| UI | [Flutter](https://flutter.dev), custom tool-grade design system (not stock Material) |
| State | [Riverpod](https://riverpod.dev) 3.x (`Notifier`/`AsyncNotifier`, no code generation) |
| HTTP (requests) | [Dio](https://pub.dev/packages/dio) |
| Local storage | [path_provider](https://pub.dev/packages/path_provider) for the workspace directory, [shared_preferences](https://pub.dev/packages/shared_preferences) for small settings |
| Import/export | [file_picker](https://pub.dev/packages/file_picker) native save/open dialogs |

## Repository Layout

```
role-client/
├── docs/                    # This documentation
├── lib/
│   ├── main.dart            # Entry point: inits SharedPreferences, runs ProviderScope
│   ├── app.dart              # MaterialApp + theme wiring
│   ├── core/
│   │   ├── constants.dart    # App-wide constants
│   │   ├── models/           # ApiRequest, Collection, Environment, RequestResult, ...
│   │   ├── storage/          # JsonStore — local JSON persistence under the workspace dir
│   │   ├── network/          # HttpClient (Dio wrapper), TemplateResolver, RequestRunner
│   │   ├── io/                # Workspace export + Röle/Postman import
│   │   ├── theme/             # Design tokens, colors, typography, ThemeData assembly
│   │   └── utils/
│   ├── state/                # Riverpod notifiers (workspace, environments, history,
│   │                          # runs, flows, settings, workbench UI state)
│   └── ui/
│       ├── shell/             # Persistent desktop shell: top bar, rail, sidebar,
│       │                      # tabbed workbench, inspector, status bar, mobile shell
│       ├── sidebar/            # Requests/collections sidebar panel
│       ├── request/            # Request tab: method/url bar, editor, response viewer
│       ├── environments/       # Environment sidebar panel + editor tab
│       ├── history/             # History sidebar panel + snapshot viewer
│       ├── runner/              # Collection runner setup + run report tabs
│       ├── flows/               # Flow (request chain) editor + sidebar panel
│       └── widgets/             # Shared design-system widgets
├── assets/
├── pubspec.yaml
└── README.md
```

- **core**: Models, local persistence, HTTP execution, import/export, theme.
- **state**: All app state as Riverpod notifiers — no separate repository/usecase layers, since a local-only app doesn't need them.
- **ui**: Feature UI, organized by the workbench section it belongs to.

## Key Concepts

- **Workspace**: The full set of collections (with their requests), environments, history, run reports, and flows, stored as JSON files on-device under the app's support directory.
- **No accounts, no sync**: There is no authentication, no remote data source, and no team/workspace-sharing functionality.
