import 'package:dio/dio.dart';
import 'package:relay/core/models/request_result_model.dart';
import 'package:relay/core/services/api_service.dart';

class RequestRunnerService {
  const RequestRunnerService._internal();

  static final RequestRunnerService _instance = RequestRunnerService._internal();
  factory RequestRunnerService() => _instance;
  static RequestRunnerService get instance => _instance;

  Future<RequestResultModel> sendRequest({required String method, required String url, Map<String, dynamic>? headers, dynamic body}) async {
    final dio = ApiService.instance.dio;
    final stopWatch = Stopwatch()..start();

    final response = await dio.request(
      url,
      data: body,
      options: Options(method: method, headers: headers),
    );
    stopWatch.stop();

    return RequestResultModel(statusCode: response.statusCode, headers: response.headers.map, data: response.data, duration: stopWatch.elapsed);
  }
}
