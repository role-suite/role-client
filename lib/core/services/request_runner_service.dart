import 'package:relay/core/models/request_result_model.dart';
import 'package:relay/core/services/api_service.dart';

class RequestRunnerService {
  const RequestRunnerService._internal();

  static final RequestRunnerService _instance = RequestRunnerService._internal();
  factory RequestRunnerService() => _instance;
  static RequestRunnerService get instance => _instance;

  Future<RequestResultModel> sendRequest({required String method, required String url, Map<String, dynamic>? headers, dynamic body}) async {
    final stopWatch = Stopwatch()..start();

    final response = await ApiService.instance.send<dynamic>(method: method, url: url, headers: headers, data: body);
    stopWatch.stop();

    return RequestResultModel(statusCode: response.statusCode, headers: response.headers, data: response.data, duration: stopWatch.elapsed);
  }
}
