# Röle – Missing Features Todo List

A checklist to patch gaps compared to Postman. Tick items as they are implemented.

---

## 1. Request Building

- [ ] **Headers editor in request form** – Add key/value rows in create/edit request UI so users can add and edit custom headers (model already has `headers`; only applied on Postman import today).
- [ ] **Multiple body types** – Support body modes: none, form-data, x-www-form-urlencoded, raw (JSON/XML/text), binary (file). Currently only a single raw body field exists.
- [ ] **Auth configuration in UI** – Let users set auth per request or collection: Bearer token, Basic auth, API Key, and (later) OAuth 2.0 / AWS. Today Bearer is only applied when importing from Postman.

---

## 2. Variables & Environments

- [ ] **Variable scopes** – Add global and/or collection-level variables alongside environment-level (e.g. global for API keys, collection for base URL).
- [ ] **Session / local variables** – Support short-lived or script-set variables if scripting is added.
- [ ] **Predefined variables** – Built-in vars such as `{{$guid}}`, `{{$timestamp}}`, `{{$randomInt}}` for use in URLs, headers, and body.

---

## 3. Scripting & Tests

- [ ] **Pre-request scripts** – JavaScript (or similar) that runs before each request (e.g. set headers, generate values).
- [ ] **Test (post-response) scripts** – Scripts that run after the response with assertions (e.g. status code, body shape).
- [ ] **Script levels** – Support scripts at collection, folder (if added), and request level with clear execution order.
- [ ] **Collection runner pass/fail** – In collection runner, run tests and show passed/failed/skipped per request and overall.

---

## 4. Protocols & API Types

- [ ] **GraphQL** – Dedicated GraphQL body/editor and (optional) query docs (README roadmap).
- [ ] **WebSocket** – WebSocket testing support (README roadmap).
- [ ] **gRPC** – gRPC request support (README roadmap).
- [ ] **SOAP / MQTT / Socket.IO** – Lower priority; consider after REST/GraphQL/WS/gRPC.

---

## 5. Collections & Organization

- [ ] **Nested folders** – Allow folders inside collections (collection → folders → requests). Today collections are flat; Postman folders are flattened on import.
- [ ] **Folder description** – Optional description for folders (e.g. for docs).

---

## 6. Response & DX

- [ ] **Syntax highlighting** – Highlight JSON/HTML/XML in request and response bodies (README roadmap).
- [ ] **Response visualizer** – Optional view: charts or custom HTML/JS to visualize response data.
- [ ] **Code generation** – Generate snippets (cURL, Dart, JavaScript, etc.) from the current request.
- [ ] **Search in response** – Find text in response body (and optionally headers).

---

## 7. Collaboration & Sync (optional)

- [ ] **Workspaces** – Notion of workspace (personal/team) for grouping collections and envs.
- [ ] **Sync / backup** – Optional cloud or file-based sync/backup of workspace (no requirement for Postman-style cloud).
- [ ] **Sharing** – Export/share collection + env as file or link for teammates.

---

## 8. Documentation & Mocking

- [ ] **API documentation** – Generate readable API docs from collection (README roadmap).
- [ ] **Mock server** – Generate mock server from collection (optional).
- [ ] **OpenAPI/Swagger import** – Import from OpenAPI/Swagger spec in addition to Postman JSON.

---

## 9. Other

- [ ] **Request history with response snapshots** – Save response body/headers (or summary) with history entries (README roadmap).
- [ ] **SSL verification toggle** – Option to disable SSL verification for local/dev (with clear warning).
- [ ] **Configurable timeouts** – Let user set connect/receive timeout per request or globally (today uses app constants).
- [ ] **Cookie handling** – Store and send cookies automatically where applicable.
- [ ] **Proxy** – Optional HTTP(S) proxy configuration for requests.

---

## Priority suggestion

| Priority | Area                    | Example first tasks                          |
|----------|-------------------------|----------------------------------------------|
| High     | Request building        | Headers editor, then body types, then auth   |
| High     | Scripting & tests       | Pre-request + test scripts, runner pass/fail |
| Medium   | Collections             | Nested folders                               |
| Medium   | Variables               | Global/collection scope, predefined vars     |
| Medium   | Response & DX           | Syntax highlighting, code generation         |
| Lower    | Protocols               | GraphQL, WebSocket, gRPC                     |
| Lower    | Docs & mocking          | API docs, OpenAPI import                     |
| Optional | Collaboration, proxy…   | As needed                                    |

---

*Last updated from Postman comparison. Revisit when adding major features.*
