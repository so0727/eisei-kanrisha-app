import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/app_settings_provider.dart';
import 'quiz_settings_sheet.dart';

/// ホーム画面
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isInitialized = false;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final repo = ref.read(questionRepositoryProvider);
    final questions = await repo.loadQuestions();
    await ref
        .read(progressProvider.notifier)
        .loadProgress(questions.length);
    final categories = await repo.getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _buildCompactHeader(theme),
              const SizedBox(height: 16),
              _buildExamDateCard(context, appSettings.targetExamDate),
              const SizedBox(height: 20),
              _buildStreakAndPredictionRow(context, progress),
// ...
              const SizedBox(height: 16),
              _buildTodayGoalCard(progress),
              const SizedBox(height: 20),
              _buildTodayButton(context),
              const SizedBox(height: 20),
              _buildQuickGrid(context, progress),
              const SizedBox(height: 20),
              _buildProgressCard(context, progress),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 左側の余白調整 (設定アイコン文)
        const SizedBox(width: 48),
        const Spacer(),
        Text(
          '衛生管理者',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '（第1種）',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.8),
                AppTheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '爆速合格',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.textSecondary),
          onPressed: () {
            context.pushNamed('search');
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
          onPressed: () {
            context.pushNamed('settings');
          },
        ),
      ],
    );
  }

  Widget _buildStreakAndPredictionRow(
      BuildContext context, ProgressState progress) {
    final streak = progress.streakDays;
    final prediction = _calculatePassPrediction(progress);

    return Row(
      children: [
        Expanded(
          child: _buildMiniCard(
            icon: streak > 0 ? Icons.local_fire_department : Icons.wb_sunny,
            value: '$streak日',
            label: '連続学習',
            color: streak >= 7
                ? AppTheme.incorrect
                : streak > 0
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniCard(
            icon: prediction >= 80
                ? Icons.emoji_events
                : prediction >= 50
                    ? Icons.trending_up
                    : Icons.school,
            value: '${prediction.toStringAsFixed(0)}%',
            label: '合格予測',
            color: prediction >= 80
                ? AppTheme.correct
                : prediction >= 50
                    ? AppTheme.accent
                    : AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  static const int _dailyGoalCount = 10;

  Widget _buildTodayGoalCard(ProgressState progress) {
    final count = progress.todayAnsweredCount;
    final achieved = count >= _dailyGoalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved
              ? AppTheme.correct.withValues(alpha: 0.4)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            achieved ? Icons.check_circle : Icons.flag,
            size: 28,
            color: achieved ? AppTheme.correct : AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日の目標 10 問',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achieved
                      ? '✓ 達成！'
                      : 'あと ${(_dailyGoalCount - count).clamp(0, _dailyGoalCount)} 問',
                  style: TextStyle(
                    fontSize: 14,
                    color: achieved
                        ? AppTheme.correct
                        : AppTheme.textSecondary,
                    fontWeight: achieved ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (achieved)
            const Icon(Icons.emoji_events,
                color: AppTheme.correct, size: 32),
        ],
      ),
    );
  }

  Widget _buildTodayButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.goNamed('quiz', extra: {
          'fromContinue': false,
          'config': const QuizConfig(
            mode: QuizMode.allRandom,
            questionCount: 10,
          ),
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.play_circle_filled, size: 48, color: Colors.black),
            SizedBox(height: 8),
            Text(
              '今日の10問',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '5分で終わる！タップで即スタート',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context, ProgressState progress) {
    final wrongCount = progress.wrongIds.length;
    final bookmarkCount = progress.bookmarkedIds.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGridButton(
                icon: Icons.shuffle,
                label: '全問ランダム',
                color: AppTheme.primary,
                onTap: () =>
                    _showSettingsSheet(context, QuizMode.allRandom),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGridButton(
                icon: Icons.replay,
                label: '続きから',
                color: AppTheme.textPrimary,
                enabled: progress.answeredIds.isNotEmpty,
                onTap: () {
                  context.goNamed('quiz', extra: {'fromContinue': true});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGridButton(
                icon: Icons.refresh,
                label: '復習 ($wrongCount)',
                color: AppTheme.incorrect,
                enabled: wrongCount > 0,
                onTap: () =>
                    _showSettingsSheet(context, QuizMode.wrongOnly),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGridButton(
                icon: Icons.bookmark,
                label: 'ブックマーク ($bookmarkCount)',
                color: AppTheme.accent,
                enabled: bookmarkCount > 0,
                onTap: () => _showBookmarkActionSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 数字スロット暗記モード
        _buildNumberSlotButton(context),
      ],
    );
  }

  /// 数字スロット暗記ボタン（目立つデザイン）
  Widget _buildNumberSlotButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.pushNamed('number-slot');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accent,
              AppTheme.accent.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.casino,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数字スロット暗記',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '数値だけをサクッと覚える！',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : AppTheme.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? effectiveColor.withValues(alpha: 0.3)
                  : AppTheme.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: effectiveColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, ProgressState progress) {
    final percent = progress.progressPercent;
    final percentText = (percent * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('学習進捗',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(
                '$percentText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: percent >= 0.8
                      ? AppTheme.correct
                      : percent >= 0.5
                          ? AppTheme.accent
                          : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: AppTheme.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 0.8
                    ? AppTheme.correct
                    : percent >= 0.5
                        ? AppTheme.accent
                        : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.answeredIds.length} / ${progress.totalQuestions}問',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
              Text(
                '正解 ${progress.correctIds.length}問',
                style:
                    const TextStyle(fontSize: 14, color: AppTheme.correct),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, QuizMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuizSettingsSheet(mode: mode),
    );
  }

  /// ブックマークアクションシート（クイズ or 問題一覧）
  void _showBookmarkActionSheet(BuildContext context) {
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
              const Text(
                'ブックマーク',
                style: TextStyle(
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
                  'ブックマークした問題を解く',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsSheet(context, QuizMode.bookmarked);
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
                  context.pushNamed('bookmarked_list');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  double _calculatePassPrediction(ProgressState progress) {
    if (progress.answeredIds.isEmpty) return 0;
    final repo = ref.read(questionRepositoryProvider);
    if (repo.cachedQuestions == null) return 0;

    final categoryRates = <String, double>{};
    for (final cat in _categories) {
      final catIds = repo.cachedQuestions!
          .where((q) => q.category == cat)
          .map((q) => q.id)
          .toSet();
      final answered = progress.answeredIds.intersection(catIds).length;
      final correct = progress.correctIds.intersection(catIds).length;
      if (answered > 0) categoryRates[cat] = correct / answered;
    }
    if (categoryRates.isEmpty) return 0;

    final overallRate =
        progress.correctIds.length / progress.answeredIds.length;
    final allAbove40 = categoryRates.values.every((r) => r >= 0.4);
    final coverage = progress.totalQuestions > 0
        ? progress.answeredIds.length / progress.totalQuestions
        : 0.0;

    double base;
    if (overallRate >= 0.6 && allAbove40) {
      base = 60 + (overallRate - 0.6) * 100;
    } else if (overallRate >= 0.6) {
      base = 40 + (overallRate - 0.6) * 50;
    } else {
      base = overallRate * 66;
    }

    final conf = coverage < 0.1
        ? 0.3
        : coverage < 0.3
            ? 0.5 + (coverage / 0.3) * 0.3
            : 0.8 + (coverage.clamp(0.3, 1.0) - 0.3) * 0.29;

    return (base * conf).clamp(0, 99);
  }

  Widget _buildExamDateCard(BuildContext context, DateTime? targetDate) {
    if (targetDate == null) {
      return GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 30)),
            firstDate: now,
            lastDate: now.add(const Duration(days: 365 * 5)),
          );
          if (date != null) {
            ref.read(appSettingsProvider.notifier).setTargetExamDate(date);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_calendar, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                '試験日を設定する',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysLeft = examDay.difference(today).inDays;

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: targetDate,
          firstDate: now,
          lastDate: now.add(const Duration(days: 365 * 5)),
        );
        if (date != null) {
          ref.read(appSettingsProvider.notifier).setTargetExamDate(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '試験まであと',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${targetDate.year}/${targetDate.month}/${targetDate.day}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              daysLeft > 0 ? '$daysLeft 日' : (daysLeft == 0 ? '試験当日' : '終了'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: daysLeft <= 7 ? AppTheme.incorrect : AppTheme.primary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
