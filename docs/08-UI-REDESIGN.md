# 8. UI Redesign Strategy

## Goal

Redesign Röle into a more focused, tool-like API workspace inspired by Postman's operating model, while keeping Röle's product identity: local-only, lightweight, and centered on request execution.

The redesign should not copy Postman literally. It should borrow the parts of Postman's UI/UX strategy that make API work fast and legible, then simplify them for Röle's smaller scope.

## Core Design Strategy

The redesign should follow these principles:

- **Workbench first**: the center of the product is a persistent work surface, not a set of disconnected screens.
- **Fast request execution**: method, URL, and send actions stay prominent and easy to reach.
- **Deep inspection when needed**: advanced request configuration and response analysis are available without cluttering the first interaction.
- **Persistent navigation**: collections, requests, environments, runs, flows, and history remain visible and easy to switch between.
- **Local-first clarity**: avoid cloud, team, and workspace concepts that do not fit Röle.
- **Dense but calm UI**: optimize for speed and information density, but avoid noisy enterprise chrome.

In short, Röle should feel like a local API IDE rather than a generic dashboard.

## What To Borrow From Postman

- A central workbench where the main task happens.
- A persistent left navigation area for structure and organization.
- Request tabs or equivalent multi-document workflows on desktop.
- A request editor optimized around method, URL, and send.
- A response viewer that is always close to the request being edited.
- Progressive disclosure through tabs, panes, and inspectors.
- Strong visibility of execution state, active environment, errors, and history.

## What Not To Borrow

- Cloud-first navigation and collaboration-heavy chrome.
- Enterprise governance features in the main navigation.
- Too many global entry points competing for attention.
- Large amounts of product marketing or team workspace framing inside the app shell.

## Information Architecture

The redesigned app should use one persistent shell with four functional layers:

1. Global shell
2. Left navigation
3. Center workbench
4. Right inspector

### Global Shell

Purpose: global identity, quick actions, and app-level state.

Recommended contents:

- Röle app mark and name
- global search or command bar
- active environment switcher
- import/export actions
- theme toggle
- settings

The top bar should not act as the main feature navigation surface.

### Left Navigation

The left side should become the structural backbone of the app.

Recommended sections:

- Requests
- Collections
- Environments
- History
- Runs
- Flows

Recommended behavior:

- collapsible
- resizable on desktop
- searchable
- collection tree support
- quick create actions
- item actions from context menus or hover controls

Recommended desktop composition:

1. **Sidebar rail** with icons only
2. **Sidebar panel** showing the content for the selected domain

Example:

- Selecting `Requests` shows the collections and requests tree.
- Selecting `Runs` shows run history and runner entry points.
- Selecting `Environments` shows available environments and active state.

This is preferable to a single overloaded drawer.

### Center Workbench

The workbench is the product's primary operating surface.

The desktop workbench should support tabbed content for:

- request tabs
- collection runner tabs
- run result tabs
- flow tabs
- environment editor tabs

Recommended behavior:

- multiple open tabs on desktop
- visible unsaved state
- easy reopen of recently used items later if needed

Requests should remain the default first-class workbench entity.

### Right Inspector

The right side should be contextual, not primary.

Examples for request tabs:

- variables used
- request metadata
- saved history snapshots
- notes or info
- future code generation tools

Examples for run tabs:

- summary
- timing
- failures
- execution metadata

Examples for environment tabs:

- variable usage
- unresolved references
- active value preview

Core editing should stay in the main workbench, not in the inspector.

## Object Model The UI Should Communicate

The redesigned UI should make these layers clear:

1. **Workspace state**: local app state, active environment, theme
2. **Container**: collection, flow, or run set
3. **Unit**: request, environment, or run
4. **Execution**: send, run, replay, inspect
5. **Context**: variables, metadata, history, errors

The current home screen mixes several of these concerns in one place. The redesign should separate them more clearly.

## Feature Grouping

### Requests

- collections tree
- request list
- request tabs
- request editor
- response viewer

### Runs

- collection runner setup
- active run
- past run reports

### Flows

- create or edit flow
- execute flow
- inspect flow results

### Environments

