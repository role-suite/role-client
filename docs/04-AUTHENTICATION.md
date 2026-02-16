# 4. Authentication

The app supports authenticated access to the backend when using **Serverpod RPC** as the API style. Authentication is handled by the Serverpod auth IDP (email) flow; the app does not implement its own login server.

## Overview

- **When**: Authentication is used when the data source is **API** and **API style** is **Serverpod RPC**.
- **How**: A shared Serverpod `Client` is built with `FlutterAuthSessionManager`. The client is created once per base URL (see `serverpodClientProvider`), and `client.auth.initialize()` restores or validates the session. All RPC calls (collections, requests, environments, workspace) use this client, so they automatically send the JWT when the user is signed in.
- **Sign-in UI**: The **Sign in** screen (`lib/features/auth/presentation/sign_in_screen.dart`) shows the email flow (register, verify, login) using `EmailSignInWidget` from `serverpod_auth_idp_flutter`. It is opened from the drawer when in API + Serverpod mode.

## Client Setup (Technical)

1. **Shared client**: `lib/core/services/relay_api/serverpod_client_provider.dart` defines `serverpodClientProvider`, a `FutureProvider.autoDispose.family<Client?, String>` keyed by base URL. For each non-empty base URL it:
   - Builds `Client(url)` with `connectivityMonitor: FlutterConnectivityMonitor()` and `authSessionManager: FlutterAuthSessionManager()`.
   - Calls `await client.auth.initialize()` (restore/validate session).
   - Returns the client.
2. **Usage**: `ServerpodRelayApiClient` and `ServerpodWorkspaceClient` accept an optional `Client? client`. When provided (e.g. from `serverpodClientProvider(baseUrl).whenOrNull(data: (c) => c)`), they use it for all calls so that auth headers (JWT) are sent. When not provided, they create a non-authenticated client (e.g. for anonymous or API-key-only servers).
3. **Repositories**: Collection, request, and environment repository providers (in `repository_providers.dart`) pass the shared client into `_createRelayApiClient(config, serverpodClient)` when the config is Serverpod. Sync to remote (from the drawer) also resolves the client for the current config and passes it into `SyncToRemoteService.sync(..., serverpodClient: client)` when applicable.

## Sign-In Screen

- **Route**: Opened from the drawer via “Sign in” (visible only when in API mode and API style is Serverpod).
- **Behavior**:
  - If the current data source is not API + Serverpod with a non-empty base URL, the screen shows a short message asking the user to switch to API, set Serverpod RPC, and set the base URL.
  - Otherwise it watches `serverpodClientProvider(baseUrl)`. While loading it shows a progress indicator; on error it shows the error; on success it shows `EmailSignInWidget(client: client, onAuthenticated: () => pop, onError: snackbar)`.
- **After sign-in**: The session is stored by `FlutterAuthSessionManager` (secure storage). The same client is used for all subsequent RPC and sync, so no extra steps are required in the UI beyond signing in.

## API Key (REST)

When the API style is **REST**, the server may require an API key. The user enters it in the data source config dialog (optional field). It is sent as `Authorization: Bearer <apiKey>` by `RestWorkspaceClient` (Dio). There is no separate “sign in” screen for REST; the key is just part of the stored config.

## Security Notes

- **Secrets**: API key is stored in SharedPreferences (`data_source_api_key`). Prefer not logging it; avoid shipping pre-filled keys in builds.
- **JWT**: Handled by Serverpod auth packages; stored in secure storage by `FlutterAuthSessionManager`. Use HTTPS in production so tokens are not sent in clear text.
- **Sign out**: The Serverpod auth session manager supports sign-out (e.g. `client.auth.signOutDevice()`). The current UI focuses on sign-in; sign-out can be added (e.g. in the drawer when authenticated).
