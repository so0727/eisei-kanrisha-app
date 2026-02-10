import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../app/theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../../utils/ad_helper.dart';
import '../common/premium_upgrade_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// クイズ画面
/// - 上部: 円形ゲージ進捗
/// - 中央: 問題文カード（22sp, 行間1.6）
/// - 下部: 選択肢ボタン（60dp+ タッチターゲット, Gap 16+）
/// - mikan式: 正解→即自動進行 / 不正解→解説表示
class QuizScreen extends ConsumerStatefulWidget {
  final bool fromContinue;
  final QuizConfig? config;

  const QuizScreen({
    super.key,
    this.fromContinue = false,
    this.config,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  // 正解フラッシュ
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  // 不正解シェイク
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _autoAdvancing = false;
  InterstitialAd? _interstitialAd;

  // Mock Exam Timer
  Timer? _examTimer;
  int _elapsedSeconds = 0;
  static const int _examTimeLimit = 180 * 60; // 3 hours

  @override
  void initState() {
    super.initState();
    // ... (animations) ...
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _flashAnimation = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.fromContinue) {
        ref.read(quizSessionProvider.notifier).resumeSession();
      } else if (widget.config != null) {
        ref.read(quizSessionProvider.notifier).startSession(widget.config!);
      } else {
        ref.read(quizSessionProvider.notifier).startNewSession();
      }
      _loadInterstitialAd();
      
      // Start timer if in Mock Exam mode
      if (widget.config?.mode == QuizMode.year) {
        _startExamTimer();
      }
    });
  }

  void _startExamTimer() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
      // Optional: Auto-submit when time up? For now just track time.
    });
  }

  void _loadInterstitialAd() {
    final subscription = ref.read(userSubscriptionProvider);
    if (kIsWeb || subscription == UserSubscriptionStatus.pro) return;

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _flashController.dispose();
    _shakeController.dispose();
    _interstitialAd?.dispose();
    _examTimer?.cancel();
    super.dispose();
  }

  /// 選択肢タップ
  void _onAnswerSelected(int index) {
    HapticFeedback.lightImpact();

    ref.read(quizSessionProvider.notifier).selectAnswer(index);
    
    final session = ref.read(quizSessionProvider);
    final isExamMode = session.config.mode == QuizMode.year;

    // Mock Exam Mode: No immediate feedback, just move to next or wait for manual advance
    if (isExamMode) {
      // In exam mode, selecting an answer just marks it. 
      // We might want to auto-advance or let user click 'Next'.
      // For now, let's keep it manual or auto-advance slightly faster without feedback.
      // Actually, standard CBT usually requires 'Next' click, but here we can just auto-advance for speed.
      // Let's simple auto-advance for now to keep flow smooth.
      _autoAdvancing = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _autoAdvancing) {
          _autoAdvancing = false;
          ref.read(quizSessionProvider.notifier).nextQuestion();
        }
      });
      return;
    }

    _feedbackController.forward(from: 0);

    final showExplanationAlways =
        ref.read(appSettingsProvider).showExplanationAlways;

    if (session.isCorrect) {
      _flashController.forward(from: 0);
      HapticFeedback.mediumImpact();
      // 設定で「正解時も解説を表示」なら自動進行しない
      if (!showExplanationAlways) {
        _autoAdvancing = true;
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && _autoAdvancing) {
            _autoAdvancing = false;
            ref.read(quizSessionProvider.notifier).nextQuestion();
          }
        });
      }
    } else {
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(quizSessionProvider);
    final progress = ref.watch(progressProvider);
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final isExamMode = session.config.mode == QuizMode.year;
    final showExplanation = !isExamMode &&
        session.showResult &&
        (!session.isCorrect || settings.showExplanationAlways);
    ref.listen<QuizSessionState>(quizSessionProvider, (prev, next) {
      if (next.showPremiumDialog && !(prev?.showPremiumDialog ?? false)) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PremiumUpgradeDialog(),
        ).then((_) {
          // ダイアログが閉じられたら結果画面へ (課金してもその場では結果画面へ遷移させるのが無難)
          context.goNamed('result', extra: {
            'correctCount': next.correctCount,
            'totalCount': next.questions.length,
          });
        });
      } else if (next.isFinished && !(prev?.isFinished ?? false)) {
        if (_interstitialAd != null) {
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              context.goNamed('result', extra: {
                'correctCount': next.correctCount,
                'totalCount': next.questions.length,
              });
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              context.goNamed('result', extra: {
                'correctCount': next.correctCount,
                'totalCount': next.questions.length,
              });
            },
          );
          _interstitialAd!.show();
          _interstitialAd = null; // Shown once
        } else {
          context.goNamed('result', extra: {
            'correctCount': next.correctCount,
            'totalCount': next.questions.length,
          });
        }
      }
    });

    if (session.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text('問題を読み込み中...',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textBody)),
            ],
          ),
        ),
      );
    }

    final question = session.currentQuestion;
    if (question == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline,
                  size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              Text('問題がありません', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.goNamed('home'),
                child: const Text('ホームへ戻る'),
              ),
            ],
          ),
        ),
      );
    }

    final isBookmarked = progress.bookmarkedIds.contains(question.id);
    final quizProgress =
        (session.currentIndex + 1) / session.questions.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 30),
          padding: const EdgeInsets.all(12),
          onPressed: () => _showExitDialog(context),
        ),
        title: null,
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 28,
              color: isBookmarked ? AppTheme.accent : AppTheme.textSecondary,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(progressProvider.notifier).toggleBookmark(question.id);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: session.config.mode == QuizMode.year
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.textPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.textSecondary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, size: 16, color: AppTheme.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: question.isHazardous
                            ? AppTheme.incorrect.withValues(alpha: 0.2)
                            : AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        question.isHazardous ? '有害' : '一般',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: question.isHazardous
                              ? AppTheme.incorrect
                              : AppTheme.primary,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // メインコンテンツ (シェイク対応)
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final shake = math.sin(_shakeAnimation.value * math.pi * 4) * 10;
              return Transform.translate(
                offset: Offset(shake, 0),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  // ===== 上部: 円形ゲージ + 問題番号 =====
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // 円形ゲージ
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: CustomPaint(
                            painter: _CircularGaugePainter(
                              progress: quizProgress,
                            ),
                            child: Center(
                              child: Text(
                                '${session.currentIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // 問題番号テキスト
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${session.currentIndex + 1} / ${session.questions.length}問',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                question.category,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.primary.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 正解/不正解表示 (解答後) - 模擬試験モードでは非表示
                        if (session.showResult && session.config.mode != QuizMode.year)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: session.isCorrect
                                  ? AppTheme.correct.withValues(alpha: 0.2)
                                  : AppTheme.incorrect.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              session.isCorrect ? '正解！' : '不正解',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: session.isCorrect
                                    ? AppTheme.correct
                                    : AppTheme.incorrect,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 太めの進捗バー
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: quizProgress,
                        minHeight: 6,
                        backgroundColor: AppTheme.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
                      ),
                    ),
                  ),

                  // ===== 中央〜下部: 問題文 + 選択肢 =====
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        showExplanation ? 100 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 問題文カード
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.divider, width: 1),
                            ),
                            child: Text(
                              question.questionText,
                              style: theme.textTheme.titleLarge?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 選択肢ボタン（gap 16+, 各60dp以上）
                          ...List.generate(
                            question.options.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildOptionButton(
                                context,
                                index: index,
                                text: question.options[index],
                                session: session,
                              ),
                            ),
                          ),

                          // 解説カード（不正解時、または「正解時も解説表示」ON時）
                          if (showExplanation) ...[
                            const SizedBox(height: 8),
                            _buildExplanationCard(context, session),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 正解フラッシュオーバーレイ
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, _) {
              if (_flashAnimation.value == 0 || !_flashController.isAnimating) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: AppTheme.primary.withValues(
                        alpha: (1 - _flashAnimation.value) * 0.18),
                  ),
                ),
              );
            },
          ),
          // 「次の問題へ」下部固定ボタン（解説表示時）
          if (showExplanation)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(quizSessionProvider.notifier).nextQuestion();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    elevation: 10,
                    shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '次の問題へ',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 26),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 選択肢ボタン（タッチターゲット 60dp+）
  Widget _buildOptionButton(
    BuildContext context, {
    required int index,
    required String text,
    required QuizSessionState session,
  }) {
    final isSelected = session.selectedIndex == index;
    final isCorrectOption = session.currentQuestion?.correctIndex == index;
    final showResult = session.showResult;

    Color borderColor = AppTheme.divider;
    Color bgColor = AppTheme.cardColor;
    IconData? trailingIcon;

    final isExamMode = session.config.mode == QuizMode.year;

    if (showResult && !isExamMode) {
      if (isCorrectOption) {
        borderColor = AppTheme.correct;
        bgColor = AppTheme.correct.withValues(alpha: 0.12);
        trailingIcon = Icons.check_circle;
      } else if (isSelected && !isCorrectOption) {
        borderColor = AppTheme.incorrect;
        bgColor = AppTheme.incorrect.withValues(alpha: 0.12);
        trailingIcon = Icons.cancel;
      }
    } else if (isExamMode && isSelected) {
       // Mock Exam: Just show selected state (e.g., primary color border)
       borderColor = AppTheme.primary;
       bgColor = AppTheme.primary.withValues(alpha: 0.1);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showResult ? null : () => _onAnswerSelected(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minHeight: 64), // 60dp+
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              // 番号バッジ
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (showResult && !isExamMode && isCorrectOption)
                      ? AppTheme.correct
                      : (showResult && !isExamMode && isSelected)
                          ? AppTheme.incorrect
                          : (isSelected || (isExamMode && isSelected)) 
                              ? AppTheme.primary.withValues(alpha: 0.25)
                              : AppTheme.primary.withValues(alpha: 0.1), // Default
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: (showResult && !isExamMode && (isCorrectOption || isSelected))
                          ? Colors.black
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 選択肢テキスト（18sp本文サイズ）
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // 結果アイコン
              if (trailingIcon != null)
                ScaleTransition(
                  scale: _feedbackAnimation,
                  child: Icon(
                    trailingIcon,
                    size: 28,
                    color: isCorrectOption
                        ? AppTheme.correct
                        : AppTheme.incorrect,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 解説カード（不正解時のみ表示）
  Widget _buildExplanationCard(
      BuildContext context, QuizSessionState session) {
    final question = session.currentQuestion!;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: AppTheme.accent, size: 24),
                const SizedBox(width: 8),
                Text(
                  '解説',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.accent,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://docs.google.com/forms/d/e/1FAIpQLScP_dummy/viewform?entry.123456=${question.id}',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.report_problem, size: 16, color: AppTheme.textSecondary),
                  label: const Text('誤植を報告', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.explanationSummary,
              style: const TextStyle(
                fontSize: 18,
                height: 1.6,
                color: AppTheme.textBody,
              ),
            ),
            const Divider(height: 28),
            // 語呂合わせ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tips_and_updates,
                          color: AppTheme.accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '覚え方',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.mnemonic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('クイズを終了しますか？',
            style: TextStyle(fontSize: 20, color: AppTheme.textPrimary)),
        content: const Text(
          '途中経過は保存されます。\n「続きから」で再開できます。',
          style: TextStyle(fontSize: 18, height: 1.6, color: AppTheme.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル',
                style: TextStyle(fontSize: 18, color: AppTheme.textBody)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      context.goNamed('home');
    }
  }
}

/// 円形ゲージ描画（タコメーター風）
class _CircularGaugePainter extends CustomPainter {
  final double progress;

  _CircularGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 背景リング
    final bgPaint = Paint()
      ..color = AppTheme.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, bgPaint);

    // 進捗アーク
    final progressPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
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
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