- environment list
- environment editor
- variable inspection
- active environment switching

### History

- individual request sends
- reopen into request tabs
- inspect response snapshots
- save ad hoc history entries as requests

## Desktop Wireframe Plan

### 1. Desktop App Shell

```text
+--------------------------------------------------------------------------------------------------+
| Role | Search / Command | Environment: Local v | Import | Export | Theme | Settings            |
+--------------------------------------------------------------------------------------------------+
| Rail | Sidebar Panel                         | Workbench Tabs                         | Inspector |
|------|---------------------------------------|----------------------------------------|-----------|
| Req  | Collections / Requests tree           | [Users API] [Create User] [Run #12]    | Variables |
| Hist | Search requests                       |----------------------------------------| Metadata  |
| Runs |                                       | Active tab content                      | History   |
|Flows |                                       |                                        | Details   |
| Env  |                                       |                                        |           |
+--------------------------------------------------------------------------------------------------+
| Status: Local-only | Last run: 240ms | 2 unresolved vars | Save state                           |
+--------------------------------------------------------------------------------------------------+
```

Why this works:

- stable structure
- low navigation churn
- room for growth without redesigning the shell again
- keeps request work at the center

### 2. Requests View: Left Sidebar

```text
Requests
[ + New Request ]
[ + New Collection ]

Search requests...

Collections
- All Requests
- Default
  - Get Users
  - Create User
- Auth Service
  - Login
  - Refresh Token

Filters
[GET] [POST] [Errors] [Recent]
```

Rules:

- requests live inside collections
- `All Requests` is a virtual view
- search affects the visible tree or list
- quick actions are attached to items, not repeated across the page

### 3. Request Tab Workbench

```text
Tab: GET  Get Users                                          [Save] [Send]

[ GET v ] [ https://api.example.com/users________________ ] [ Send ]

[ Params ] [ Auth ] [ Headers ] [ Body ] [ Scripts ] [ Tests ]
--------------------------------------------------------------
Editor content for selected tab

--------------------------------------------------------------
Response
[ Body ] [ Headers ] [ Console ] [ Timeline ] [ History ]
Status 200 OK | 412 ms | 1.4 KB
Response content...
```

Recommended structure:

- top row for method, URL, and send
- request configuration beneath it
- response area below with a draggable splitter on desktop
- response area collapses or stays hidden when no response exists

This is the highest-priority screen in the redesign.

### 4. Empty Workbench State

```text
Role Workbench

[ New Request ]   [ Import Workspace ]

Recent
- GET Users
- Login
- Orders Smoke Test

Quick Start
- Create a request
- Open run history
- Manage environments
```

This state should be minimal and action-oriented.

### 5. Collection Runner Tab

```text
Collection Runner

Collection: [ Auth Service v ]
Environment: [ Staging v ]

Run options
Iterations [ 1 ]
Delay      [ 0 ms ]
Order
[x] Login
[x] Refresh Token
[x] Get Profile

[ Start Run ]
```

The runner should open inside the workbench as a tab, not as a separate screen-level mode.

### 6. Run Results Tab

```text
Run: Auth Service
Passed 8 | Failed 1 | 3.2s avg 240ms

[ Summary ] [ Requests ] [ Errors ] [ Console ]

Left list:
- Login          PASS 220ms
- Refresh Token  FAIL 401
- Get Profile    PASS 180ms

Main panel:
Selected run item details
request / response / assertion failure
```

This surface should feel analytical and easy to scan.

### 7. History View

```text
History

Search history...
Filters: [All] [GET] [POST] [Errors] [Today]

- GET /users            200   120ms   11:40
- POST /login           401   88ms    11:38
- GET /profile          200   95ms    11:37
```

Expected actions:

- reopen as tab
- save as request
- inspect response snapshot

### 8. Environment Editor Tab

```text
Environment: Staging                            [Set Active]

Name        Value                         Type
baseUrl     https://api.staging...        text
token       ************                  secret
tenantId    acme                          text

[ + Add Variable ]
```

Inspector support can include:

- where variables are used
- unresolved variable references
- current active values

### 9. Flows View

Röle currently supports sequential request chains. The redesign should not pretend to be a full node-graph editor unless the product scope actually expands there.

