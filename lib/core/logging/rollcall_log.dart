import 'package:flutter/services.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

/// Shared rollcall diagnostic events (design §2).
abstract final class RollcallLog {
  static String newOpId() => AppLog.newOpId();

  static void start({
    required String opId,
    required String type,
    required int rollcallId,
    required String courseTitle,
    required String session,
    int? assistUserId,
    String? batchOpId,
  }) {
    AppLog.event(
      'rollcall.answer.start',
      opId: opId,
      fields: {
        'type': type,
        'rollcallId': rollcallId,
        'courseTitle': courseTitle,
        'session': session,
        'assistUserId': ?assistUserId,
        'batchOpId': ?batchOpId,
      },
    );
  }

  static void cancel({
    required String opId,
    required String type,
    required int rollcallId,
    required String courseTitle,
    required String session,
    int? assistUserId,
    String? batchOpId,
  }) {
    AppLog.event(
      'rollcall.answer.cancel',
      opId: opId,
      fields: {
        'type': type,
        'rollcallId': rollcallId,
        'courseTitle': courseTitle,
        'session': session,
        'assistUserId': ?assistUserId,
        'batchOpId': ?batchOpId,
      },
    );
  }

  static void numberCode({required String opId, required String numberCode}) {
    AppLog.event(
      'rollcall.number_code',
      opId: opId,
      fields: {'codeLen': numberCode.length, 'numberCode': numberCode},
    );
  }

  static void location({
    required String opId,
    required String source,
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) {
    AppLog.event(
      'rollcall.location',
      opId: opId,
      fields: {
        'source': source,
        'accuracyM': accuracyM,
        'latitude': double.parse(latitude.toStringAsFixed(5)),
        'longitude': double.parse(longitude.toStringAsFixed(5)),
      },
    );
  }

  static void locationFail({
    required String opId,
    required String reason,
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppLog.event(
      'rollcall.location.fail',
      level: 'W',
      opId: opId,
      fields: {
        'reason': reason,
        if (error != null)
          ...LogRedactor.exceptionFields(
            error: error,
            stackTrace: stackTrace,
            source: 'location',
          ),
        if (error is PlatformException) ...{
          'platformCode': LogRedactor.scrubString(error.code),
          'platformMessage': LogRedactor.scrubString(error.message ?? ''),
        },
      },
    );
  }

  static void qrPayloadHashed({
    required String opId,
    required int payloadLen,
    required String payloadSha256Prefix,
  }) {
    AppLog.event(
      'rollcall.qr.payload',
      opId: opId,
      fields: {
        'payloadLen': payloadLen,
        'payloadSha256Prefix': payloadSha256Prefix,
      },
    );
  }

  static void qrBatch({required String batchOpId, required int targetCount}) {
    AppLog.event(
      'rollcall.qr.batch',
      opId: batchOpId,
      fields: {'batchOpId': batchOpId, 'targetCount': targetCount},
    );
  }

  static void result({
    required String opId,
    required int rollcallId,
    required bool ok,
    int? status,
    String? message,
    Object? distance,
  }) {
    AppLog.event(
      'rollcall.answer.result',
      level: ok ? 'I' : 'W',
      opId: opId,
      fields: {
        'ok': ok,
        'rollcallId': rollcallId,
        'status': ?status,
        'message': ?message,
        'distance': ?distance,
      },
    );
  }

  static void exception({
    required String opId,
    required int rollcallId,
    required Object error,
    StackTrace? stackTrace,
    int? status,
  }) {
    AppLog.event(
      'rollcall.answer.exception',
      level: 'E',
      opId: opId,
      fields: {
        'rollcallId': rollcallId,
        ...LogRedactor.exceptionFields(
          error: error,
          stackTrace: stackTrace,
          status: status,
        ),
      },
    );
  }

  static void end({
    required String opId,
    required int rollcallId,
    required int durationMs,
    bool? ok,
  }) {
    AppLog.event(
      'rollcall.answer.end',
      opId: opId,
      fields: {'rollcallId': rollcallId, 'durationMs': durationMs, 'ok': ?ok},
    );
  }
}
