# role-client Technical Documentation

This folder contains technical documentation for maintaining and operating the **role-client** project (Röle — the Flutter API testing app).

## Documentation Index

| Document | Description |
|----------|-------------|
| [01-OVERVIEW.md](01-OVERVIEW.md) | Project purpose, stack, and repository layout |
| [02-ARCHITECTURE.md](02-ARCHITECTURE.md) | App architecture, data flow, and data sources |
| [03-CONNECTING-TO-BACKEND.md](03-CONNECTING-TO-BACKEND.md) | Data source modes, API config, REST vs Serverpod RPC |
| [04-AUTHENTICATION.md](04-AUTHENTICATION.md) | Sign-in (email), Serverpod client auth, and session |
| [05-DATA-MODEL.md](05-DATA-MODEL.md) | App models, workspace bundle, and local storage |
| [06-CONFIGURATION.md](06-CONFIGURATION.md) | Preferences, data source config, and theme |
| [07-DEPLOYMENT.md](07-DEPLOYMENT.md) | Building for release and distribution |
| [08-DEVELOPMENT.md](08-DEVELOPMENT.md) | Local setup, running, and code layout |
| [09-MAINTENANCE.md](09-MAINTENANCE.md) | Extending the app and troubleshooting |

## Quick Links by Task

- **Run locally:** [08-DEVELOPMENT.md#running-the-app](08-DEVELOPMENT.md#running-the-app)
- **Configure API data source:** [03-CONNECTING-TO-BACKEND.md](03-CONNECTING-TO-BACKEND.md)
- **Sign in (email) with Serverpod:** [04-AUTHENTICATION.md](04-AUTHENTICATION.md)
- **Build release:** [07-DEPLOYMENT.md](07-DEPLOYMENT.md)
- **Add a new feature:** [09-MAINTENANCE.md](09-MAINTENANCE.md)

## Conventions

- **role-client** = this Git repository (Röle Flutter app).
- **role-server** = the backend (relay API server); see that repo’s `docs/` for server-side documentation.
- **Röle** = app name (Turkish for “Relay”).

All paths in the docs are relative to the **role-client** repository root unless stated otherwise.
