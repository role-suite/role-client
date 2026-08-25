# 8. Online Mode Integration (role-node)

This guide is the implementation reference for wiring **role-client** (Röle, this repo) to
**role-node** (`../role-node`, sibling repo — a TypeScript/Express/Postgres backend for
team-synced workspaces). It is the working spec for the `feature/online-mode` branch.

Source of truth for the backend contract: `role-node/docs/guides/client-integration.md`,
`role-node/docs/modules/*.md`, `role-node/docs/errors.md`, and `GET /docs/openapi.json` served
by a running role-node instance. This guide does not restate every endpoint shape — it says
**how those endpoints should be wired into this app's existing architecture** without disturbing
what already works.

## Implementation status (as of 2026-08-25)

All six phases of §12's build order are done, plus a cleanup pass that closed the base-URL
settings gap Phases 1-5 had left open. The "Known gaps" subsection below lists what's left, all of
which need a decision or action outside this codebase — there is no more numbered phase work.
Full detail is in §12 below; short version:

- ✅ **Phase 1 (Groundwork)** — `WorkspaceOrigin` + sync-bookkeeping fields on `Collection`/
  `ApiRequest`/`Environment`; `generateId()` is UUIDv4; `KeyValueEntry`/`RequestBody`/
  `EnvironmentVariable` shape changes (§3.2) landed with old-shape migration tests; empty
  `lib/core/remote/` module; `AppConstants.apiPrefix` + `remoteBaseUrlProvider` (unset by
  default). See `lib/core/models/`, `lib/core/utils/id.dart`,
  `lib/state/settings_providers.dart`.
- ✅ **Phase 2 (Auth)** — `lib/core/remote/api_client.dart` (`RemoteApiClient`,
  `RemoteApiException`, envelope/error parsing per §6); `lib/core/remote/auth/`
  (`SecureTokenStore`/`TokenStorage`, `AuthInterceptor` with refresh-once-then-replay);
  `lib/state/auth_notifier.dart` (`register`/`login`/`logout`/`restore`/`switchWorkspace`/
  `listSessions`/`revokeSession`/`revokeOtherSessions`); `lib/ui/auth/` (sign-in/register dialog,
  session/device management dialog); account menu wired into `lib/ui/shell/top_bar.dart`;
  `AuthNotifier.restore()` called once from `lib/ui/shell/app_shell.dart` on startup. All auth
  response shapes were checked directly against the sibling `role-node` repo (not guessed) —
  see `role-node/docs/modules/auth.md`.
