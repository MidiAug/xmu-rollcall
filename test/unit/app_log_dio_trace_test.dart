import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/app_log_dio_interceptor.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';

void main() {
  test(
    'HTTP trace correlates operation, timings and structured errors safely',
    () async {
      final root = await Directory.systemTemp.createTemp('xmu_http_trace_');
      final sink = NdjsonFileSink(logsDir: root);
      await sink.open();
      await AppLog.resetForTest(sink: sink);
      try {
        final interceptor = AppLogDioInterceptor();
        final options = RequestOptions(
          path: 'https://lnt.xmu.edu.cn/api/profile?token=secret-query',
          extra: {'opId': 'sign-operation', 'queueMs': 4321},
          headers: {'Authorization': 'secret-header'},
        );
        interceptor.onRequest(options, RequestInterceptorHandler());
        interceptor.onResponse(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'name': 'private-profile', 'password': 'secret-body'},
          ),
          ResponseInterceptorHandler(),
        );
        final errorHandler = _ObservedErrorHandler();
        final handled = errorHandler.waitHandled();
        interceptor.onError(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
          errorHandler,
        );
        await handled;
        await sink.flush();
        final records = await sink.readNewest(limit: 10);
        final request = records.singleWhere((r) => r.event == 'http.request');
        final response = records.singleWhere((r) => r.event == 'http.response');
        final error = records.singleWhere((r) => r.event == 'http.error');
        expect(response.fields['requestId'], request.fields['requestId']);
        expect(error.fields['requestId'], request.fields['requestId']);
        expect(response.opId, 'sign-operation');
        expect(response.fields['queueMs'], 4321);
        expect(response.fields['totalMs'], greaterThanOrEqualTo(4321));
        expect(error.fields['dioType'], 'receiveTimeout');
        final text = jsonEncode(records.map((r) => r.toJson()).toList());
        expect(text, isNot(contains('secret-')));
        expect(text, isNot(contains('private-profile')));
      } finally {
        await AppLog.resetForTest();
        await root.delete(recursive: true);
      }
    },
  );
}

class _ObservedErrorHandler extends ErrorInterceptorHandler {
  Future<void> waitHandled() =>
      future.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
}