Phase 1 flows layout:

```text
Flow: Signup Journey

Steps
1. Create User
2. Login
3. Fetch Profile

[ + Add Step ] [ Run Flow ]

Selected step config on right:
- request
- variable mappings
- delay
- stop on error
```

This is a better fit for the current product than a large visual canvas.

## Mobile Information Architecture

Mobile should not attempt to mirror the desktop shell exactly.

Recommended mobile navigation:

- Requests
- History
- Runs
- Flows

Collections and environments should be accessed through compact sheets, drawers, or segmented pickers.

Recommended mobile behavior:

- request editor and response viewer remain central
- use stacked or tabbed request/response sections
- no persistent right inspector
- avoid trying to preserve full desktop panel density

## Theme Direction

The theme tokens can and should change significantly.

The current theme still reads as a general-purpose Material app. The redesigned UI should move toward a tool-grade visual system.

### Current Theme Characteristics

- rounded surfaces
- warm orange brand emphasis
- softer contrast
- spacing and controls tuned more like a general app than a desktop tool

### Recommended Theme Characteristics

- neutral-first surfaces
- restrained accent usage
- sharper visual hierarchy
- denser spacing
- stronger border and divider system
- excellent dark mode support
- code or editor surfaces visually distinct from app chrome

### Token Recommendations

- lower border radius overall
- smaller vertical padding for controls
- semantic request method colors
- stronger separation between panels and content surfaces
- monospace typography for URLs, request bodies, and response bodies
- dark mode treated as a first-class experience

Suggested method colors:

- `GET`: blue
- `POST`: green
- `PUT`: amber
- `PATCH`: purple
- `DELETE`: red

## What To Remove From The Current Mental Model

Avoid carrying these forward into the redesign:

- a top toolbar doing too many jobs
- screen hopping for request, runner, and history workflows
- repeated create actions across multiple surfaces
- wide generic card-based layouts for tool-heavy screens
- app flows that feel like mobile pages instead of a persistent workspace

## Recommended Rollout Order

1. Build the new app shell
2. Move desktop request work into a tabbed workbench
3. Introduce the left rail and contextual sidebar panel
4. Redesign the request tab with request and response split panes
5. Bring runs and history into workbench tabs
6. Rewrite theme tokens for the new tool-like visual system
7. Adapt the shell and workbench patterns for mobile

## Summary

The redesign target for Röle should be:

- **a local API IDE**

not:

- **a mini Postman clone**

Postman's strongest lesson is not its branding or enterprise features. It is the way it keeps API work inside one continuous workspace while letting users move quickly from request creation to execution to debugging. Röle should adopt that operating model and simplify it around local-only workflows.

## Concrete Implementation Plan

This section maps the redesign onto the current Flutter codebase so implementation can proceed incrementally without rewriting the app all at once.

## Current Implementation Snapshot

The current UI is primarily organized around these screens and files:

- `lib/main.dart`: app entry and `MaterialApp`
- `lib/features/home/presentation/home_screen.dart`: current app hub and shell
- `lib/features/home/presentation/widgets/home_drawer.dart`: mobile drawer and quick actions
- `lib/features/home/request/presentation/widgets/home_requests_view.dart`: request list view
- `lib/features/home/request/presentation/widgets/request_runner_screen.dart`: request detail route with request editor and response panel
- `lib/features/collection_runner/presentation/collection_runner_screen.dart`: standalone collection runner screen
- `lib/features/collection_runner/presentation/collection_run_history_screen.dart`: standalone run history screen
- `lib/features/request_chain/presentation/request_chain_config_screen.dart`: standalone request chain builder
- `lib/core/theme/app_theme.dart`: current light and dark theme definitions
- `lib/features/home/presentation/providers/providers.dart`: common feature provider barrel export

At the moment, the product behavior is spread across several route-level screens. The redesign should move those workflows into one persistent shell with a shared workbench.

## Target Structure

The implementation should add a shell-oriented presentation layer instead of continuing to expand `HomeScreen`.

Recommended new top-level presentation structure:

