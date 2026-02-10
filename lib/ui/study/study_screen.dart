import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../common/premium_upgrade_dialog.dart';
import '../home/quiz_settings_sheet.dart';

/// 学習タブ（カテゴリ別・年度別）
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  bool _isInitialized = false;
  List<String> _categories = [];
  List<String> _years = [];
  Map<String, int> _categoryCounts = {};
  Map<String, int> _freeCategoryCounts = {}; // Freeプラン: 2022-2023年のみ
  Map<String, int> _yearCounts = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final repo = ref.read(questionRepositoryProvider);
    await repo.loadQuestions();
    final categories = await repo.getCategories();
    final years = await repo.getYears();
    final categoryCounts = await repo.getCategoryCounts();
    final freeCategoryCounts = await repo.getFreeCategoryCounts();
    final yearCounts = await repo.getYearCounts();

    if (mounted) {
      setState(() {
        _categories = categories;
        _years = years;
        _categoryCounts = categoryCounts;
        _freeCategoryCounts = freeCategoryCounts;
        _yearCounts = yearCounts;
        _isInitialized = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ヘッダー
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text('学習モード', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      onPressed: () => context.pushNamed('search'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
                      onPressed: () => context.pushNamed('settings'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '苦手なカテゴリを集中攻略、年度別で模擬試験',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // 集中特訓セクション
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSectionTitle(theme, '集中特訓', Icons.psychology),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSpecialCard(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // カテゴリ別セクション
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSectionTitle(theme, 'カテゴリ別', Icons.category),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCategoryTile(
                      context, _categories[index], progress),
                  childCount: _categories.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // 年度別セクション
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child:
                    _buildSectionTitle(theme, '年度別 模擬試験', Icons.history_edu),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _buildYearTile(context),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }

  Widget _buildCategoryTile(
      BuildContext context, String category, ProgressState progress) {
    final totalCount = _categoryCounts[category] ?? 0; // Pro用: 全問題数
    final freeCount = _freeCategoryCounts[category] ?? 0; // Free用: 2022-2023年のみ
    final subscription = ref.watch(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;
    
    final categoryCorrect = _getCategoryCorrectCount(category, progress);
    final categoryAnswered = _getCategoryAnsweredCount(category, progress);
    final rate =
        categoryAnswered > 0 ? categoryCorrect / categoryAnswered : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCategoryActionSheet(context, category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 問題数表示：Freeユーザーには解ける問題数とPro問題数を表示
                      isFree
                          ? RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 14, color: AppTheme.textSecondary),
                                children: [
                                  TextSpan(text: '$freeCount問'),
                                  const TextSpan(
                                    text: '  ',
                                  ),
                                  TextSpan(
                                    text: '(Proなら$totalCount問)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.accent.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              '$totalCount問',
                              style: const TextStyle(
                                  fontSize: 14, color: AppTheme.textSecondary),
                            ),
                    ],
                  ),
                ),
                if (categoryAnswered > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rate >= 0.6
                          ? AppTheme.correct.withValues(alpha: 0.15)
                          : AppTheme.incorrect.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(rate * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            rate >= 0.6 ? AppTheme.correct : AppTheme.incorrect,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/number-slot'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accent.withValues(alpha: 0.1),
                AppTheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.casino, color: AppTheme.accent, size: 28),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '数字スロット暗記',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '基準値や数値を楽しく暗記しよう！',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill,
                  color: AppTheme.accent, size: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearTile(BuildContext context) {
    // ユーザーの課金状態を取得
    final subscription = ref.watch(userSubscriptionProvider);
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final year = _years[index];
            final count = _yearCounts[year] ?? 0;
            
            // 2018, 2019, 2020, 2021, 2024, 2025年度はPro限定
            final isPremiumYear = year.startsWith('2018') || year.startsWith('2019') || year.startsWith('2020') || year.startsWith('2021') || year.startsWith('2024') || year.startsWith('2025');
            final isLocked = isPremiumYear && subscription == UserSubscriptionStatus.free;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (isLocked) {
                      showDialog(
                        context: context,
                        builder: (_) => const PremiumUpgradeDialog(),
                      );
                    } else {
                      _showSettingsSheet(context, QuizMode.year, year: year);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isLocked 
                          ? AppTheme.cardColor.withValues(alpha: 0.6) 
                          : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLocked ? AppTheme.divider : AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isLocked
                                ? Colors.grey.withValues(alpha: 0.2)
                                : AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLocked ? Icons.lock : Icons.description,
                            color: isLocked ? Colors.grey : AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatYear(year),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isLocked ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (isLocked) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Pro',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count問',
                                style: const TextStyle(
                                    fontSize: 14, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isLocked ? Icons.lock_outline : Icons.chevron_right,
                          color: isLocked ? Colors.grey : AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _years.length,
        ),
      ),
    );
  }

  // ===== ヘルパー =====

  void _showSettingsSheet(BuildContext context, QuizMode mode,
      {String? category, String? year}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QuizSettingsSheet(mode: mode, category: category, year: year),
    );
  }

  String _formatYear(String year) {
    final parts = year.split('_');
    if (parts.length == 2) {
      final y = parts[0];
      final n = int.tryParse(parts[1]) ?? 0;
      if (n == 1 || n == 4) return '$y年 4月公表';
      if (n == 2 || n == 10) return '$y年 10月公表';
      return '$y年 ${parts[1]}月公表';
    }
    return year;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('有害')) return AppTheme.incorrect;
    if (category.contains('労働生理')) return AppTheme.accent;
    return AppTheme.primary;
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('関係法令') && category.contains('有害')) {
      return Icons.gavel;
    }
    if (category.contains('関係法令')) return Icons.balance;
    if (category.contains('労働衛生') && category.contains('有害')) {
      return Icons.warning;
    }
    if (category.contains('労働衛生')) return Icons.health_and_safety;
    if (category.contains('労働生理')) return Icons.biotech;
    return Icons.quiz;
  }

  int _getCategoryCorrectCount(String category, ProgressState progress) {
    final repo = ref.read(questionRepositoryProvider);
    if (repo.cachedQuestions == null) return 0;
    final ids = repo.cachedQuestions!
        .where((q) => q.category == category)
        .map((q) => q.id)
        .toSet();
    return progress.correctIds.intersection(ids).length;
  }

  int _getCategoryAnsweredCount(String category, ProgressState progress) {
    final repo = ref.read(questionRepositoryProvider);
    if (repo.cachedQuestions == null) return 0;
    final ids = repo.cachedQuestions!
        .where((q) => q.category == category)
        .map((q) => q.id)
        .toSet();
    return progress.answeredIds.intersection(ids).length;
  }

  /// カテゴリアクションシート（クイズ or 問題一覧）
  void _showCategoryActionSheet(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // クイズ開始
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_arrow, color: AppTheme.primary),
                ),
                title: const Text(
                  'クイズ開始',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  '問題を解く',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsSheet(context, QuizMode.category, category: category);
                },
              ),
              // 問題一覧
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.list_alt, color: AppTheme.accent),
                ),
                title: const Text(
                  '問題一覧',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  '問題を閲覧・個別に解く',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  context.pushNamed('question_list', extra: {'category': category});
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
