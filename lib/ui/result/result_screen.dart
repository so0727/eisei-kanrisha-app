import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';

/// リザルト画面（カテゴリ別内訳付き）
class ResultScreen extends ConsumerStatefulWidget {
  final int correctCount;
  final int totalCount;

  const ResultScreen({
    super.key,
    required this.correctCount,
    required this.totalCount,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final percent = widget.totalCount > 0
        ? widget.correctCount / widget.totalCount
        : 0.0;
    final isPassed = percent >= 0.6;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPassed
                        ? AppTheme.correct.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    isPassed ? Icons.emoji_events : Icons.trending_up,
                    size: 52,
                    color: isPassed ? AppTheme.correct : AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  isPassed ? '素晴らしい！' : 'もう少し！',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: isPassed ? AppTheme.correct : AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CustomPaint(
                            painter: _CircularProgressPainter(
                              progress: percent,
                              color: isPassed
                                  ? AppTheme.correct
                                  : AppTheme.accent,
                            ),
                            child: Center(
                              child: Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isPassed
                                      ? AppTheme.correct
                                      : AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${widget.correctCount}',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: isPassed
                                          ? AppTheme.correct
                                          : AppTheme.accent,
                                    ),
                                  ),
                                  Text(
                                    ' / ${widget.totalCount}問',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPassed
                                      ? AppTheme.correct
                                          .withValues(alpha: 0.12)
                                      : AppTheme.incorrect
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPassed
                                      ? '合格ライン（60%）クリア！'
                                      : '合格ラインは60%です',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isPassed
                                        ? AppTheme.correct
                                        : AppTheme.incorrect,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCategoryBreakdown(context, progress),
              ),
              const SizedBox(height: 24),
              // Detailed Review List
              _buildDetailedReview(context),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.goNamed('quiz', extra: {'fromContinue': false});
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 28),
                      SizedBox(width: 8),
                      Text('もう一度チャレンジ'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (progress.wrongIds.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final session = ref.read(quizSessionProvider);
                      final wrongIds = <int>[];
                      for (int i = 0; i < session.questions.length; i++) {
                        final q = session.questions[i];
                        final userAnswer = session.userAnswers[i];
                        if (userAnswer != null && userAnswer != q.correctIndex) {
                          wrongIds.add(q.id);
                        }
                      }
                      
                      context.goNamed('quiz', extra: {
                        'fromContinue': false,
                        'config': QuizConfig(
                          mode: QuizMode.wrongOnly,
                          targetIds: wrongIds,
                        ),
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppTheme.incorrect, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh,
                            size: 24, color: AppTheme.incorrect),
                        const SizedBox(width: 8),
                        Text(
                          '間違えた問題を復習 (${progress.wrongIds.length}問)',
                          style: const TextStyle(color: AppTheme.incorrect),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.goNamed('home');
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, size: 28),
                      SizedBox(width: 8),
                      Text('ホームへ戻る'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      BuildContext context, ProgressState progress) {
    final repo = ref.read(questionRepositoryProvider);
    if (repo.cachedQuestions == null) return const SizedBox.shrink();

    // Use current session questions for breakdown
    final session = ref.read(quizSessionProvider);
    final questions = session.questions;
    final userAnswers = session.userAnswers;
    if (questions.isEmpty) return const SizedBox.shrink();

    final categories = questions.map((q) => q.category).toSet();
    final catStats = <String, Map<String, int>>{};
    String? weakestCategory;
    double worstRate = 1.0;

    for (final cat in categories) {
      final catQuestions = questions.where((q) => q.category == cat).toList();
      int answered = 0;
      int correct = 0;

      for (final q in catQuestions) {
        final index = questions.indexOf(q);
        if (userAnswers.containsKey(index)) {
          answered++;
          if (userAnswers[index] == q.correctIndex) {
            correct++;
          }
        }
      }

      if (answered > 0) {
        catStats[cat] = {'answered': answered, 'correct': correct};
        final rate = correct / answered;
        if (rate < worstRate) {
          worstRate = rate;
          weakestCategory = cat;
        }
      }
    }

    if (catStats.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'カテゴリ別内訳',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...catStats.entries.map((entry) {
              final cat = entry.key;
              final answered = entry.value['answered']!;
              final correct = entry.value['correct']!;
              final rate = correct / answered;
              final isWeakest = cat == weakestCategory && worstRate < 0.6;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (isWeakest)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.warning,
                                      size: 16, color: AppTheme.incorrect),
                                ),
                              Flexible(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isWeakest
                                        ? AppTheme.incorrect
                                        : AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(rate * 100).toStringAsFixed(0)}% ($correct/$answered)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: rate >= 0.6
                                ? AppTheme.correct
                                : AppTheme.incorrect,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 8,
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rate >= 0.6 ? AppTheme.correct : AppTheme.incorrect,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (weakestCategory != null && worstRate < 0.6) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.incorrect.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.incorrect.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb,
                        color: AppTheme.incorrect, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '弱点: $weakestCategory\nこのカテゴリを集中的に復習しましょう',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.incorrect,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedReview(BuildContext context) {
    final session = ref.read(quizSessionProvider);
    final questions = session.questions;
    final userAnswers = session.userAnswers;

    if (questions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '回答詳細',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final question = questions[index];
            final selectedIndex = userAnswers[index];
            final isCorrect = selectedIndex == question.correctIndex;
            final isSkipped = selectedIndex == null;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppTheme.correct
                            : (isSkipped ? Colors.grey : AppTheme.incorrect),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCorrect ? '正解' : (isSkipped ? '未回答' : '不正解'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Q${index + 1}. ${question.questionText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    question.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '【問題】',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(question.questionText, style: const TextStyle(fontSize: 15, height: 1.5)),
                        const SizedBox(height: 16),
                        const Text(
                          '【選択肢】',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(question.options.length, (optIndex) {
                          final isSelected = optIndex == selectedIndex;
                          final isAnswer = optIndex == question.correctIndex;
                          Color? textColor;
                          FontWeight? fontWeight;
                          
                          if (isAnswer) {
                            textColor = AppTheme.correct;
                            fontWeight = FontWeight.bold;
                          } else if (isSelected) {
                            textColor = AppTheme.incorrect;
                            fontWeight = FontWeight.bold;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isAnswer
                                      ? Icons.circle_outlined
                                      : (isSelected ? Icons.close : Icons.radio_button_unchecked),
                                  size: 16,
                                  color: isAnswer
                                      ? AppTheme.correct
                                      : (isSelected ? AppTheme.incorrect : Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    question.options[optIndex],
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: fontWeight,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Text('(あなたの回答)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '【解説】',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question.explanationSummary,
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                        if (question.mnemonic.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 覚え方', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(question.mnemonic, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final bgPaint = Paint()
      ..color = AppTheme.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
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
