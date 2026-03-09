import 'package:dio/dio.dart';
import 'package:tariqi/const/api_data/api_keys.dart';
import 'package:tariqi/const/api_data/api_links.dart';

class DioPaymentClient {

  static final DioPaymentClient _instance = DioPaymentClient._internal();
  factory DioPaymentClient() => _instance;
  final authToken = ApiKeys.paymentAccessToken;

  late Dio dio;

  DioPaymentClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiLinks.paymentBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    // اختياري: إضافة Interceptors لعرض اللوج أو التعامل مع الأخطاء
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
      ),
    );
  }

  Dio get client => dio;
}
