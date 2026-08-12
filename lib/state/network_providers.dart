import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/network/http_client.dart';
import '../core/network/request_runner.dart';

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout);
});

final requestRunnerProvider = Provider<RequestRunner>((ref) {
  return RequestRunner(ref.watch(httpClientProvider));
});
