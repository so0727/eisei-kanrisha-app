import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/number_slot_provider.dart';

/// 数字スロット暗記 ゲーム画面
class NumberSlotScreen extends ConsumerStatefulWidget {
  const NumberSlotScreen({super.key});

  @override
  ConsumerState<NumberSlotScreen> createState() => _NumberSlotScreenState();
}

class _NumberSlotScreenState extends ConsumerState<NumberSlotScreen>
    with TickerProviderStateMixin {
  late FixedExtentScrollController _wheelController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isSpinning = false;
  Timer? _spinSoundTimer;

  // 無限スクロール用の大きな数字（初期位置）
  static const int _infiniteScrollOffset = 10000;

  @override
  void initState() {
    super.initState();
    _wheelController = FixedExtentScrollController(initialItem: _infiniteScrollOffset);

    // 振動アニメーション
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // ゲーム開始
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(numberSlotProvider.notifier).startGame(questionCount: 10);
      } catch (e) {
        debugPrint('Error in NumberSlotScreen: $e');
      }
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _shakeController.dispose();
    _spinSoundTimer?.cancel();
    super.dispose();
  }

  void _onSubmit() {
    if (_isSpinning) return;
    
    final notifier = ref.read(numberSlotProvider.notifier);
    notifier.submitAnswer();

    // 不正解時は振動
    final state = ref.read(numberSlotProvider);
    if (!state.isCorrect) {
      _shakeController.forward().then((_) => _shakeController.reset());
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
      // 正解音（擬似）
      _playWinSound();
    }
  }

  void _onNext() {
    final state = ref.read(numberSlotProvider);
    if (state.isFinished) {
      // 結果画面へ
      context.pushReplacement('/result', extra: {
        'correctCount': state.correctCount,
        'totalCount': state.totalCount,
      });
    } else {
      ref.read(numberSlotProvider.notifier).nextQuestion();
      // ホイールをリセット（無限スクロールの中央へ）
      _wheelController.jumpToItem(_infiniteScrollOffset);
    }
  }

  // 自動スピン
  void _spin(int optionCount, {int? targetIndex}) {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    // 回転音（擬似）スタート
    _spinSoundTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      HapticFeedback.selectionClick();
    });

    final random = Random();
    // 3〜5回転 + ランダムインデックス
    // もし targetIndex が指定されていればそこで止まる（デバッグ用や、必ず正解させたい場合など）
    final nextIndexRaw = targetIndex ?? random.nextInt(optionCount);
    
    // 現在の位置から、最低でも3周分（optionCount * 3）は回す
    final currentItem = _wheelController.selectedItem;
    final targetItem = currentItem + (optionCount * 3) + 
        (nextIndexRaw - (currentItem % optionCount) + optionCount) % optionCount;

    _wheelController.animateToItem(
      targetItem,
      duration: const Duration(seconds: 2), // 2秒間回る
      curve: Curves.easeOutCubic, // だんだんゆっくりになる
    ).then((_) {
      _spinSoundTimer?.cancel();
      HapticFeedback.heavyImpact(); // 停止音
      
      setState(() {
        _isSpinning = false;
      });
      
      // 値を選択（Notifierに通知）
      // 無限スクロールのインデックスから、実際の選択肢インデックスに変換
      final actualIndex = targetItem % optionCount;
      final state = ref.read(numberSlotProvider);
      final question = state.currentQuestion;
      if (question != null) {
         ref.read(numberSlotProvider.notifier).selectValue(question.options[actualIndex]);
      }
    });
  }

  void _playWinSound() {
    // タタタタン！みたいなリズムで振動させる
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.mediumImpact());
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.mediumImpact());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(numberSlotProvider);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('データを読み込んでいます...'),
            ],
          ),
        ),
      );
    }

    final question = state.currentQuestion;
    if (question == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text('問題データを読み込めませんでした。'),
              const SizedBox(height: 8),
              const Text('再度お試しください。'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '問題 ${state.currentIndex + 1}/${state.totalCount}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${state.correctCount}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // プログレスバー
            LinearProgressIndicator(
              value: state.progressPercent,
              backgroundColor: AppTheme.cardColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // カテゴリ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        question.category,
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // コンテキスト
                    Text(
                      question.context,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 問題文
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            state.isAnswered && !state.isCorrect
                                ? _shakeAnimation.value *
                                    ((_shakeController.value * 10).toInt() % 2 ==
                                            0
                                        ? 1
                                        : -1)
                                : 0,
                            0,
                          ),
                          child: child,
                        );
                      },
                      child: _buildQuestionCard(question, state),
                    ),
                    const SizedBox(height: 32),

                    // スロットホイール
                    if (!state.isAnswered) _buildSlotWheel(question, state),

                    // 回答後の解説
                    if (state.isAnswered) _buildExplanation(question, state),
                  ],
                ),
              ),
            ),

            // ボタンエリア
            _buildBottomButton(state),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(question, NumberSlotState state) {
    // 問題文を {slot} で分割
    final parts = question.questionText.split('{slot}');
    final beforeSlot = parts.isNotEmpty ? parts[0] : '';
    final afterSlot = parts.length > 1 ? parts[1] : '';

    Color slotColor = AppTheme.primary;
    if (state.isAnswered) {
      slotColor = state.isCorrect ? AppTheme.correct : AppTheme.incorrect;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isAnswered
              ? (state.isCorrect ? AppTheme.correct : AppTheme.incorrect)
                  .withValues(alpha: 0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 22,
            height: 1.8,
            color: AppTheme.textPrimary,
          ),
          children: [
            TextSpan(text: beforeSlot),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: slotColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: slotColor, width: 2),
                ),
                child: Text(
                  state.isAnswered
                      ? '${question.correctValue}'
                      : (state.selectedValue != null
                          ? '${state.selectedValue}'
                          : '?'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: slotColor,
                  ),
                ),
              ),
            ),
            TextSpan(text: afterSlot),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotWheel(question, NumberSlotState state) {
    return Column(
      children: [
        // スロットホイール
        SizedBox(
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 矢印（上）
              Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 24),

              // ホイール（無限スクロール）
              SizedBox(
                width: 120,
                child: ListWheelScrollView.useDelegate(
                  controller: _wheelController,
                  itemExtent: 70, // 少し大きくした
                  perspective: 0.003,
                  diameterRatio: 1.2,
                  physics: _isSpinning
                      ? const NeverScrollableScrollPhysics() // スピン中は操作禁止
                      : const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    if (!_isSpinning) {
                       // 無限スクロールのインデックスを正規化して通知
                       final actualIndex = index % question.options.length;
                       ref
                          .read(numberSlotProvider.notifier)
                          .selectValue(question.options[actualIndex]);
                       HapticFeedback.selectionClick();
                    }
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      // 無限スクロールのためのインデックス正規化
                      final actualIndex = index % question.options.length;
                      final value = question.options[actualIndex];
                      
                      // 選択状態の判定（無限スクロールなので、正規化した値で比較）
                      final isSelected = state.selectedValue == value;
                      
                      // スピン中は全部薄くするなどの演出も可だが、今回はシンプルに
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected && !_isSpinning
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontSize: isSelected ? 36 : 28,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 8),

              // 単位
              Text(
                question.unit,
                style: const TextStyle(
                  fontSize: 24,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // AUTO SPIN ボタン
        Center(
          child: SizedBox(
            height: 50,
            width: 160,
            child: ElevatedButton.icon(
              onPressed: _isSpinning ? null : () => _spin(question.options.length),
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text(
                'Play Slot',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        const Text(
            '手動で回すこともできます',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildExplanation(question, NumberSlotState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (state.isCorrect ? AppTheme.correct : AppTheme.incorrect)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (state.isCorrect ? AppTheme.correct : AppTheme.incorrect)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.isCorrect ? Icons.check_circle : Icons.cancel,
                color: state.isCorrect ? AppTheme.correct : AppTheme.incorrect,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                state.isCorrect ? '正解！' : '不正解...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color:
                      state.isCorrect ? AppTheme.correct : AppTheme.incorrect,
                ),
              ),
            ],
          ),
          if (!state.isCorrect) ...[
            const SizedBox(height: 12),
            Text(
              '正解は ${question.correctValue}${question.unit}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  question.explanationShort,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: AppTheme.textBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(NumberSlotState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: state.isAnswered ? _onNext : _onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  state.isAnswered ? AppTheme.accent : AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              state.isAnswered
                  ? (state.isFinished ? '結果を見る' : '次へ →')
                  : '決定！',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