```text
lib/
├── core/
│   ├── presentation/
│   │   ├── shell/
│   │   │   ├── role_shell.dart
│   │   │   ├── role_top_bar.dart
│   │   │   ├── role_left_rail.dart
│   │   │   ├── role_sidebar_panel.dart
│   │   │   ├── role_workbench.dart
│   │   │   ├── role_inspector.dart
│   │   │   └── role_status_bar.dart
│   │   └── widgets/
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       ├── app_tokens.dart
│       └── app_text_styles.dart
└── features/
    ├── workspace/
    │   └── presentation/
    │       └── providers/
    ├── home/
    ├── collection_runner/
    └── request_chain/
```

This structure keeps the shell generic and lets feature content plug into the workbench instead of owning the whole app frame.

## File-By-File Migration Plan

### 1. Replace `HomeScreen` As The App Shell

Current file:

- `lib/features/home/presentation/home_screen.dart`

Problem:

- It currently acts as app shell, feature navigator, collection browser, request list, import/export controller, and mobile layout controller all at once.

Implementation direction:

- Keep `HomeScreen` temporarily as the entry route.
- Reduce it into a thin host for the new shell.
- Move most layout responsibility into new shell widgets under `lib/core/presentation/shell/`.

Recommended end state:

- `HomeScreen` becomes a composition root that wires providers and opens the shell.
- The shell owns desktop layout regions.
- Feature views become workbench content instead of top-level pages.

### 2. Introduce A Workspace UI State Layer

Current provider area:

- `lib/features/home/presentation/providers/providers.dart`

Gap:

- Current providers cover requests, collections, environments, and theme state, but there is no UI state model for a desktop shell.

Add a new provider group for workspace UI state, for example:

- active left-rail section
- selected sidebar item
- open workbench tabs
- active workbench tab
- inspector visibility
- sidebar collapsed or expanded state
- sidebar width
- request search query
- history filters

Recommended location:

- `lib/features/workspace/presentation/providers/workspace_ui_providers.dart`

Recommended model types:

- `WorkspaceSection`
- `WorkbenchTabType`
- `WorkbenchTabModel`
- `WorkspaceLayoutState`

This should be a new feature-level UI state layer, not added into request or collection repositories.

### 3. Convert `HomeDrawer` Into Mobile-Only Shell Support

Current file:

- `lib/features/home/presentation/widgets/home_drawer.dart`

Problem:

- It currently carries quick actions and appearance controls, but the redesign moves these concerns into the global shell.

Implementation direction:

- Keep `HomeDrawer` only for mobile.
- Remove desktop responsibility from it.
- Make it mirror the left rail domains for smaller screens.

Recommended mobile behavior:

- request navigation
- history access
- runs access
- flows access
- environment switching
- import/export
- settings and theme

Desktop should no longer depend on this drawer for primary navigation.

### 4. Evolve `HomeRequestsView` Into A Sidebar-Or-List Primitive

Current file:

- `lib/features/home/request/presentation/widgets/home_requests_view.dart`

Current strength:

- It already presents a compact request list with method, name, and URL.

Problem:

- It is currently treated as the main request area rather than part of a broader shell and workbench model.

Implementation direction:

- Reuse its dense list behavior.
- Split responsibilities if needed into:
  - request tree or list for the sidebar panel
  - request row tile widget
  - all-requests virtual list view

Recommended refactor targets:

- `request_list_panel.dart`
- `request_list_item.dart`
- `request_tree_panel.dart` if collections become hierarchical in the sidebar

Opening a request should no longer always push a route. On desktop it should open or focus a workbench tab.

### 5. Turn `RequestRunnerPage` Into The Main Request Workbench Surface

Current file:

- `lib/features/home/request/presentation/widgets/request_runner_screen.dart`

Current strength:

- It already combines the request editor and response viewer, which is the correct core interaction.

Problem:

- It is implemented as a standalone page with its own `Scaffold` and `AppBar`.
- That shape prevents it from fitting naturally into a shared desktop workbench.

Implementation direction:

- Split the route shell from the content widget.
- Extract the editable request surface into a reusable workbench widget.

Recommended split:

