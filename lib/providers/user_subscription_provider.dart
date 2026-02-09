import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserSubscriptionStatus {
  free,
  pro,
}

class UserSubscriptionNotifier extends StateNotifier<UserSubscriptionStatus> {
  UserSubscriptionNotifier() : super(UserSubscriptionStatus.free) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool('is_pro_user') ?? false;
    state = isPro ? UserSubscriptionStatus.pro : UserSubscriptionStatus.free;
  }

  Future<void> enablePro() async {
    state = UserSubscriptionStatus.pro;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_user', true);
  }

  Future<void> restore() async {
    // 実際にはレシート検証などが走るが、簡易的に保存された状態を再読み込み
    await _loadStatus();
  }

  // デバッグ用：Freeに戻す
  Future<void> debugResetToFree() async {
    state = UserSubscriptionStatus.free;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_pro_user');
  }
}

final userSubscriptionProvider =
    StateNotifierProvider<UserSubscriptionNotifier, UserSubscriptionStatus>(
        (ref) {
  return UserSubscriptionNotifier();
});
