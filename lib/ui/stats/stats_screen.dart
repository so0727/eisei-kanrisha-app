import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';

/// 成績タブ
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _isInitialized = false;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final repo = ref.read(questionRepositoryProvider);
    await repo.loadQuestions();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行
              Row(
                children: [
                  Text('成績', style: theme.textTheme.headlineLarge),
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
              const SizedBox(height: 8),
              Text(

                'あなたの学習状況を確認しましょう',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // 全体進捗の円グラフ風
              _buildOverallProgress(context, progress),
              const SizedBox(height: 24),

              // 学習履歴グラフ（日別回答数）
              _buildSectionTitle(theme, '学習履歴', Icons.show_chart),
              const SizedBox(height: 12),
              _buildLearningHistoryChart(context, progress),
              const SizedBox(height: 28),

              // カテゴリ別正答率
              _buildSectionTitle(theme, 'カテゴリ別 正答率', Icons.analytics),
              const SizedBox(height: 12),
              _buildCategoryBars(context, progress),
              const SizedBox(height: 28),

              // 学習カレンダー
              _buildSectionTitle(theme, '学習カレンダー', Icons.calendar_month),
              const SizedBox(height: 12),
              _buildStudyCalendar(context, progress),
              const SizedBox(height: 28),
            ],
          ),
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

  /// 全体進捗（大きな円グラフ風）
  Widget _buildOverallProgress(BuildContext context, ProgressState progress) {
    final percent = progress.progressPercent;
    final overallRate = progress.answeredIds.isNotEmpty
        ? progress.correctIds.length / progress.answeredIds.length
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // 円グラフ
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: overallRate,
                  color: overallRate >= 0.6
                      ? AppTheme.correct
                      : overallRate >= 0.4
                          ? AppTheme.accent
                          : AppTheme.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(overallRate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: overallRate >= 0.6
                              ? AppTheme.correct
                              : overallRate >= 0.4
                                  ? AppTheme.accent
                                  : AppTheme.primary,
                        ),
                      ),
                      const Text(
                        '正答率',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // 数値情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow(
                      '回答済', '${progress.answeredIds.length}問', AppTheme.textSecondary),
                  const SizedBox(height: 10),
                  _buildStatRow(
                      '正解', '${progress.correctIds.length}問', AppTheme.correct),
                  const SizedBox(height: 10),
                  _buildStatRow('間違い', '${progress.wrongIds.length}問',
                      AppTheme.incorrect),
                  const SizedBox(height: 10),
                  _buildStatRow(
                      '進捗',
                      '${(percent * 100).toStringAsFixed(0)}%',
                      AppTheme.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  /// カテゴリ別正答率バー
  Widget _buildCategoryBars(BuildContext context, ProgressState progress) {
    return Column(
      children: _categories.map((category) {
        final repo = ref.read(questionRepositoryProvider);
        if (repo.cachedQuestions == null) return const SizedBox.shrink();
        final ids = repo.cachedQuestions!
            .where((q) => q.category == category)
            .map((q) => q.id)
            .toSet();
        final answered = progress.answeredIds.intersection(ids).length;
        final correct = progress.correctIds.intersection(ids).length;
        final rate = answered > 0 ? correct / answered : 0.0;
        final total = ids.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    answered > 0
                        ? '${(rate * 100).toStringAsFixed(0)}% ($correct/$answered)'
                        : '未回答',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: answered > 0
                          ? (rate >= 0.6 ? AppTheme.correct : AppTheme.incorrect)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 正答率バー
              Stack(
                children: [
                  // 背景（全体）
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  // 回答済み範囲
                  FractionallySizedBox(
                    widthFactor: total > 0 ? answered / total : 0,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  // 正答率
                  FractionallySizedBox(
                    widthFactor:
                        total > 0 ? (correct / total).clamp(0.0, 1.0) : 0,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color:
                            rate >= 0.6 ? AppTheme.correct : AppTheme.accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 学習カレンダー（過去30日）
  Widget _buildStudyCalendar(BuildContext context, ProgressState progress) {
    final now = DateTime.now();
    final studySet = progress.studyDates.toSet();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 曜日ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['月', '火', '水', '木', '金', '土', '日']
                  .map((d) => SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 5週間分のカレンダー
            ...List.generate(5, (weekIndex) {
              // 今週の月曜日を求めて、そこから遡る
              final todayWeekday = now.weekday; // 1=月
              final thisMonday =
                  now.subtract(Duration(days: todayWeekday - 1));
              final weekMonday =
                  thisMonday.subtract(Duration(days: (4 - weekIndex) * 7));

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (dayIndex) {
                    final date = weekMonday.add(Duration(days: dayIndex));
                    final dateStr = ProgressState.dateString(date);
                    final isStudied = studySet.contains(dateStr);
                    final isToday = date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;
                    final isFuture = date.isAfter(now);

                    return SizedBox(
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isStudied
                              ? AppTheme.correct.withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                              color: isFuture
                                  ? AppTheme.divider
                                  : isStudied
                                      ? AppTheme.correct
                                      : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.correct.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('= 学習した日',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 学習履歴グラフ（直近14日間の日別回答数）
  Widget _buildLearningHistoryChart(
      BuildContext context, ProgressState progress) {
    const daysCount = 14;
    final now = DateTime.now();
    final counts = <String, int>{};
    for (int i = daysCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = ProgressState.dateString(d);
      counts[key] = progress.dailyAnswerCounts[key] ?? 0;
    }
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final labels = List.generate(daysCount, (i) {
      final d = now.subtract(Duration(days: daysCount - 1 - i));
      return '${d.month}/${d.day}';
    });

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '直近14日間の日別回答数',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysCount, (i) {
                  final key = ProgressState.dateString(
                      now.subtract(Duration(days: daysCount - 1 - i)));
                  final count = progress.dailyAnswerCounts[key] ?? 0;
                  final heightRatio = maxCount > 0 ? count / maxCount : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: (heightRatio * 80).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? AppTheme.primary.withValues(alpha: 0.7)
                                  : AppTheme.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// 円グラフ描画
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 背景円
    final bgPaint = Paint()
      ..color = AppTheme.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, bgPaint);

    // 進捗円
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
