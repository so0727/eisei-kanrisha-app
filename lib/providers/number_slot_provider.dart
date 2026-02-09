import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/number_question.dart';
import '../data/repositories/number_question_repository.dart';

// ---------------------
// リポジトリプロバイダー
// ---------------------
final numberQuestionRepositoryProvider =
    Provider<NumberQuestionRepository>((ref) {
  return NumberQuestionRepository();
});

// ---------------------
// Number Slot ゲーム状態
// ---------------------
class NumberSlotState {
  final List<NumberQuestion> questions;
  final int currentIndex;
  final num? selectedValue;
  final bool isAnswered;
  final bool isCorrect;
  final int correctCount;
  final bool isLoading;
  final bool isFinished;

  const NumberSlotState({
    this.questions = const [],
    this.currentIndex = 0,
    this.selectedValue,
    this.isAnswered = false,
    this.isCorrect = false,
    this.correctCount = 0,
    this.isLoading = true,
    this.isFinished = false,
  });

  NumberQuestion? get currentQuestion =>
      questions.isNotEmpty && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  int get totalCount => questions.length;
  int get remainingCount => questions.length - currentIndex;
  double get progressPercent =>
      questions.isEmpty ? 0 : (currentIndex + 1) / questions.length;

  NumberSlotState copyWith({
    List<NumberQuestion>? questions,
    int? currentIndex,
    num? selectedValue,
    bool? isAnswered,
    bool? isCorrect,
    int? correctCount,
    bool? isLoading,
    bool? isFinished,
    bool clearSelectedValue = false,
  }) {
    return NumberSlotState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedValue:
          clearSelectedValue ? null : (selectedValue ?? this.selectedValue),
      isAnswered: isAnswered ?? this.isAnswered,
      isCorrect: isCorrect ?? this.isCorrect,
      correctCount: correctCount ?? this.correctCount,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

// ---------------------
// Number Slot Notifier
// ---------------------
class NumberSlotNotifier extends StateNotifier<NumberSlotState> {
  final Ref ref;

  NumberSlotNotifier(this.ref) : super(const NumberSlotState());

  /// ゲーム開始（ランダム出題）
  Future<void> startGame({int? questionCount}) async {
    print('Starting Number Slot game...'); // Debug log
    try {
      state = state.copyWith(isLoading: true, isFinished: false);

      final repository = ref.read(numberQuestionRepositoryProvider);
      print('Loading questions from repository...'); // Debug log
      var questions = await repository.loadShuffledQuestions();
      print('Loaded ${questions.length} questions.'); // Debug log

      // 問題数を制限
      if (questionCount != null && questionCount < questions.length) {
        questions = questions.take(questionCount).toList();
      }

      if (questions.isEmpty) {
        print('Warning: No questions loaded.');
        state = state.copyWith(isLoading: false); // Stop loading even if empty
        return;
      }

      state = NumberSlotState(
        questions: questions,
        currentIndex: 0,
        selectedValue: questions.isNotEmpty ? questions[0].options.first : null,
        isAnswered: false,
        isCorrect: false,
        correctCount: 0,
        isLoading: false,
        isFinished: false,
      );
      print('Game started successfully with ${questions.length} questions.'); // Debug log
    } catch (e, stack) {
      print('Error starting Number Slot game: $e\n$stack'); // Error log
      state = state.copyWith(isLoading: false); // Stop loading on error
    }
  }

  /// スロットで値を選択
  void selectValue(num value) {
    if (state.isAnswered) return;
    state = state.copyWith(selectedValue: value);
  }

  /// 回答確定
  void submitAnswer() {
    if (state.isAnswered || state.selectedValue == null) return;

    final question = state.currentQuestion;
    if (question == null) return;

    final isCorrect = state.selectedValue == question.correctValue;
    state = state.copyWith(
      isAnswered: true,
      isCorrect: isCorrect,
      correctCount: isCorrect ? state.correctCount + 1 : state.correctCount,
    );
  }

  /// 次の問題へ
  void nextQuestion() {
    if (!state.isAnswered) return;

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.questions.length) {
      // ゲーム終了
      state = state.copyWith(isFinished: true);
      return;
    }

    final nextQuestion = state.questions[nextIndex];
    state = state.copyWith(
      currentIndex: nextIndex,
      selectedValue: nextQuestion.options.first,
      isAnswered: false,
      isCorrect: false,
    );
  }

  /// リセット
  void reset() {
    state = const NumberSlotState();
  }
}

// ---------------------
// プロバイダー
// ---------------------
final numberSlotProvider =
    StateNotifierProvider<NumberSlotNotifier, NumberSlotState>((ref) {
  return NumberSlotNotifier(ref);
});
