import 'package:flutter/services.dart';

/// Shared adapter registered in the UI engine and the foreground worker engine.
abstract final class AndroidMonitorPlatform {
  static const ongoingChannelId = 'monitor_ongoing';
  static const channel = MethodChannel('xmu_rollcall/monitor');

  static Future<bool> updateCountdown({
    required String title,
    required String text,
    int? deadlineMs,
  }) async =>
      await channel.invokeMethod<bool>('updateCountdown', {
        'title': title,
        'text': text,
        'deadlineMs': deadlineMs,
      }) ??
      false;

  static Future<Map<String, dynamic>> backgroundSettings() async =>
      Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('backgroundSettings') ??
            const {},
      );

  static Future<void> openChannelSettings(String? channelId) => channel
      .invokeMethod<void>('openChannelSettings', {'channelId': channelId});

  static Future<void> openAppDetails() =>
      channel.invokeMethod<void>('openAppDetails');
}