- ✅ **Phase 3 (Read-only sync)** — `lib/core/remote/sync/remote_mappers.dart` (pure wire→local
  translation, checked field-by-field against `role-node/src/modules/{collections,
  environments}/service.ts`'s response mappers — not guessed); `lib/core/remote/sync/
  workspace_sync_service.dart` (`fetchUpdates`/`fetchCollections`/`fetchEnvironments`, the latter
  two doing a full-list refetch-and-cache rather than patching individual rows from the update
  feed's partial event payloads — see the design note in §5 below); `lib/core/models/
  sync_cursor.dart`; `lib/state/sync_notifier.dart` (`SyncNotifier`, one instance since role-node
  scopes a token pair to exactly one workspace at a time — not a `.family`). `WorkspaceNotifier`/
  `EnvironmentsNotifier` merge `workspace/remote/<id>/...` into their loaded state per §7, gated by
  the new `activeRemoteWorkspaceIdProvider` (`lib/state/auth_notifier.dart`) — a true no-op for
  every local-only user. Sidebar (`requests_sidebar_panel.dart`, `environments_sidebar_panel.dart`,
  `environment_tab_view.dart`, `request_tab_view.dart`) shows remote-origin collections/
  environments/requests with a cloud badge and hides edit/rename/delete/save affordances on them
  (push doesn't exist until Phase 4); `status_bar.dart`'s indicator is now `SyncNotifier`-driven
  while signed in, verbatim "Local-only" otherwise.
- ✅ **Phase 4 (Two-way sync)** — scoped to editing/deleting already-synced (i.e. already carrying
  a `remoteId`) remote-origin collections/requests/environments+variables; creating a brand-new
  entity *inside* a remote workspace is deliberately deferred (needs an id-reconciliation step
  Phase 3's deterministic-id scheme doesn't cover yet — see "Deferred scope from Phase 4" below).
  `lib/core/remote/sync/workspace_push_service.dart`
  (`updateCollection`/`updateEndpoint`/`updateEnvironment` + matching deletes, all field shapes
  checked against `role-node/src/modules/{collections,environments}/service.ts`; `reconcileVariables`
  matches a row by `remoteId` when it has one, falling back to `key` for never-synced rows).
  `lib/core/models/outbox_entry.dart` + `lib/core/remote/sync/outbox_store.dart` (file-backed
  pending-push queue at `workspace/sync/outbox/<id>.json`, no Riverpod dependency — deliberately
  avoids the notifier-to-notifier circular-dependency trap hit with `AuthNotifier`/`SyncNotifier`
  in Phase 3) + `lib/core/remote/sync/outbox_flusher.dart` (permanent- vs retryable-error
  classification per `role-node/src/shared/errors/error-codes.ts`; permanent failures drop the
  entry and let the next pull silently reconcile, per the doc's "no merge UI" v1 choice).
  `WorkspaceNotifier`/`EnvironmentsNotifier` now route persistence by `origin` (fixing a Phase-3
  gap where a remote-origin write would have landed in the local `collections/`/`environments/`
  directories) and enqueue+best-effort-immediately-flush an outbox entry on every remote-origin
  edit/delete; `SyncNotifier._tick` flushes the outbox before each pull. UI un-gated accordingly
  (rename/delete/save/variable-edit now live for already-synced items; "New request" on a remote
  collection and "Duplicate" on a remote request stay disabled, matching the scope note above).
- ✅ **Phase 5 (Team features)** — `lib/core/models/workspace_member.dart` +
  `lib/core/models/workspace_invitation.dart` (server-driven only, no `toJson`/local persistence —
  a member list is fetched fresh every time, same pattern as `AuthNotifier.listSessions()`);
  `lib/core/remote/workspace/workspace_service.dart` (`WorkspaceService`: `createWorkspace`/
  `listMembers`/`createInvitation`/`join`/`updateMemberRole`/`removeMember`/`leave`/
  `convertToTeam`, all field/route/envelope shapes checked against
  `role-node/src/modules/workspaces/{service,schema,controller,route}.ts`); `lib/ui/workspace/
  workspace_dialog.dart` (`showWorkspaceDialog` — workspace switcher, create/join, members+role
  dropdown+remove, invite-by-email showing the raw token to copy/share, "convert to team," "leave
  workspace"), reached via a new "Workspace" item in `_AccountMenu`
  (`lib/ui/shell/top_bar.dart`). No new outbox/sync involvement — every action is a direct,
  synchronous REST call. Deliberately excludes `POST /workspaces/:id/members` (add an existing
  user directly, bypassing the invitation flow) — §10 only names the invitation path. Permission
  gating mirrors role-node's actual server checks rather than reimplementing them: role/type
  drive which buttons render (`owner`-only for invite/role-change/remove/convert-to-team; "leave"
  disabled client-side when the caller is the fetched member list's only `owner` row, mirroring
  `WORKSPACE_LAST_OWNER_LEAVE_FORBIDDEN` without an extra round-trip); anything not pre-empted
  this way still surfaces role-node's own error message rather than crashing, same
  `error is RemoteApiException ? error.message : error.toString()` pattern as
  `sign_in_dialog.dart`/`sessions_dialog.dart`. `join`/`createWorkspace` don't mint new tokens on
  their own (role-node quirk, verified in `src/modules/workspaces/service.ts`) — the dialog always
  follows up with the pre-existing `AuthNotifier.switchWorkspace` to actually scope in.
- ✅ **Post-Phase-5 cleanup** — closed the gaps a UI audit turned up after Phase 5 (see prior
  revisions of this doc for the original writeup): `lib/ui/shell/server_settings_dialog.dart`
  (`showServerSettingsDialog` — the §9 base-URL field + `GET /health` check this was missing since
  Phase 1/2; bare `Dio` pointed at the raw base URL, since role-node mounts `/health` outside
  `/api/v1`) reached from `_AccountMenu`'s signed-out state, which had to become a popup itself
  (previously a single icon jumping straight to sign-in — there was nowhere to put a second
  entry). `lib/core/remote/sync/outbox_store.dart` gained a per-workspace async lock around
  `enqueue`/`remove` (closed a narrow lost-update race between the immediate-flush-on-edit path
  and `SyncNotifier`'s per-tick flush). `EnvironmentVariable` gained an additive `remoteId`, used
  by `WorkspacePushService.reconcileVariables` to match a row across a key rename instead of
  treating it as delete-then-create. `lib/core/network/body_size.dart` (`estimatedWireBytes`)
  drives a warning icon in `request_tab_view.dart` when a request body nears role-node's 1MB cap
  (§3.2's known limit — still a bare `500` server-side, but now warned about client-side).
- ✅ **Phase 6 (role-node import/export integration)** — `lib/core/models/import_export_job.dart`
  (server-driven only, same pattern as `WorkspaceMember`/`WorkspaceInvitation`);
  `lib/core/remote/workspace/workspace_import_export_service.dart`
  (`WorkspaceImportExportService`: `listJobs`/`getJob`/`createExport`/`createImport`, verified
  against `role-node/src/modules/import-export/{schema,service,controller,route}.ts`). Two things
  worth knowing about role-node's actual behavior here, both confirmed in its source, not the
  prose docs: jobs **complete synchronously today** (no real async/polling needed — `createExport`/
  `createImport` return the finished job directly), and the wire payload is a **third shape**
  distinct from both the live collections/environments REST shape and Röle's own `WorkspaceBundle`
  — a portable "role-native" tree (`roleNativeImportPayloadSchema`) whose `body`/`auth` fields
  role-node itself passes through untyped/byte-for-byte. Net effect: **no mapper was needed in
  either direction** — export just takes `job.artifact` off the response and writes it to a file
  the user picks (reusing `WorkspaceIo.exportToFile`); import reads a picked file, `jsonDecode`s
  it, and POSTs it straight through as `payload`. `lib/ui/workspace/workspace_import_export_actions.dart`
  (`runExportRemoteWorkspace`/`runImportRemoteWorkspace` — import shows a confirmation dialog with
  the file's collection/environment counts first, since it's a real, workspace-wide, hard-to-undo
  write other members will see), wired as two icon buttons on `_WorkspaceRow` in
  `workspace_dialog.dart`, gated to `role != 'member'` (mirrors role-node's
  `IMPORT_EXPORT_RUN_FORBIDDEN` check for the same reason Phase 5's gating does). Also fixed a
  real bug found while researching this: a completed import publishes an `import_export_job`
  event so other clients see its new collections/environments via the normal pull, but
  `SyncNotifier._applyChangedEntities` (`lib/state/sync_notifier.dart`) didn't recognize that
  entity name at all — an import's effects would have been silently dropped by every other
  client's poll loop. Fixed by refetching both collection and environment families whenever
  `import_export_job` appears (the event alone doesn't say which it touched).

Every phase has kept `flutter analyze` / `dart format --set-exit-if-changed .` / `flutter test`
green, per §13. Test counts by area: model shape/migration tests in `test/core/models/`,
network/auth/sync-mapper/sync-service/push-service/outbox/workspace-service/import-export-service
tests in `test/core/remote/` (incl. `test/core/remote/auth/`, `test/core/remote/sync/`, and
`test/core/remote/workspace/`), notifier tests in `test/state/` (incl. `sync_notifier_test.dart`,
driven via `SyncNotifier.debugBootstrap`/`debugTick`/`debugFlushOutbox` + `syncAutoStartProvider`
rather than a real background poll loop). Dialog UI (`workspace_dialog.dart`,
`server_settings_dialog.dart`) has no widget-test coverage — this repo has no widget-test harness
for dialogs beyond `app_smoke_test.dart`, which boots signed-out and never reaches either;
verified via the service-layer unit tests only, same standing caveat as every prior phase's UI.

### Known gaps (as of 2026-08-25)

Everything left here needs a decision or action outside this codebase — not a bug to fix in a
future cleanup pass:

- **Creating a brand-new collection/request/environment *inside* a remote workspace** (deferred
  scope from Phase 4, still open). Needs an id-reconciliation step (mint a local id → push a
  `POST` → rewrite the local id to the deterministic `remote-<kind>-<workspaceId>-<remoteId>`
  scheme Phase 3 established) that hasn't been built — a real future feature, not a bug. Concretely
  still disabled in the UI: "New request" on a remote collection, "Duplicate" on a remote request;
  the global "New collection"/"New environment" buttons always create local-origin entities
  regardless of which remote workspace is active.
- **§3.1 "Flag, don't build" — a role-node backend decision.** Ask whoever owns role-node whether
  the collection/endpoint/environment/variable tables could accept an optional client-supplied
  `client_id UUID UNIQUE` column, purely as an idempotency key for retried creates. Dormant today
  (every push in Phase 4 targets an entity that already has a `remoteId`, and `PATCH`/`DELETE` are
  both naturally idempotent) but becomes a real correctness gap the moment the item above is
  built — a network timeout right after a successful `POST` would leave the client unable to tell
  "retry" from "already created."
- **No test in this repo has ever exercised a live, running role-node instance** — every phase's
  tests use a scripted `Dio` adapter. True end-to-end verification needs a running server, which
  isn't something to stand up unilaterally.

**Housekeeping:** nothing from this branch has been committed to git — `git status` on
`feature/online-mode` still shows all six phases plus the cleanup pass as working-tree changes
(plus some files modified before this doc's phase work started, e.g. `docs/README.md`,
`top_bar.dart`, `request_editor_panel.dart`). Worth a checkpoint commit now that all phases are
done.

## 0. The one rule everything else follows

> **Local mode is the product. Online mode is an optional second layer on top of it.**

Röle today (see [01-OVERVIEW.md](01-OVERVIEW.md), [02-ARCHITECTURE.md](02-ARCHITECTURE.md)) is
local-only: no accounts, no backend, notifiers read/write `JsonStore` directly, and the README
promises "Röle never talks to anything except the endpoints you point it at." That promise must
still be true after this work lands, for anyone who never logs in.

Concretely:

- A fresh install with no account, no login, no network must behave **exactly** as it does on
  `main` today. Nothing here recurring-polls, phones home, or reads config that requires a
  server, unless a user has explicitly signed in.
- Logging in never deletes, migrates, or silently overwrites local-only collections. A local
  workspace and a remote (team) workspace are different, coexisting things — see §2.
- If a signed-in user loses connectivity, the app degrades to the last-synced cache and stays
  usable; it does not lock the UI or throw a full-screen error.
- No existing model's local-mode JSON shape changes in a breaking way. New fields are additive
  and optional (`Foo.fromJson` must still parse pre-existing local files with those fields
  absent).
- No existing notifier's public API (method signatures UI code calls) changes shape for the
  local-only path. UI written against `WorkspaceNotifier`, `EnvironmentsNotifier`, etc. keeps
  working unmodified in local mode.

Everything below is designed to satisfy this rule first, features second.

## 1. What "online mode" actually adds

Mapped from role-node's domain (`role-node/README.md` API Overview,
`role-node/docs/architecture/overview.md`) onto Röle's existing concepts:

| role-node concept | Röle's existing concept | Relationship |
|---|---|---|
| Workspace (team, members, roles, invitations) | *(new)* — no local equivalent | New concept: a synced container that _holds_ collections/environments, parallel to "your local workspace" |
| Collection → Endpoint → Example | `Collection` → `ApiRequest` (+ history as "examples" analog) | Same concepts, but `ApiRequest`'s headers/query params/body need a shape change to match `collection_endpoints` losslessly — see §3.2 |
| Folder | *(new)* — Röle has no folder/grouping inside a collection today | New, additive UI concept |
| Environment → Variable | `Environment` (`variables: Map<String,String>`) | role-node models variables as rows with `enabled`/`isSecret`/`position`; a flat map can't carry that — the local model changes shape too, not just the mapper (§3.2) |
| Import/export jobs | `lib/core/io/workspace_io.dart` (sync, local) | role-node's import/export is async (job + polling); local import/export stays synchronous and unaffected |
| `GET /workspaces/:id/updates` cursor feed | *(new)* — no equivalent | Drives sync; see §5 |
| Auth (register/login/refresh/sessions) | *(new)* — Röle has no account concept | Entirely new, opt-in |

Most of this table is additive: new concepts (workspaces, folders, auth) or new UI, with nothing
about what a `Collection` or `ApiRequest` already stores having to change. The two rows flagged
above are the exception — `ApiRequest`'s headers/query params/body and `Environment.variables`
do change shape, not just gain new fields, per §3.2.

## 2. Mode model: two workspace kinds, not a global on/off switch

Resist making this a single `bool isOnline` flag on the whole app. Model it as: the user can have
any number of **local collections** (today's behavior, always present, never require a network)
plus, once signed in, any number of **remote workspaces** they're a member of. Both kinds show up
side by side in the sidebar/left rail — a remote workspace collection just carries a sync badge.

```
WorkspaceOrigin { local, remote }
```

- `Collection.origin` (new, optional, defaults to `local` when absent — see §3): which storage a
  collection belongs to.
- The left rail's requests section groups by origin: a "Local" group (always there, exactly
  today's behavior) and, once signed in, one group per remote workspace the token is scoped to.
- Signing out simply hides remote groups; it does not touch local data.

This avoids the two failure modes a single toggle invites: (1) a user who never logs in
accidentally hitting online-only code paths, and (2) a user's local scratch collections getting
entangled with a team's synced ones.

## 3. Model changes

Every model below already has `id`, `createdAt`, `updatedAt`. Existing fields are never renamed
or removed, and `fromJson` keeps using named/defaulted parameters throughout, so a file written
by today's `main` must still deserialize cleanly after every change in this section.

### 3.1 Sync bookkeeping and id strategy — checked against role-node's actual schema

The cleanest local-first pattern is a **client-generated id that IS the shared id** (a UUID
minted at creation time, used identically on-device and on the server) — it removes id
reconciliation as a problem entirely. That's not available against role-node as it stands today:
`collections`, `collection_endpoints`, `collection_folders`, `environments`, and
`environment_variables` are all `id SERIAL PRIMARY KEY`
(`role-node/migrations/20260320_002_create_collections_schema.migration.ts`,
`.../20260321_003_create_environments_schema.migration.ts`), and every `create*Schema` in
`role-node/src/modules/*/schema.ts` is `.strict()` — a client-supplied `id` field would be
rejected outright by Zod's unknown-key check, not silently ignored. So the id design has to work
*with* server-assigned integer ids, not around them:

- `Collection`, `ApiRequest`, `Environment` add:
  - `origin` (`WorkspaceOrigin`, default `local` if the key is missing)
  - `remoteWorkspaceId` (`int?`, role-node's workspace id, null for local)
  - `remoteId` (`int?`, role-node's row id for this entity, null until first synced)
  - `syncedAt` (`DateTime?`, last successful pull/push time)
- Do **not** repurpose the existing string `id` for the remote row id. Keep it as the app's
  stable local key always (Riverpod state keys, `ApiRequest.collectionId`, history's `requestId`
  foreign key, etc. all keep working untouched); `remoteId` is purely a foreign key into
  role-node, populated from the response of the entity's first successful `POST`.
- **Do** switch `generateId()` (`lib/core/utils/id.dart`) from its current timestamp+random-suffix
  scheme to UUIDv4. This isn't required by the dual-id design above, but it's a low-cost change
  that removes any future doubt about collision-safety once ids also double as outbox entry keys
  (§5), and it's invisible to local-only users.
- **Flag, don't build**: ask whoever owns role-node whether the collection/endpoint/environment/
  variable tables could accept an optional client-supplied `client_id UUID UNIQUE` column
  alongside the existing serial `id`, purely as an idempotency key for retried creates from the
  outbox (§5) — a network timeout right after a `POST` succeeds server-side leaves the client
  unable to tell "retry" from "already created" without one. This is a backend schema decision,
  not something to route around unilaterally on the client — same treatment as the body-size
  known limit in §3.2: name it, don't silently work around it.

### 3.2 Field-shape changes — match role-node's shapes, not just its field names

Some fields aren't just missing metadata, they're the wrong *shape* for what role-node's schema
(verified directly in `role-node/src/modules/{collections,environments}/schema.ts`, not just the
prose docs) can represent losslessly. Fix the shape now instead of translating a lossy shape at
the sync boundary forever — these are real local-mode improvements on their own merit, not
sync-only overhead:

- **`ApiRequest.headers` / `queryParams`**: `Map<String, String>` → `List<KeyValueEntry>`
  (`key`, `value`, `enabled`), matching role-node's `keyValueSchema`. A map can't hold a
  duplicate key, a guaranteed order, or a disabled-without-deleted entry; the list can.
  `TemplateResolver`/`RequestRunner`/`HttpClient` filter `enabled == true` when building the wire
  request. Migration: `fromJson` seeing the old `Map` shape converts each entry to
  `KeyValueEntry(enabled: true)`, preserving Dart's map iteration order.
- **`ApiRequest` body**: replace the `bodyType` + `body: String?` + `formFields: Map<String,String>`
  trio with one typed `RequestBody` union — `raw(contentType?, raw)` /
  `urlencoded(entries: List<KeyValueEntry>)` / `formdata(entries: List<FormPart>)` (`FormPart` is
  `text(key,value,enabled)` or `file(key,fileName,contentType?,dataBase64,enabled)`) /
  `binary(fileName,contentType?,dataBase64)` / `none` — matching `endpointBodySchema` exactly.
  This is also the only way to add file-upload support, which Röle has never had. Migration: the
  old `{bodyType, body, formFields}` triple maps onto exactly one of the five variants based on
  `bodyType`.
- **`Environment.variables`**: `Map<String, String>` → `List<EnvironmentVariable>` (`key`, `value`,
  `enabled`, `isSecret`, `position`), matching `environment_variables`. `TemplateResolver` skips
  `enabled == false` when resolving `{{var}}`. The environment editor UI gains an enable toggle
  and a secret-mask toggle on the value field. Migration: the old `Map` becomes
  `enabled: true, isSecret: false, position: <index>` per entry.
- **Known limit, accepted for now**: a form-data file part or binary body can be up to ~1.5MB
  base64 per `endpointBodySchema`, but role-node's overall JSON body cap (`REQUEST_BODY_LIMIT`,
  default 1MB) is smaller, and overflow currently surfaces as a bare `500`, not a clean `413`
  (`role-node/docs/guides/client-integration.md`). Warn or block client-side once an encoded
  payload nears ~700KB; this is a role-node-side inconsistency worth flagging upstream, not
  something the client can fully paper over.

### 3.3 Why match role-node's shapes instead of unifying the models outright

This is a deliberate middle path between two worse options:

- **Not** "leave local models untouched, absorb every difference in the mapper" — Röle would
  never gain ordering/duplicate-key headers, per-variable secrets, or file uploads, even though
  those are good local features independent of sync.
- **Not** "make the local model literally the generated role-node DTO" — that would pull
  server-only bookkeeping (`workspaceId`, `createdByUserId`, server-assigned `id`) into every
  local-only object, couple Röle's release cadence to role-node's schema churn (defeating the
  point of `role-node/docs/compatibility.md`'s `/api/v1` versioning), and *still* not solve the id
  problem in §3.1 — `SERIAL` ids can't be minted client-side no matter how similar the two models
  look.
- Instead: local models stay Röle's own domain types — an anti-corruption-layer boundary, not a
  shared type — reshaped field-by-field only where role-node's shape is genuinely better modeling
  (§3.2), with server-only concerns kept in the additive `remoteId`/`remoteWorkspaceId` side
  fields (§3.1) rather than baked into the model's required shape.

### 3.4 New models, local-only concerns

- `RemoteWorkspace` (`id`, `name`, `slug`, `role`, membership metadata) — mirrors role-node's
  workspace list/member shape, cached locally so the workspace switcher works offline.
- `AuthSession` (access/refresh token metadata, **not** the tokens themselves — see §4 on
  where tokens actually live).
- `SyncCursor` (`workspaceId`, `since` value) — one per remote workspace, persisted so polling
  resumes from where it left off after a restart.
- `WorkspaceBundle` / `lib/core/io/workspace_io.dart` (local import/export): unaffected. Local
  export continues to serialize local-origin data exactly as today. Whether a remote workspace's
  data is *also* exportable through the same bundle format is a nice-to-have (§8), not a
  prerequisite — role-node's own import/export module is the primary path for that.

## 4. Auth layer

New module: `lib/core/remote/auth/`.

- **Token storage**: access/refresh tokens are secrets and must not go through
  `shared_preferences` (plaintext) or `JsonStore` (plaintext JSON on disk) — both are fine for
  the local-only settings and workspace data they hold today, neither is appropriate for
  credentials. Add `flutter_secure_storage` (new dependency; Keychain/Keystore/DPAPI-backed) and
  put only the token pair + which `AuthSession` they belong to there. Everything else about auth
  state (`isSignedIn`, current user, current remote workspace id) can live in a normal
  `Notifier` backed by that secure store, mirroring the pattern `ThemeModeNotifier` /
  `ActiveEnvironmentNotifier` already use in `lib/state/settings_providers.dart` for
  `SharedPreferences`.
- **`AuthNotifier`** (`lib/state/auth_notifier.dart`): wraps
  `POST /api/v1/auth/{register,login,refresh,logout}`, `GET /api/v1/auth/me`,
  `POST /api/v1/auth/switch-workspace`, and the session-management endpoints
  (`GET/DELETE /api/v1/auth/sessions[/:id]`) per
  `role-node/docs/guides/client-integration.md`. State: `signedOut | signingIn | signedIn(user,
  workspaces, activeWorkspaceId)`.
- **Token refresh**: implement as a Dio interceptor (see §6) that catches
  `401 INVALID_ACCESS_TOKEN`, calls refresh once, replaces both tokens atomically in secure
  storage, and replays the original request — exactly the retry rule role-node's own guide
  specifies ("refresh once, then replay original request once"). On `INVALID_REFRESH_TOKEN` or
  `REFRESH_SESSION_INVALID`, clear stored tokens and drop `AuthNotifier` to `signedOut`; do not
  surface a generic error, surface "signed out, please sign in again."
- **Workspace scoping**: role-node scopes a token pair to one workspace
  (`data.workspace`/`data.memberships`, `POST /auth/switch-workspace`). `AuthNotifier` tracks
  `activeWorkspaceId` and exposes `switchWorkspace(id)`, which calls the endpoint, replaces
  tokens (switch revokes the old session, same as a refresh), and triggers the sync layer (§5) to
  re-point at the new workspace's cursor.
- **UI**: `lib/ui/auth/` — sign-in/sign-up screens, a "manage devices" screen driven by
  `GET /api/v1/auth/sessions` (per-row revoke via `DELETE .../sessions/:id`, "sign out
  everywhere else" via bulk `DELETE .../sessions`). Entry point: a new item in
  `ui/shell/top_bar.dart` (account menu) — additive, does not replace anything already there.
  Nothing under `lib/ui/auth/` is reachable unless the user opens it; it is never a gate in front
  of the rest of the app.

## 5. Sync layer

New module: `lib/core/remote/sync/`, plus `lib/state/sync_notifier.dart` (one instance per
active remote workspace, not global).

### Pull: cursor polling

role-node has no push transport (`role-node/docs/guides/client-integration.md`, "Real-time
sync"): `GET /workspaces/:workspaceId/updates?since=<cursor>&limit=<n>` is the only mechanism,
and it's the client's job to poll it. Implementation:

1. On entering a remote workspace (switch, or app resume while one is active), load the
   persisted `SyncCursor` for that workspace (`since = 0` the first time).
2. Poll on an interval (foreground/active only — do not poll from a backgrounded app; there is no
   server-push to justify a background service). Suggested baseline: 5–10s while the workbench is
   focused on that workspace, paused entirely when it isn't the active workspace or the app is
   backgrounded. This must stay well under the general rate limit (300 req/60s per
   `role-node/docs/guides/client-integration.md`) even with several collections/environments open.
3. Each page's `items` carries `{entity, action, entityId, payload}` events (collections, folders,
   endpoints, examples, environments, variables, membership changes, completed import jobs, per
   the client-integration guide). Apply them to the local cache of that remote workspace by
   entity type; advance the stored cursor to `data.cursor.next` only after events are applied
   successfully (so a crash mid-apply re-fetches the same page next time, not loses it).
4. `hasMore: true` means keep paging immediately at the same cursor position before falling back
   to the poll interval; `hasMore: false` means wait for the next tick.

### Push: local edits

Local mutations to a remote-origin `Collection`/`ApiRequest`/`Environment` go through the same
`WorkspaceNotifier` / `EnvironmentsNotifier` methods UI already calls (§7) — they still write the
local JSON cache immediately (so the UI never blocks on network), then enqueue the corresponding
role-node write (`POST`/`PATCH`/`DELETE` under `/workspaces/:id/collections|environments/...`).

- **While online**: enqueue → send now → on success, stamp `remoteId`/`syncedAt`; the next
  `updates` poll will see the same change come back as an event for this entity and should no-op
  (compare `syncedAt`/payload, don't re-apply and re-emit).
- **While offline** (request fails with a network error, not a 4xx): keep the mutation in a
  local, persisted outbox (`workspace/sync/outbox/<workspaceId>.json`, following the same
  `JsonStore` convention everything else uses) and retry with backoff when connectivity returns.
  The UI shows the item as "pending sync," never as an error, and the local copy remains fully
  editable in the meantime.
- **Conflict rule**: last-write-wins by `updatedAt`, applied at the field-group level role-node's
  `PATCH` already operates at (whole collection/endpoint/environment/variable object, not
  per-field diff — matches how `WorkspaceNotifier.updateCollection`/`updateRequest` already work
  today). This is a deliberate simplicity choice for v1, not a hidden requirement — note it in
  the UI (last editor wins, no merge UI) rather than trying to build operational-transform-style
  merging.

### What does *not* sync

History (`HistoryNotifier`), run reports (`RunHistoryNotifier`), and Flows (`ChainsNotifier`)
stay device-local even for a remote-origin collection/request in v1 — role-node has no endpoints
for any of these (see the API Overview table in `role-node/README.md`). Don't build sync paths
for them speculatively; if team-shared run history becomes a real ask, that's a role-node feature
addition first, client work second.

## 6. Network client

New module: `lib/core/remote/api_client.dart`, separate from `lib/core/network/http_client.dart`.

- **Keep these separate on purpose.** `HttpClient`/`RequestRunner` execute the arbitrary
  user-defined requests that are this app's whole point (any method, any URL, any auth the user
  configures) — that code must never gain awareness of role-node. The new remote API client only
  ever talks to one fixed base URL (role-node) with one fixed auth scheme (bearer JWT managed by
  `AuthNotifier`). Do not merge them into one "generic HTTP layer" — they solve unrelated
  problems and a shared abstraction would just make the user-facing request engine more complex
  for no benefit.
- Base it on Dio (already a dependency) with:
  - A base URL from build-time config (see §9) — never hardcoded to a single deployment, since
    self-hosted role-node instances are a real case for a "bring your own backend" team tool.
  - An auth interceptor that attaches `Authorization: Bearer <accessToken>` and implements the
    refresh-and-replay described in §4.
  - Error mapping: role-node's envelope is always `{success, data}` or
    `{success:false, error:{code, message, details, requestId}}`
    (`role-node/docs/guides/client-integration.md`). Parse into a typed `RemoteApiException(code,
    message, requestId, details)` and branch UI/retry behavior on `code`, matching the table in
    that guide (`VALIDATION_FAILED`, `WORKSPACE_ACCESS_DENIED`, `RATE_LIMIT_EXCEEDED`, etc.) —
    never branch on `message` text.
  - Rate-limit handling: read `Retry-After` on `429 RATE_LIMIT_EXCEEDED` and back off the sync
    poller specifically (don't just fail the poll tick silently — pause it for the indicated
    duration then resume).
  - Respect the 1MB request body cap the backend enforces (`REQUEST_BODY_LIMIT`, per
    `role-node/docs/guides/client-integration.md`) client-side before sending a large
    import/export payload, since an oversized body currently surfaces there as an unhelpful `500`
    rather than a clean `413`.
- **Typed request/response models**: generate from role-node's `GET /docs/openapi.json` (Swagger
  UI at `GET /docs`, non-production only — see `role-node/docs/guides/client-integration.md`)
  rather than hand-writing DTOs. Regenerate whenever role-node bumps a minor/major version, per
  `role-node/docs/compatibility.md`. Do not assume a `role-sdk` package is a usable Dart
  dependency — that repo's language/platform isn't confirmed by role-node's docs; treat role-node
  as a plain REST/JSON API until proven otherwise.
  - **Decision (Phases 3-5)**: hand-mapped instead, in `lib/core/remote/sync/remote_mappers.dart`
    and the various `*_service.dart` files, with every wire shape verified line-by-line against
    role-node's actual TypeScript source rather than the prose docs. This is a deliberate,
    permanent choice, not a gap to close later: it fits the anti-corruption-layer design (§3.3),
    and standing up an openapi-codegen pipeline (new dependency, a build_runner step, CI wiring)
    for a surface this small and already-verified would cost more than it buys. Revisit only if
    role-node's API grows enough that hand-mapping becomes the bottleneck.

## 7. Fitting into the existing state layer without a repository split

[07-MAINTENANCE.md](07-MAINTENANCE.md) is explicit that Röle has "no
`features/<name>/data|domain|presentation` split" because a local-only app's notifier already is
the data layer. Online mode is the first time that stops being strictly true — resist solving it
by giving every notifier a full repository/service abstraction; that would restructure the whole
app for a feature only some users opt into. Instead:

- `WorkspaceNotifier` (and `EnvironmentsNotifier`) keep their existing method signatures exactly.
  Internally, each mutating method (`createCollection`, `updateRequest`, ...) does what it does
  today (write `JsonStore`, update state) and, **only when the target entity's `origin` is
  `remote`**, additionally calls into the sync layer's push path (§5) after the local write
  succeeds. This is a small, explicit `if (entity.origin == WorkspaceOrigin.remote) { ... }`
  branch per method, not a swapped-out storage backend — local-mode code paths are untouched and
  still don't know remote mode exists.
- Loading (`_loadAll`/`build()`) merges two sources instead of one: local `JsonStore` files
  (today's behavior, unconditional) plus, per signed-in remote workspace, that workspace's cached
  JSON files under `workspace/remote/<workspaceId>/...` (written by the sync pull path, §5 — same
  `JsonStore`, different subtree, never mixed into the local `collections/<id>.json` files). A
  user who is signed out simply has no `remote/` subtree to read.
- This keeps "notifier IS the data layer" true — it's just a data layer that, per-entity, knows
  whether it also has a remote counterpart to reconcile with. It also means deleting the
  `remote/<workspaceId>/` cache (e.g., on sign-out or leaving a workspace) is a pure local
  operation with no risk to `collections/<id>.json`.

## 8. Import/export

Local import/export (`lib/core/io/workspace_io.dart`, Röle/Postman bundles, synchronous,
file-picker based) is unaffected and stays the primary path for local-only users.

role-node additionally exposes its own **async, job-based** import/export
(`POST .../import-export/imports`, `POST .../import-export/exports`,
`GET .../import-export/jobs[/:jobId]`) scoped to a remote workspace. Treated as a distinct
feature (`lib/ui/workspace/workspace_import_export_actions.dart`, exposed as two icon buttons in
`workspace_dialog.dart`), not a replacement for or a merge with the local export flow. Completed
import jobs also show up on the `updates` cursor feed per role-node's docs — a workspace member
who didn't trigger the import still sees the new collections appear via the normal sync pull
(`SyncNotifier` refetches on the `import_export_job` entity — see the Phase 6 status note above).

**Implementation note**: despite "async, job-based" above, role-node's create routes currently
complete *synchronously* (confirmed in `role-node/src/modules/import-export/service.ts` and its
own module docs) — `createExport`/`createImport` return the finished job directly, so there's no
actual polling loop in the client, just a create-and-done call. The wire payload is also not the
live collections/environments REST shape or Röle's `WorkspaceBundle`, but role-node's own portable
"role-native" tree (`roleNativeImportPayloadSchema`) — passed through by the client unparsed in
both directions, since role-node's `body`/`auth` fields inside it are untyped and passed through
by role-node itself the same way.

## 9. Configuration additions

`lib/core/constants.dart` gains only what's genuinely fixed/compile-time; anything
environment-specific (which role-node instance to talk to) should not be hardcoded, since
self-hosting is a real scenario for a team tool:

- `AppConstants.apiPrefix = '/api/v1'` (mirrors role-node's `API_PREFIX`,
  `role-node/docs/compatibility.md` — bump only for a documented `/api/v2` breaking change).
- Reuse `defaultConnectTimeout`/`defaultReceiveTimeout` for the remote client too unless
  role-node's own timeout guidance (`SERVER_REQUEST_TIMEOUT_MS`, 5 min default, per
  `role-node/docs/guides/client-integration.md`) argues for a longer receive timeout specifically
  on large import/export calls.
- Base URL: a per-install setting (`SharedPreferences`, alongside `themeModeProvider` — see
  `RemoteBaseUrlNotifier` in `lib/state/settings_providers.dart`), defaulting to unset/empty
  (= online mode simply isn't offered until configured), with a settings screen field
  (`lib/ui/shell/server_settings_dialog.dart`) to point at a self-hosted or hosted role-node
  instance plus a `GET /health` check before saving it.

## 10. UI touch points (additive)

- `ui/shell/top_bar.dart`: account/avatar menu (sign in/out, current workspace, "manage devices").
- `ui/shell/side_rail.dart` / `ui/sidebar/`: remote workspace groups alongside the existing Local
  group; a small sync-state glyph (synced / pending / offline) per remote item, sourced from
  `SyncNotifier`, not from a new top-level route — there is still exactly one persistent shell,
  per [02-ARCHITECTURE.md](02-ARCHITECTURE.md).
- `ui/shell/status_bar.dart`: today's "local-only" indicator becomes conditional — still shown
  verbatim when signed out, replaced with an online/last-synced indicator only while a remote
  workspace is active.
- New `lib/ui/workspace/`: workspace list/switcher, members + roles, invitations (create/accept
  via `POST /workspaces/:id/invitations`, `POST /workspaces/join`), "convert to team"
  (`POST /workspaces/:id/convert-to-team`).
- New `lib/ui/auth/`: sign-in, sign-up, session/device management.

None of these are shown or reachable without an explicit user action (opening the account menu),
so a local-only user's day-to-day screens are pixel-for-pixel unchanged.

## 11. Error and offline UX

Map role-node's error codes (full registry: `role-node/docs/errors.md`; the common subset is
tabulated in `role-node/docs/guides/client-integration.md`) to user-facing behavior, not raw
`error.message`:

| Code | Client behavior |
|---|---|
| `VALIDATION_FAILED` | Inline field errors from `error.details.fieldErrors`, no retry |
| `MISSING_ACCESS_TOKEN` / `INVALID_ACCESS_TOKEN` | Silent refresh-and-replay (§4); only surface UI if refresh itself fails |
| `INVALID_REFRESH_TOKEN` / `REFRESH_SESSION_INVALID` | Force sign-out, remote groups collapse, local workspace keeps working |
| `WORKSPACE_ACCESS_DENIED` | "You no longer have access" on that workspace group; don't retry |
| `WORKSPACE_NOT_FOUND` | Remove that workspace from the switcher, keep others |
| `RATE_LIMIT_EXCEEDED` | Pause sync poller for `Retry-After`; don't error-toast for routine polling |
| Network/timeout (no response) | Treat as offline: pause pull/push, keep local cache read/write-able, show "offline, pending sync" |

A signed-in user with no connectivity should be able to keep editing a remote-origin collection
exactly like a local one — the outbox (§5) is what makes that safe.

## 12. Suggested build order

Each phase should leave `main`/the branch in a working, shippable state for local-only users —
this is not a "big bang" migration.

1. ✅ **Groundwork** (done): additive sync-bookkeeping fields, `WorkspaceOrigin`, the
   `generateId()` → UUIDv4 switch, the header/query-param/body/environment-variable shape changes
   (§3.1–§3.2), and an empty `lib/core/remote/` module + `apiPrefix`/base-URL setting. No UI
   change yet. Verify local mode + all existing tests still pass untouched, including the
   old-shape migration paths (`fromJson` on a `main`-written file).
2. ✅ **Auth** (done): secure token storage, `AuthNotifier`, sign-in/up UI, session management UI.
   A user can sign in and see their workspace list; nothing syncs yet.
3. ✅ **Read-only sync** (done): cursor polling (§5 pull only) populates
   `workspace/remote/<id>/...` and the sidebar shows remote collections/environments read-only.
4. ✅ **Two-way sync** (done): local mutation methods gain the remote push branch (§7) for
   already-synced entities; file-backed outbox for offline edits; conflict rule (last-write-wins)
   in place. Creating a brand-new entity inside a remote workspace is deliberately out of scope
   (needs an id-reconciliation step not yet built — see the Phase-4 status note above).
5. ✅ **Team features** (done): members/roles, invitations, "convert to team," workspace switcher,
   per-role permission gating in the UI (mirroring what role-node's role checks already enforce
   server-side, e.g. `owner`-only actions and the last-owner-leave guard — the client only hides
   actions the server would reject, it doesn't re-implement authorization).
6. ✅ **role-node import/export integration** (§8, done) — the "and any remaining polish" half of
   this step (rate-limit-aware backoff, generated-client refresh policy) was already covered by
   Phase 3/4's `Retry-After` handling and the cleanup pass's §6 decision note, so this step ended
   up being the import/export feature alone. No numbered phase work remains — see "Known gaps"
   above for what's left and why none of it is more phase work.

## 13. Testing

- Unit-test the sync merge logic (`updates` events → local cache mutations) and the outbox
  replay logic against fixture payloads shaped like role-node's integration tests
  (`role-node/tests/integration/*.test.ts` are the source of truth for real request/response
  shapes — copy fixtures from there the way
  `role-node/docs/guides/client-integration.md` itself does).
- Unit-test that every existing local-mode notifier test still passes unmodified — that's the
  regression signal for the "local mode isn't broken" rule in §0.
- Integration-test the Dio auth interceptor's refresh-and-replay and rate-limit backoff against a
  mocked role-node (status codes + `Retry-After`/`RateLimit` headers), not a live server.
- Keep `flutter analyze` / `dart format --set-exit-if-changed .` / `flutter test` green per
  [06-DEVELOPMENT.md](06-DEVELOPMENT.md) at every phase boundary in §12, since each phase is
  meant to be independently shippable.