- `request_runner_screen.dart`: temporary route wrapper only
- `request_workbench_tab.dart`: main desktop tab content
- `request_workbench_header.dart`: tab-level request actions
- `request_response_split_view.dart`: draggable request/response layout

Key change:

- desktop opens request content inside the workbench tab area
- mobile may still use a dedicated route for request details initially

This is the highest-value implementation step in the redesign.

### 6. Move Collection Runner Into A Workbench Tab

Current file:

- `lib/features/collection_runner/presentation/collection_runner_screen.dart`

Problem:

- It is a separate page with its own app bar and route navigation to history.

Implementation direction:

- Extract its main content into a reusable panel that can render in the center workbench.
- Keep a route wrapper only for mobile compatibility if needed.

Recommended split:

- `collection_runner_screen.dart`: mobile wrapper or compatibility route
- `collection_runner_tab.dart`: desktop workbench tab content
- `collection_runner_setup_panel.dart`
- `collection_runner_results_panel.dart`

Desired behavior:

- runner configuration and results live in the same tab
- history opens in a sibling tab, not a separate page push on desktop

### 7. Move Run History Into The Workbench

Current file:

- `lib/features/collection_runner/presentation/collection_run_history_screen.dart`

Current strength:

- The content already has the right data concept.

Problem:

- It is route-shaped and card-heavy for a tool-oriented UI.

Implementation direction:

- Recast it as a run report index panel.
- Keep a compact list on the left and selected run details in the main area or inspector.

Recommended split:

- `collection_run_history_screen.dart`: compatibility route if needed
- `run_history_tab.dart`
- `run_history_list.dart`
- `run_report_view.dart`

Longer term, run history should behave much more like a file/report browser than a feed of large cards.

### 8. Keep Request Chains Simpler Than Postman Flows

Current file:

- `lib/features/request_chain/presentation/request_chain_config_screen.dart`

Observation:

- This screen is already large and tries to solve both request selection and chain editing.

Implementation direction:

- Keep the sequential-chain model.
- Do not jump to a visual graph canvas yet.
- Convert the current screen into a workbench tab with list-based editing.

Recommended split:

- `request_chain_config_screen.dart`: mobile or compatibility route
- `request_chain_tab.dart`
- `request_chain_request_picker.dart`
- `request_chain_steps_panel.dart`
- `request_chain_step_editor.dart`

This keeps the flow redesign aligned with current product scope.

### 9. Rewrite The Theme Layer For Tooling UI

Current file:

- `lib/core/theme/app_theme.dart`

Problem:

- The theme is still defined as one large theme file and optimized around a general Material app feel.

Implementation direction:

- Break the theme into tokens first, then rebuild `ThemeData` from those tokens.

Recommended additions:

- `app_colors.dart`: neutral surfaces, semantic colors, request method colors
- `app_tokens.dart`: radius, spacing, border widths, panel metrics
- `app_text_styles.dart`: editor-friendly and compact text styles
- `app_theme.dart`: final `ThemeData` assembly only

Design changes to encode:

- smaller radii
- denser controls
- stronger dividers and panel edges
- more neutral surfaces
- distinct editor surfaces
- first-class dark mode

### 10. Expand Shared Widgets For Shell Composition

Current widget barrel:

- `lib/core/presentation/widgets/widgets.dart`

Implementation direction:

- Keep existing widgets like `MethodBadge`, `AppButton`, and spacing primitives.
- Add shell-specific widgets separately instead of overloading the generic widget barrel too early.

Good reusable additions:

- pane header widgets
- tab strip widgets
- inspector section widgets
- command bar field
- collapsible sidebar section widgets
- split-pane drag handle widgets

## New Components To Add

Recommended first-wave components:

### Shell Components

- `role_shell.dart`
- `role_top_bar.dart`
- `role_left_rail.dart`
- `role_sidebar_panel.dart`
- `role_workbench.dart`
- `role_inspector.dart`
- `role_status_bar.dart`

### Workbench Components

- `workbench_tab_strip.dart`
- `workbench_tab_chip.dart`
- `workbench_empty_state.dart`
- `workbench_split_view.dart`

### Request Components

