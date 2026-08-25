# role-client Technical Documentation

This folder contains technical documentation for maintaining and operating the **role-client** project (Röle — the local-only Flutter API testing app).

## Documentation Index

| Document | Description |
|----------|-------------|
| [01-OVERVIEW.md](01-OVERVIEW.md) | Project purpose, stack, and repository layout |
| [02-ARCHITECTURE.md](02-ARCHITECTURE.md) | App architecture and data flow |
| [03-DATA-MODEL.md](03-DATA-MODEL.md) | App models, workspace bundle, and local storage |
| [04-CONFIGURATION.md](04-CONFIGURATION.md) | Preferences and theme configuration |
| [05-DEPLOYMENT.md](05-DEPLOYMENT.md) | Building for release and distribution |
| [06-DEVELOPMENT.md](06-DEVELOPMENT.md) | Local setup, running, and code layout |
| [07-MAINTENANCE.md](07-MAINTENANCE.md) | Extending the app and troubleshooting |
| [08-ONLINE-MODE-INTEGRATION.md](08-ONLINE-MODE-INTEGRATION.md) | Integrating role-node as an optional, additive team-sync layer |

## Quick Links by Task

- **Run locally:** [06-DEVELOPMENT.md](06-DEVELOPMENT.md)
- **Build release:** [05-DEPLOYMENT.md](05-DEPLOYMENT.md)
- **Add a new feature:** [07-MAINTENANCE.md](07-MAINTENANCE.md)
- **Build online/team-sync mode (role-node integration):** [08-ONLINE-MODE-INTEGRATION.md](08-ONLINE-MODE-INTEGRATION.md)

## Conventions

- **role-client** = this Git repository (Röle Flutter app).
- **Röle** = app name (Turkish for "Relay").
- The app is fully local: there is no backend, no accounts, and no sync.

All paths in the docs are relative to the **role-client** repository root unless stated otherwise.
