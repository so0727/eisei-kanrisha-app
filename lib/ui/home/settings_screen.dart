import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../utils/local_notification_service.dart';
import '../../utils/purchase_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(userSubscriptionProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final isPro = subscription == UserSubscriptionStatus.pro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // ステータス表示
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPro
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPro ? AppTheme.accent : Colors.grey.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPro ? Icons.verified : Icons.person_outline,
                  color: isPro ? AppTheme.accent : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro ? 'Proプラン契約中' : '無料プラン',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!isPro)
                      const Text(
                        'アップグレードして制限を解除',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 表示・サウンド設定
          _buildSectionHeader('表示・サウンド'),
          ListTile(
            title: const Text('文字サイズ'),
            subtitle: Row(
              children: [
                const Icon(Icons.text_fields, size: 16),
                Expanded(
                  child: Slider(
                    value: appSettings.textScale,
                    min: 1.0,
                    max: 1.5,
                    divisions: 5,
                    label: appSettings.textScale.toString(),
                    activeColor: AppTheme.primary,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setTextScale(value);
                    },
                  ),
                ),
                const Icon(Icons.text_fields, size: 24),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('効果音'),
            value: appSettings.enableSound,
            activeColor: AppTheme.primary,
            onChanged: (value) {
              ref.read(appSettingsProvider.notifier).setEnableSound(value);
            },
          ),
          
          const Divider(),

          // 通知設定
          _buildSectionHeader('通知'),
          SwitchListTile(
            title: const Text('学習リマインダー'),
            subtitle: const Text('毎日決まった時間に通知'),
            value: appSettings.reminderTime != null,
            activeColor: AppTheme.primary,
            onChanged: (value) async {
              if (value) {
                // Default to 21:00
                const defaultTime = TimeOfDay(hour: 21, minute: 0);
                await ref.read(appSettingsProvider.notifier).setReminderTime(defaultTime);
                await LocalNotificationService().scheduleDailyReminder(defaultTime);
              } else {
                await ref.read(appSettingsProvider.notifier).setReminderTime(null);
                await LocalNotificationService().cancelAllReminders();
              }
            },
          ),
          if (appSettings.reminderTime != null)
            ListTile(
              title: const Text('通知時間'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appSettings.reminderTime!.format(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: appSettings.reminderTime!,
                );
                if (time != null) {
                  await ref.read(appSettingsProvider.notifier).setReminderTime(time);
                  await LocalNotificationService().scheduleDailyReminder(time);
                }
              },
            ),

          const Divider(),

          // 学習設定
          _buildSectionHeader('学習設定'),
          SwitchListTile(
            title: const Text('正解時も解説を表示'),
            subtitle: const Text('OFFのときは正解すると自動で次へ'),
            value: appSettings.showExplanationAlways,
            activeColor: AppTheme.primary,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .setShowExplanationAlways(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: AppTheme.incorrect),
            title: const Text('学習履歴をリセット'),
            subtitle: const Text('進捗・正解記録を初期化'),
            onTap: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('学習履歴のリセット'),
                  content: const Text(
                    'これまでの学習記録（正解数・進捗・ブックマーク）がすべて消去されます。\n本当によろしいですか？',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'リセット',
                        style: TextStyle(color: AppTheme.incorrect),
                      ),
                    ),
                  ],
                ),
              );

              if (result == true) {
                await ref.read(progressProvider.notifier).resetAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('学習履歴をリセットしました')),
                  );
                }
              }
            },
          ),

          const Divider(),

          // 課金関連
          _buildSectionHeader('課金・プラン'),
          if (!isPro)
            ListTile(
              leading: const Icon(Icons.star, color: AppTheme.accent),
              title: const Text('Proプランにアップグレード'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(purchaseServiceProvider).buyPro();
              },
            ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('購入を復元する'),
            subtitle: const Text('機種変更時など'),
            onTap: () async {
              await ref.read(purchaseServiceProvider).restorePurchases();
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('復元処理が完了しました')),
                 );
              }
            },
          ),
          if (isPro)
            ListTile( // デバッグ用ボタン（リリース時は隠すか削除）
               leading: const Icon(Icons.bug_report),
               title: const Text('デバッグ: Freeに戻す'),
               onTap: () async {
                  await ref.read(userSubscriptionProvider.notifier).debugResetToFree();
               },
            ),

          const Divider(height: 32),

          // アプリ情報
          _buildSectionHeader('アプリについて'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: 利用規約URLへ遷移
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // TODO: プライバシーポリシーURLへ遷移
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            trailing: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
