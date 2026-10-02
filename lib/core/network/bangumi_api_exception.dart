import 'package:dio/dio.dart';

class BangumiApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic error;

  const BangumiApiException(this.message, {this.statusCode, this.error});

  factory BangumiApiException.fromDio(String prefix, DioException e) {
    final status = e.response?.statusCode;
    final resData = e.response?.data;
    String message = e.message ?? e.error?.toString() ?? '未知网络异常';

    if (resData is Map && resData.containsKey('description')) {
      message = resData['description'].toString();
    } else if (resData is Map && resData.containsKey('message')) {
      message = resData['message'].toString();
    }

    return BangumiApiException(
      '$prefix: $message',
      statusCode: status,
      error: e,
    );
  }

  @override
  String toString() => 'BangumiApiException: [$statusCode] $message';
}
