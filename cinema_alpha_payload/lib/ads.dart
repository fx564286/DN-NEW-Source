import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonetizationConfig {
  static const String adFreeProductId = 'remove_ads_lifetime_2900';
  static const String fallbackPriceLabel = '비활성화';
  static const int freeWatchSlots = 3;
}

class AdRuntime {
  static bool get ready => false;
  static Object? get lastError => null;
  static Future<bool> ensureInitialized() async => false;
}

class RewardManager {
  static const String _bonusUntilKey = 'reward_bonus_until';

  Future<DateTime?> bonusUntil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_bonusUntilKey);
      return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (error, stack) {
      debugPrint('Reward state read skipped safely: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<DateTime?> grantBonus() async {
    final until = DateTime.now().add(const Duration(hours: 24));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bonusUntilKey, until.millisecondsSinceEpoch);
    } catch (error, stack) {
      debugPrint('Reward state save skipped safely: $error');
      debugPrintStack(stackTrace: stack);
    }
    return until;
  }
}

/// 좌석 감시 안정화 빌드에서는 광고·인앱결제 SDK를 로드하지 않습니다.
/// 기존 화면과의 호환을 위해 동일한 공개 인터페이스만 유지합니다.
class MonetizationController extends ChangeNotifier {
  bool _initialized = false;
  bool _disposed = false;

  bool storeAvailable = false;
  bool purchasePending = false;
  bool restorePending = false;
  bool rewardPending = false;
  bool isAdFree = true;
  Object? adFreeProduct;
  DateTime? bonusUntil;
  String? statusMessage = '광고·결제 기능은 좌석 감시 안정화를 위해 비활성화되어 있습니다.';

  bool get initialized => _initialized;
  bool get bonusActive => bonusUntil?.isAfter(DateTime.now()) ?? false;
  String get priceLabel => MonetizationConfig.fallbackPriceLabel;
  int get watchLimit => 1 << 20;
  String get watchLimitLabel => '무제한';

  bool canCreateWatch(int currentCount) => true;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    bonusUntil = await RewardManager().bonusUntil();
    _initialized = true;
    _safeNotify();
  }

  Future<void> refreshProducts() async {
    storeAvailable = false;
    statusMessage = '광고·결제 SDK 없이 좌석 감시 기능만 사용합니다.';
    _safeNotify();
  }

  Future<bool> buyAdFree() async {
    isAdFree = true;
    purchasePending = false;
    statusMessage = '현재 빌드는 기본적으로 광고 없이 제공됩니다.';
    _safeNotify();
    return true;
  }

  Future<void> restorePurchases() async {
    restorePending = false;
    statusMessage = '현재 빌드에는 복원할 결제 항목이 없습니다.';
    _safeNotify();
  }

  Future<bool> showRewardedBonus() async {
    rewardPending = true;
    _safeNotify();
    bonusUntil = await RewardManager().grantBonus();
    rewardPending = false;
    statusMessage = '광고 없이 24시간 보너스 슬롯을 적용했습니다.';
    _safeNotify();
    return true;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppBannerAd extends StatelessWidget {
  const AppBannerAd({super.key, required this.controller});

  final MonetizationController controller;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
