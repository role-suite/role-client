import '../models/request_body.dart';

/// role-node's overall JSON body cap (`REQUEST_BODY_LIMIT`) defaults to 1MB,
/// but an oversized request currently surfaces as a bare `500`, not a clean
/// `413` (known limit, §3.2 of docs/08-ONLINE-MODE-INTEGRATION.md) — warn
/// client-side well before that, rather than let a push fail with a
/// confusing error.
const bodySizeWarningThresholdBytes = 700000;

/// Estimates the wire size of [body] in bytes. Only `FormDataBody` file parts
/// and `BinaryBody` can realistically approach the cap — `raw`/`urlencoded`
/// text bodies are capped at 200KB/500 entries by role-node's own
/// `endpointBodySchema`, already well under 1MB, so they're not estimated
/// here.
int estimatedWireBytes(RequestBody body) {
  switch (body) {
    case BinaryBody(:final dataBase64):
      return dataBase64.length;
    case FormDataBody(:final parts):
      return parts.whereType<FormFilePart>().fold(0, (sum, part) => sum + part.dataBase64.length);
    case NoneBody():
    case RawBody():
    case UrlEncodedBody():
      return 0;
  }
}
