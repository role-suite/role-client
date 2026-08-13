# 3. Data Model

The app works with **collections** (groups of requests), **requests** (API request
definitions), **environments** (named sets of variables), **history** (response
snapshots), **runs** (Collection Runner reports), and **flows** (saved request chains).
All are stored locally on-device as JSON. Models live in `lib/core/models/`.

## Core Models

### Collection

`lib/core/models/collection.dart` — `id`, `name`, `description`, `createdAt`, `updatedAt`.

### ApiRequest

`lib/core/models/api_request.dart` — a single HTTP request definition:

`id`, `collectionId`, `name`, `method` (`HttpMethod`), `url`, `headers`, `queryParams`,
`bodyType` (`BodyType`), `body`, `formFields`, `authType` (`AuthType`), `authConfig`,
`assertions` (`List<Assertion>`), `description`, `createdAt`, `updatedAt`.

Enums live in `lib/core/models/enums.dart`: `HttpMethod`, `BodyType`
(none/raw/formData/urlEncoded/binary), `AuthType` (none/bearer/basic/apiKey), plus
`AuthConfigKeys` for the keys used inside `authConfig`.

### Assertion / AssertionResult

`lib/core/models/assertion.dart` — a declarative, no-scripting check run against a
request's `RequestResult`: `id`, `type` (`AssertionType`: statusEquals/maxDurationMs/
bodyContains/headerEquals/jsonPath), `target` (header name or JSON path, only for the
types where `AssertionType.needsTarget` is true), `expected`, `enabled`. Evaluated by
`lib/core/network/assertion_evaluator.dart` after a request completes, producing
`AssertionResult` (`assertion`, `passed`, `message`) — not persisted itself, only the
pass/fail summary is (see `RunItemResult` below).

### Environment

`lib/core/models/environment.dart` — `id`, `name`, `variables` (`Map<String, String>`),
`createdAt`, `updatedAt`. The active environment's id is stored separately (see below);
its variables resolve `{{name}}` placeholders in requests via `TemplateResolver`.

### RequestResult / ResponseSnapshot

`lib/core/models/request_result.dart` — the outcome of sending a request: `ok`,
`statusCode`, `statusMessage`, `headers`, `body`, `duration`, `errorMessage`, `isOffline`.

`lib/core/models/response_snapshot.dart` wraps a `RequestResult` with the request it came
from (`requestId`, `requestName`, `method`, `url`, `timestamp`) for history.

### RunHistoryEntry / RunItemResult

`lib/core/models/run_history.dart` — a Collection Runner run: `id`, `collectionId`,
`collectionName`, `environmentName`, `startedAt`, `completedAt`, and a list of
`RunItemResult` (per-request `status`/`statusCode`/`duration`/`errorMessage`, plus
`assertionsPassed`, `assertionsTotal`, and `failedAssertions` — the assertion pass/fail
summary for that request, populated when the request has `Assertion`s configured).

### SavedChain / ChainStep

`lib/core/models/chain.dart` — a Flow: `id`, `name`, `description`, ordered `steps`
(`ChainStep`: `requestId`, `requestName`, `delayMs`, `usePreviousResponse`), `createdAt`,
`updatedAt`. `ChainStepResult` is the ephemeral (not persisted) result of running one step.

### WorkspaceBundle

Full workspace snapshot used for import/export.

| Field | Type | Description |
|-------|------|--------------|
| `version` | int | Schema version (`WorkspaceBundle.currentVersion` = 1). |
| `exportedAt` | DateTime | Export time. |
| `source` | String? | Optional source identifier. |
| `collections` | List\<CollectionBundle\> | Collections with their requests. |
| `environments` | List\<Environment\> | Environments. |

Defined in `lib/core/models/workspace_bundle.dart`. Built/parsed by `lib/core/io/workspace_io.dart`.

## Local Storage

- **Preferences**: `SharedPreferences` stores theme mode and the active environment id (`lib/state/settings_providers.dart`).
- **Workspace**: everything else is JSON files under the app's support directory (`getApplicationSupportDirectory()/workspace/`), read/written through `JsonStore` (`lib/core/storage/json_store.dart`):

```
workspace/
├── collections/<id>.json      # { collection, requests[] }
├── environments/<id>.json
├── history/<requestId>.json   # { requestId, snapshots[] } — metadata only, no bodies
├── history/bodies/<snapshotId>.json  # { body } — one file per snapshot, hydrated on demand
├── runs/<id>.json
└── flows/<id>.json
```

History snapshots store their response body in a separate per-snapshot file rather than
inline, so the in-memory/list view never has to hold bodies (`ResponseSnapshot.toMetadataJson`,
`lib/state/history_notifier.dart`). Two caps keep history bounded: `AppConstants.maxHistoryEntriesPerRequest`
(20, per request) and `AppConstants.maxHistoryEntriesGlobal` (300, across all requests) —
oldest entries are evicted (metadata + body file both deleted) as new ones arrive. Run
history is similarly capped at `AppConstants.maxRunHistoryEntries` (200). The history and
run sidebar panels page through their (already-capped) lists client-side at
`AppConstants.historyPageSize` (30) and `AppConstants.runHistoryPageSize` (20) respectively,
loading more on demand rather than rendering everything at once.
