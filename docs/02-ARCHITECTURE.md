# 2. Architecture

## High-Level Flow

```
UI (shell, workbench tabs, sidebar panels, dialogs)
  -> Riverpod notifiers (lib/state/)
  -> JsonStore (lib/core/storage/)
  -> local JSON files under the app support directory
```

Requests additionally flow through `RequestRunner` (`lib/core/network/`), which resolves
`{{variables}}`, builds the wire request, sends it via `HttpClient` (a thin Dio wrapper),
and times the round trip.

## App Shell

Röle is one persistent shell, not a stack of routes:

- **Top bar** (`ui/shell/top_bar.dart`): app mark, search, active-environment switcher, import/export, theme toggle.
- **Left rail** (`ui/shell/side_rail.dart`): switches the active `WorkspaceSection` (requests/history/runs/flows/environments).
- **Sidebar panel** (`ui/shell/sidebar_panel.dart`): renders the panel for the active section (e.g. `ui/sidebar/requests_sidebar_panel.dart`). The history and runs panels page their lists client-side (`AppConstants.historyPageSize`/`runHistoryPageSize`) rather than rendering every stored entry at once.
- **Workbench** (`ui/shell/workbench.dart`): a tab strip + the active tab's content, dispatched via `ui/shell/workbench_tab_content.dart`.
- **Inspector** (`ui/shell/inspector_panel.dart`): contextual detail panel for the active tab (variables used, metadata, recent history for a request tab).
- **Status bar** (`ui/shell/status_bar.dart`): local-only indicator, active environment.

On narrow screens, `ui/shell/mobile_shell.dart` replaces this with a bottom-nav shell that
pushes each opened item as a full-screen route instead of a workbench tab.

All shell/workbench UI state (open tabs, active tab, active section, sidebar width,
inspector visibility, search query) lives in `WorkbenchNotifier` (`lib/state/workbench_notifier.dart`),
not in the widgets themselves.

## Data Layer

- `lib/state/workspace_notifier.dart`: owns collections + requests. Each collection is
  persisted as one JSON file (`workspace/collections/<id>.json`) holding both the
  collection's metadata and its requests.
- `lib/state/environments_notifier.dart`: environments, one JSON file per environment.
- `lib/state/history_notifier.dart`: response snapshots (metadata in memory/JSON list,
  body in a separate per-snapshot file, hydrated on demand), capped per-request at
  `AppConstants.maxHistoryEntriesPerRequest` and globally at `AppConstants.maxHistoryEntriesGlobal`.
- `lib/state/run_history_notifier.dart`: past Collection Runner runs, including each
  request's assertion pass/fail summary; capped at `AppConstants.maxRunHistoryEntries`.
- `lib/state/chains_notifier.dart`: saved Flows.
- `lib/state/settings_providers.dart`: theme mode + active environment id, persisted via `SharedPreferences`.

There are no repository/usecase layers on top of these — a local-only app's "business logic"
is the notifier itself, reading and writing through `JsonStore`.

## Request Execution

1. UI collects the draft `ApiRequest` and the active environment's variables (`activeVariablesProvider`).
2. `RequestRunner.run()` resolves `{{variables}}`, builds the URL/headers/body per `BodyType`/`AuthType`, and sends it via `HttpClient`.
3. The result becomes a `RequestResult`, shown in the response viewer and recorded as a `ResponseSnapshot` via `HistoryNotifier`.
4. If the request has `Assertion`s configured, `lib/core/network/assertion_evaluator.dart` checks the `RequestResult` against each one, producing `AssertionResult`s shown inline for a single send and rolled up into `RunItemResult.assertionsPassed`/`assertionsTotal`/`failedAssertions` for Collection Runner/Flow runs.

Collection Runner and Flows reuse the same `RequestRunner` — a run/flow is just a sequential
loop over `RequestRunner.run()` calls with live per-item status.

## Import/Export

`lib/core/io/workspace_io.dart` builds/parses the Röle workspace bundle JSON and detects
Postman v2.x collection/environment exports (`lib/core/io/postman_import.dart`). File
picking uses `file_picker`'s native save/open dialogs — there's no custom Downloads-folder
logic.
