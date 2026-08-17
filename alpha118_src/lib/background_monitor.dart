import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class BackgroundMonitorStatus {
  const BackgroundMonitorStatus({
    required this.running,
    required this.notificationPermissionGranted,
    required this.batteryOptimizationIgnored,
    required this.activeWatchCount,
    required this.intervalSeconds,
    required this.lastCheckAtMillis,
    required this.nextCheckAtMillis,
    required this.lastCheckedCount,
    required this.lastErrorCount,
    required this.cycleInProgress,
  });

  final bool running;
  final bool notificationPermissionGranted;
  final bool batteryOptimizationIgnored;
  final int activeWatchCount;
  final int intervalSeconds;
  final int lastCheckAtMillis;
  final int nextCheckAtMillis;
  final int lastCheckedCount;
  final int lastErrorCount;
  final bool cycleInProgress;

  DateTime? get lastCheckAt => lastCheckAtMillis <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCheckAtMillis);

  DateTime? get nextCheckAt => nextCheckAtMillis <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(nextCheckAtMillis);

  factory BackgroundMonitorStatus.fromMap(Map<Object?, Object?> map) =>
      BackgroundMonitorStatus(
        running: map['running'] == true,
        notificationPermissionGranted:
            map['notificationPermissionGranted'] == true,
        batteryOptimizationIgnored:
            map['batteryOptimizationIgnored'] == true,
        activeWatchCount: _asInt(map['activeWatchCount']),
        intervalSeconds: _asInt(map['intervalSeconds'], fallback: 30),
        lastCheckAtMillis: _asInt(map['lastCheckAtMillis']),
        nextCheckAtMillis: _asInt(map['nextCheckAtMillis']),
        lastCheckedCount: _asInt(map['lastCheckedCount']),
        lastErrorCount: _asInt(map['lastErrorCount']),
        cycleInProgress: map['cycleInProgress'] == true,
      );

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static const unavailable = BackgroundMonitorStatus(
    running: false,
    notificationPermissionGranted: false,
    batteryOptimizationIgnored: false,
    activeWatchCount: 0,
    intervalSeconds: 30,
    lastCheckAtMillis: 0,
    nextCheckAtMillis: 0,
    lastCheckedCount: 0,
    lastErrorCount: 0,
    cycleInProgress: false,
  );
}

class BackgroundMonitor {
  BackgroundMonitor._();

  static const _channel = MethodChannel('cineseat/background');
  static const intervalPreferenceKey = 'settings_watch_interval_seconds';

  static Future<void> syncWatches(
    List<WatchItem> items, {
    int? intervalSeconds,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final interval =
          intervalSeconds ?? prefs.getInt(intervalPreferenceKey) ?? 30;
      final active = items.where((item) => item.active).toList();
      await _channel.invokeMethod<void>('sync', {
        'watchesJson': jsonEncode(active.map((item) => item.toJson()).toList()),
        'intervalSeconds': interval.clamp(15, 120),
      });
    } on MissingPluginException {
      debugPrint('Background monitor is unavailable on this platform.');
    } on PlatformException catch (error, stack) {
      debugPrint('Background monitor sync failed: ${error.message}');
      debugPrintStack(stackTrace: stack);
    } catch (error, stack) {
      debugPrint('Background monitor sync failed safely: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error, stack) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  static Future<void> openBatterySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } catch (error, stack) {
      debugPrint('Battery settings open failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> openNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (error, stack) {
      debugPrint('Notification settings open failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<BackgroundMonitorStatus> status() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return BackgroundMonitorStatus.unavailable;
    }
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      return value == null
          ? BackgroundMonitorStatus.unavailable
          : BackgroundMonitorStatus.fromMap(value);
    } catch (error, stack) {
      debugPrint('Background monitor status failed: $error');
      debugPrintStack(stackTrace: stack);
      return BackgroundMonitorStatus.unavailable;
    }
  }
}
