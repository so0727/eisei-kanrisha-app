import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../common/premium_upgrade_dialog.dart';

/// 出題設定ボトムシート
class QuizSettingsSheet extends ConsumerStatefulWidget {
  final QuizMode mode;
  final String? category;
  final String? year;

  const QuizSettingsSheet({
    super.key,
    required this.mode,
    this.category,
    this.year,
  });

  @override
  ConsumerState<QuizSettingsSheet> createState() => _QuizSettingsSheetState();
}

class _QuizSettingsSheetState extends ConsumerState<QuizSettingsSheet> {
  int? _selectedCount; // null = 全問
  CategoryFilter _selectedFilter = CategoryFilter.all; // カテゴリフィルター


  @override
  void initState() {
    super.initState();
    // 初期値の設定
    // ビルド後にサブスクリプション状態を確認して設定するため、ここでは何もしない
    // buildメソッド内で初期値を決定する
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回のみ初期値を設定
    if (_selectedCount == null && widget.mode != QuizMode.year) {
      final subscription = ref.read(userSubscriptionProvider);
      if (subscription == UserSubscriptionStatus.free) {
        _selectedCount = 10;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = ref.watch(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;

    // 年度別（模擬試験）の場合は出題数選択不要
    final isYearMode = widget.mode == QuizMode.year;

    // フリープランで全問(null)や20問が選択されている場合、強制的に10問にする
    // ※ build中の変数変更はアンチパターンだが、初期値整合性のために暫定対応
    if (isFree && !isYearMode && (_selectedCount == null || _selectedCount == 20)) {
      _selectedCount = 10;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),

          // タイトル
          Text(
            _getModeTitle(),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _getModeDescription(),
            style: theme.textTheme.bodyMedium,
          ),

          if (!isYearMode) ...[
            const SizedBox(height: 28),
            Text(
              '出題数を選択',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // 出題数ボタン
            Row(
              children: [
                Expanded(
                  child: _buildCountChip(context, 10, '10問'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCountChip(context, 20, '20問'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCountChip(context, null, '全問'),
                ),
              ],
            ),
          ],

          // カテゴリ別の場合、フィルタードロップダウンを表示（Pro限定）
          if (widget.mode == QuizMode.category) ...[
            const SizedBox(height: 20),
            _buildFilterDropdown(context, theme),
          ],

          const SizedBox(height: 28),

          // スタートボタン
          SizedBox(
            width: double.infinity,
            height: 68,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _startQuiz(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    _getStartButtonText(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(BuildContext context, int? count, String label) {
    // 課金状態チェック
    final subscription = ref.watch(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;
    
    // 20問と全問はPro限定
    final isProFeature = count == 20 || count == null;
    final isLocked = isFree && isProFeature;

    final isSelected = _selectedCount == count;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          showDialog(
            context: context,
            builder: (_) => const PremiumUpgradeDialog(),
          );
        } else {
          setState(() => _selectedCount = count);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          color: isLocked
              ? AppTheme.cardColor.withValues(alpha: 0.5) // ロック時は少し薄く
              : (isSelected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.background),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.grey.withValues(alpha: 0.3)
                : (isSelected ? AppTheme.primary : AppTheme.divider),
            width: isLocked ? 1 : 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isLocked
                        ? Colors.grey
                        : (isSelected ? AppTheme.primary : AppTheme.textPrimary),
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.lock, size: 16, color: Colors.grey),
                ],
              ],
            ),
            if (isProFeature && !isLocked)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case QuizMode.allRandom:
        return '全問ランダム';
      case QuizMode.category:
        return widget.category ?? 'カテゴリ別';
      case QuizMode.year:
        return '${_formatYear(widget.year ?? '')} 模擬試験';
      case QuizMode.wrongOnly:
        return '間違えた問題を復習';
      case QuizMode.bookmarked:
        return 'ブックマークした問題';
      default:
        return '出題設定';
    }
  }

  String _getModeDescription() {
    switch (widget.mode) {
      case QuizMode.allRandom:
        return '全問題からランダムに出題します';
      case QuizMode.category:
        return 'このカテゴリの問題のみ出題します';
      case QuizMode.year:
        return '本番と同じ形式で模擬試験をします';
      case QuizMode.wrongOnly:
        return '間違えた問題を集中的に復習します';
      case QuizMode.bookmarked:
        return 'ブックマークした問題のみ出題します';
      default:
        return '';
    }
  }

  String _getStartButtonText() {
    if (widget.mode == QuizMode.year) {
      return 'スタート';
    }
    if (_selectedCount != null) {
      return '$_selectedCount問 スタート';
    }
    // フリープランで全問が選択されていたら（バグ回避）、本来は表示されないはずだが
    final subscription = ref.read(userSubscriptionProvider);
    if (subscription == UserSubscriptionStatus.free && _selectedCount == null) {
       return '10問 スタート';
    }
    if (subscription == UserSubscriptionStatus.free && _selectedCount == 20) {
       return '10問 スタート';
    }
    return '全問 スタート';
  }

  String _formatYear(String year) {
    final parts = year.split('_');
    if (parts.length == 2) {
      final y = parts[0];
      final suffix = parts[1];
      final n = int.tryParse(suffix) ?? 0;
      if (n == 1 || n == 4) {
        return '$y年 4月公表';
      } else if (n == 2 || n == 10) {
        return '$y年 10月公表';
      }
      return '$y年 $suffix月公表';
    }
    return year;
  }

  void _startQuiz(BuildContext context) {
    // 最終チェック：フリープランでロックされた設定なら10問に強制変更
    final subscription = ref.read(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;
    
    // 年度別モード以外で、かつフリープランで、20問または全問(null)が選択されている場合
    int? finalCount = _selectedCount;
    if (widget.mode != QuizMode.year && isFree) {
      if (_selectedCount == null || _selectedCount == 20) {
         finalCount = 10;
      }
    }

    final config = QuizConfig(
      mode: widget.mode,
      questionCount: finalCount,
      category: widget.category,
      year: widget.year,
      categoryFilter: _selectedFilter,
    );

    Navigator.of(context).pop(); // ボトムシートを閉じる
    context.goNamed('quiz', extra: {
      'fromContinue': false,
      'config': config,
    });
  }

  /// カテゴリフィルタードロップダウン
  Widget _buildFilterDropdown(BuildContext context, ThemeData theme) {
    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '出題範囲',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CategoryFilter>(
              value: _selectedFilter,
              isExpanded: true,
              dropdownColor: AppTheme.cardColor,
              style: theme.textTheme.bodyLarge,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
              items: const [
                DropdownMenuItem(
                  value: CategoryFilter.all,
                  child: Text('全問'),
                ),
                DropdownMenuItem(
                  value: CategoryFilter.wrongOnly,
                  child: Text('間違えた問題のみ'),
                ),
                DropdownMenuItem(
                  value: CategoryFilter.unansweredOnly,
                  child: Text('未回答のみ'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFilter = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