- `request_workbench_tab.dart`
- `request_tab_toolbar.dart`
- `request_editor_tabs.dart`
- `response_viewer_tabs.dart`

### Sidebar Components

- `collections_sidebar_panel.dart`
- `requests_sidebar_panel.dart`
- `history_sidebar_panel.dart`
- `runs_sidebar_panel.dart`
- `environments_sidebar_panel.dart`

## State Model Recommendations

The redesign will go more smoothly if the workbench uses explicit UI models instead of ad hoc booleans in large screen widgets.

Recommended UI models:

```text
WorkspaceSection
- requests
- history
- runs
- flows
- environments

WorkbenchTabType
- request
- runSetup
- runReport
- flow
- environment

WorkbenchTabModel
- id
- type
- title
- subtitle
- icon
- payload reference
- isDirty
```

This will make it possible to:

- reopen tabs
- focus tabs from sidebar clicks
- avoid duplicate request tabs
- show dirty state consistently

## Phased Delivery Plan

### Phase 1: Shell Foundation

Goal:

- build the persistent desktop shell without changing business logic

Tasks:

- create workspace UI providers
- add left rail, sidebar panel, workbench, and inspector shells
- make `HomeScreen` host the new shell
- keep current feature screens usable behind compatibility wrappers

Success criteria:

- desktop opens into a persistent multi-pane shell
- left navigation changes sidebar content
- center workbench shows a stable empty state

### Phase 2: Request Workbench Migration

Goal:

- move request editing and response viewing into the central workbench

Tasks:

- extract `RequestRunnerPage` content into `request_workbench_tab.dart`
- open requests as tabs instead of desktop route pushes
- preserve mobile route behavior temporarily
- add response splitter behavior

Success criteria:

- clicking a request opens a desktop workbench tab
- requests can be switched without leaving the shell
- response view remains attached to the active request tab

### Phase 3: Sidebar Refactor

Goal:

- make collections, requests, and filters feel native to the shell

Tasks:

- transform `HomeRequestsView` patterns into sidebar list or tree components
- introduce collection-aware request browsing
- move quick create actions into sidebar headers

Success criteria:

- request browsing lives in the sidebar panel
- the center is no longer a request list page

### Phase 4: Runs And History Migration

Goal:

- bring runner and run history into the workbench model

Tasks:

- convert `CollectionRunnerScreen` into runner tab content
- convert `CollectionRunHistoryScreen` into history and report tabs
- remove desktop route pushing between runner and run history

Success criteria:

- run setup, results, and history all work inside the shell

### Phase 5: Flows Migration

Goal:

- fit request chains into the same shell model without overbuilding

Tasks:

- convert `RequestChainConfigScreen` into workbench content
- preserve simple sequential step editing

Success criteria:

- flows behave like another workbench tool, not a separate app mode

### Phase 6: Theme Rewrite And Density Pass

Goal:

- align all screens visually with the new tool-like shell

Tasks:

- split out design tokens
- tune surfaces, borders, spacing, text, and semantic colors
- update shell and workbench widgets to use the new tokens consistently

Success criteria:

- the app no longer looks like a standard Material dashboard
- desktop density and readability improve in both light and dark themes

## Implementation Priorities

If implementation starts immediately, this should be the order of attack:

1. workspace UI providers
2. shell widgets
3. request workbench extraction from `RequestRunnerPage`
4. request opening behavior on desktop
5. sidebar panel migration for requests and collections
6. runner and run history tab migration
7. request chain tab migration
8. theme token rewrite

## Guardrails During Refactor

To keep the redesign manageable:

- do not rewrite repositories or persistence layers just to support the shell
- keep mobile behavior working while desktop architecture changes
- extract route wrappers from feature content instead of deleting screens immediately
- prefer moving logic out of large widgets over creating parallel feature implementations
- keep request execution behavior stable while presentation changes

## Expected Codebase Outcome

After the redesign foundation is in place, the app should have:

- one persistent desktop shell
- tabbed request workbench behavior
- sidebar-driven navigation instead of screen hopping
- runner, history, and flows integrated into the same operating surface
- a tokenized tool-oriented theme system

That is the point where visual refinement will become fast, because the app architecture will finally match the intended product shape.
