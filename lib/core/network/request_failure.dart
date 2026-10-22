import 'package:dio/dio.dart';

bool isSessionExpired(Object? error) =>
    error is DioException &&
    (error.response?.statusCode == 401 || error.response?.statusCode == 403);

String requestFailureMessage(Object? error) {
  if (isSessionExpired(error)) return '登录已失效，请重新登录';
  if (error is DioException) {
    if (error.response?.statusCode == 429) return '请求过于频繁，请稍后重试';
    if ((error.response?.statusCode ?? 0) >= 500) return '服务暂时不可用，请稍后重试';
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '网络连接失败，请检查网络后重试';
    }
  }
  return '暂时无法加载，请稍后重试';
}
