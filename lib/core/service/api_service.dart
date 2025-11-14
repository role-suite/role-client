import 'package:dio/dio.dart';
import 'package:relay/core/constant/app_constants.dart';

class ApiService {
  ApiService._internal() {
    _dio = Dio(BaseOptions(connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout));
  }
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  static ApiService get instance => _instance;
  late final Dio _dio;
  Dio get dio => _dio;
}
