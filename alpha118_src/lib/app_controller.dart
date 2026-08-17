import 'package:flutter/foundation.dart';

import 'background_monitor.dart';
import 'models.dart';
import 'services.dart';

class AppController extends ChangeNotifier {
  AppController({WatchStore? store}) : _store = store ?? WatchStore();
  final WatchStore _store;

  bool loading = true;
  String? startupWarning;
  final List<WatchItem> items = [];

  Future<void> initialize() async {
    loading = true;
    startupWarning = null;
    notifyListeners();

    try {
      final restored = await _store.load();
      items
        ..clear()
        ..addAll(restored);
      await BackgroundMonitor.syncWatches(items);
    } catch (error, stack) {
      debugPrint('Watch store restore failed: $error');
      debugPrintStack(stackTrace: stack);
      items.clear();
      startupWarning = '저장된 감시 목록을 복원하지 못해 빈 목록으로 안전하게 시작했습니다.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> add(WatchItem item) async {
    items.add(item);
    await _saveSafely();
    await BackgroundMonitor.requestNotificationPermission();
    await BackgroundMonitor.syncWatches(items);
  }

  Future<void> toggle(WatchItem item) async {
    item.active = !item.active;
    await _saveSafely();
    if (item.active) await BackgroundMonitor.requestNotificationPermission();
    await BackgroundMonitor.syncWatches(items);
  }

  Future<void> remove(WatchItem item) async {
    items.removeWhere((value) => value.id == item.id);
    await _saveSafely();
    await BackgroundMonitor.syncWatches(items);
  }

  Future<void> clear() async {
    items.clear();
    await _saveSafely();
    await BackgroundMonitor.syncWatches(items);
  }

  Future<void> refreshBackgroundMonitor() =>
      BackgroundMonitor.syncWatches(items);

  Future<void> _saveSafely() async {
    startupWarning = null;
    try {
      await _store.save(items);
    } catch (error, stack) {
      debugPrint('Watch store save failed: $error');
      debugPrintStack(stackTrace: stack);
      startupWarning = '감시 목록을 기기에 저장하지 못했습니다. 저장공간을 확인해 주세요.';
    } finally {
      notifyListeners();
    }
  }
}
