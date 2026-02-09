import 'package:flutter/material.dart';
import '../../app/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../utils/purchase_service.dart';

class PremiumUpgradeDialog extends ConsumerWidget {
  const PremiumUpgradeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open, size: 60, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'Proプランで制限解除',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '最新2年分の過去問はProプラン限定です。\nアップグレードしてすべての問題に挑戦しよう！',
              style: TextStyle(fontSize: 16, color: AppTheme.textBody),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(purchaseServiceProvider).buyPro();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Proプランにアップグレード',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(purchaseServiceProvider).restorePurchases();
              },
              child: const Text('購入を復元する', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('あとで', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
