import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/user_subscription_provider.dart';

/// 課金処理を担当するサービス
class PurchaseService {
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 商品ID (ストア側の設定と合わせる)
  static const String _proPlanId = 'eisei_kanrisha_pro_plan';

  PurchaseService(this._ref);

  /// 初期化：リスナーの登録
  void init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('Purchase Stream Error: $error');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// 購入処理の開始
  Future<void> buyPro() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Store not available');
      // For Debug: もしストアが使えなくても、開発中は強制的にProにする導線があっても良い
      // _ref.read(userSubscriptionProvider.notifier).enablePro();
      return;
    }

    // 商品情報の取得
    const Set<String> ids = {_proPlanId};
    final response = await _iap.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product not found: ${response.notFoundIDs}');
       // 開発用ダミー処理
       if (kDebugMode) {
         _ref.read(userSubscriptionProvider.notifier).enablePro();
       }
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    // 購入フロー開始
    // 非消耗型 (Non-consumable) として購入
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 復元処理
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// 購入更新時のコールバック
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 保留中
        debugPrint('Purchase Pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // 購入完了 or 復元成功
          _verifyAndEnablePro(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// 検証とPro有効化
  Future<void> _verifyAndEnablePro(PurchaseDetails purchaseDetails) async {
    // 本来はサーバーサイドでのレシート検証が推奨される
    // ここでは簡易的にIDチェックのみ
    if (purchaseDetails.productID == _proPlanId) {
      debugPrint('Purchase Verified: ${_proPlanId}');
      await _ref.read(userSubscriptionProvider.notifier).enablePro();
    }
  }
}

// プロバイダー定義
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService(ref);
  service.init();
  // アプリ終了時のdisposeはRiverpodが管理しにくいが、
  // シングルトン的に使うのでこのままでOK
  return service;
});
