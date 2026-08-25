import '../models/api_request.dart';
import '../models/enums.dart';

const remoteRequestLocalOnlyWarning = 'Descriptions, tests, and API key auth are local-only until backend support is added.';

List<String> remoteRequestLocalOnlyFields(ApiRequest request) {
  return [
    if ((request.description ?? '').trim().isNotEmpty) 'description',
    if (request.assertions.isNotEmpty) 'tests',
    if (request.authType == AuthType.apiKey) 'API key auth',
  ];
}
