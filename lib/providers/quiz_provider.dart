import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/question.dart';
import '../data/repositories/question_repository.dart';
import 'user_subscription_provider.dart';

// ---------------------
// クイズモード定義
// ---------------------
enum QuizMode {
  allRandom, // 全問ランダム
  category, // カテゴリ別
  year, // 年度別（模擬試験）
  wrongOnly, // 間違えた問題
  bookmarked, // ブックマーク
  continueSession, // 続きから
}

/// カテゴリ別フィルター
enum CategoryFilter {
  all, // 全問
  wrongOnly, // 間違えた問題のみ
  unansweredOnly, // 未回答のみ
}

/// クイズ設定
class QuizConfig {
  final QuizMode mode;
  final int? questionCount; // null = 全問
  final String? category; // カテゴリ別の場合
  final String? year; // 年度別の場合
  final List<int>? targetIds; // 特定の問題ID指定（間違えた問題復習など）
  final CategoryFilter categoryFilter; // カテゴリ別フィルター

  const QuizConfig({
    this.mode = QuizMode.allRandom,
    this.questionCount,
    this.category,
    this.year,
    this.targetIds,
    this.categoryFilter = CategoryFilter.all,
  });
}

// ---------------------
// リポジトリプロバイダー
// ---------------------
final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository();
});

// ---------------------
// 学習進捗プロバイダー
// ---------------------
final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});

class ProgressState {
  final Set<int> answeredIds;
  final Set<int> correctIds;
  final Set<int> bookmarkedIds;
  final int totalQuestions;
  final List<String> studyDates; // YYYY-MM-DD形式の学習日リスト
  /// 日別の回答数（YYYY-MM-DD -> その日の回答数）
  final Map<String, int> dailyAnswerCounts;

  const ProgressState({
    this.answeredIds = const {},
    this.correctIds = const {},
    this.bookmarkedIds = const {},
    this.totalQuestions = 0,
    this.studyDates = const [],
    this.dailyAnswerCounts = const {},
  });

  /// 今日の回答数
  int get todayAnsweredCount {
    final today = dateString(DateTime.now());
    return dailyAnswerCounts[today] ?? 0;
  }

  double get progressPercent =>
      totalQuestions > 0 ? answeredIds.length / totalQuestions : 0.0;

  /// 間違えた問題のID（回答済み - 正解）
  Set<int> get wrongIds => answeredIds.difference(correctIds);

  /// 連続学習日数（ストリーク）を算出
  int get streakDays {
    if (studyDates.isEmpty) return 0;

    final sorted = List<String>.from(studyDates)
      ..sort((a, b) => b.compareTo(a)); // 降順
    final today = dateString(DateTime.now());
    final yesterday = dateString(DateTime.now().subtract(const Duration(days: 1)));

    // 今日か昨日に学習してなければストリーク0
    if (sorted.first != today && sorted.first != yesterday) return 0;

    int streak = 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      final current = DateTime.parse(sorted[i]);
      final prev = DateTime.parse(sorted[i + 1]);
      final diff = current.difference(prev).inDays;
      if (diff == 1) {
        streak++;
      } else if (diff > 1) {
        break;
      }
      // diff == 0 は同日（無視して続行）
    }
    return streak;
  }

  /// 今日学習済みかどうか
  bool get studiedToday => studyDates.contains(dateString(DateTime.now()));

  /// 日付を YYYY-MM-DD 形式の文字列に変換
  static String dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  ProgressState copyWith({
    Set<int>? answeredIds,
    Set<int>? correctIds,
    Set<int>? bookmarkedIds,
    int? totalQuestions,
    List<String>? studyDates,
    Map<String, int>? dailyAnswerCounts,
  }) {
    return ProgressState(
      answeredIds: answeredIds ?? this.answeredIds,
      correctIds: correctIds ?? this.correctIds,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      studyDates: studyDates ?? this.studyDates,
      dailyAnswerCounts: dailyAnswerCounts ?? this.dailyAnswerCounts,
    );
  }
}

class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(const ProgressState());

  /// SharedPreferencesから進捗を読み込む
  Future<void> loadProgress(int totalQuestions) async {
    final prefs = await SharedPreferences.getInstance();
    final answeredJson = prefs.getString('answered_ids');
    final correctJson = prefs.getString('correct_ids');
    final bookmarkedJson = prefs.getString('bookmarked_ids');
    final datesJson = prefs.getString('study_dates');
    final dailyJson = prefs.getString('daily_answer_counts');

    Set<int> answered = {};
    Set<int> correct = {};
    Set<int> bookmarked = {};
    List<String> dates = [];
    Map<String, int> dailyCounts = {};

    if (answeredJson != null) {
      answered =
          (json.decode(answeredJson) as List).map((e) => e as int).toSet();
    }
    if (correctJson != null) {
      correct =
          (json.decode(correctJson) as List).map((e) => e as int).toSet();
    }
    if (bookmarkedJson != null) {
      bookmarked =
          (json.decode(bookmarkedJson) as List).map((e) => e as int).toSet();
    }
    if (datesJson != null) {
      dates = (json.decode(datesJson) as List)
          .map((e) => e as String)
          .toList();
    }
    if (dailyJson != null) {
      final decoded = json.decode(dailyJson) as Map<String, dynamic>;
      for (final e in decoded.entries) {
        dailyCounts[e.key] = e.value as int;
      }
    }

    state = ProgressState(
      answeredIds: answered,
      correctIds: correct,
      bookmarkedIds: bookmarked,
      totalQuestions: totalQuestions,
      studyDates: dates,
      dailyAnswerCounts: dailyCounts,
    );
  }

  /// 回答結果を記録
  Future<void> recordAnswer(int questionId, bool isCorrect) async {
    // 回答済みに追加
    final newAnswered = Set<int>.from(state.answeredIds);
    newAnswered.add(questionId);
    
    // 正解/不正解を更新
    final newCorrect = Set<int>.from(state.correctIds);
    if (isCorrect) {
      newCorrect.add(questionId);
    } else {
      newCorrect.remove(questionId);
    }



    // 今日の学習日を記録
    final today = ProgressState.dateString(DateTime.now());
    final newDates = List<String>.from(state.studyDates);
    if (!newDates.contains(today)) {
      newDates.add(today);
    }

    // 日別回答数を更新
    final newDaily = Map<String, int>.from(state.dailyAnswerCounts);
    newDaily[today] = (newDaily[today] ?? 0) + 1;

    state = state.copyWith(
      answeredIds: newAnswered,
      correctIds: newCorrect,
      studyDates: newDates,
      dailyAnswerCounts: newDaily,
    );



    // SharedPreferencesに保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'answered_ids', json.encode(newAnswered.toList()));
    await prefs.setString(
        'correct_ids', json.encode(newCorrect.toList()));
    await prefs.setString(
        'study_dates', json.encode(newDates));
    await prefs.setString(
        'daily_answer_counts', json.encode(newDaily));
    

  }

  /// ブックマーク切り替え
  Future<void> toggleBookmark(int questionId) async {
    final newBookmarked = {...state.bookmarkedIds};
    if (newBookmarked.contains(questionId)) {
      newBookmarked.remove(questionId);
    } else {
      newBookmarked.add(questionId);
    }

    state = state.copyWith(bookmarkedIds: newBookmarked);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'bookmarked_ids', json.encode(newBookmarked.toList()));
  }

  /// 進捗をリセット
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('answered_ids');
    await prefs.remove('correct_ids');
    state = ProgressState(
      totalQuestions: state.totalQuestions,
      bookmarkedIds: state.bookmarkedIds,
      dailyAnswerCounts: state.dailyAnswerCounts,
    );
  }

  /// 全データリセット（ブックマーク含む）
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('answered_ids');
    await prefs.remove('correct_ids');
    await prefs.remove('bookmarked_ids');
    state = ProgressState(
      totalQuestions: state.totalQuestions,
      dailyAnswerCounts: state.dailyAnswerCounts,
    );
  }
}

// ---------------------
// クイズセッションプロバイダー
// ---------------------
final quizSessionProvider =
    StateNotifierProvider<QuizSessionNotifier, QuizSessionState>((ref) {
  return QuizSessionNotifier(ref);
});

class QuizSessionState {
  final List<Question> questions;
  final int currentIndex;
  final int? selectedIndex;
  final bool showResult;
  final int correctCount;
  final bool isLoading;
  final bool isFinished;
  final int? lastSavedIndex;
  final QuizConfig config;
  final bool isPremiumLimited;
  final bool showPremiumDialog;
  // Index -> Selected Option Index
  final Map<int, int> userAnswers;

  const QuizSessionState({
    this.questions = const [],
    this.currentIndex = 0,
    this.selectedIndex,
    this.showResult = false,
    this.correctCount = 0,
    this.isLoading = true,
    this.isFinished = false,
    this.lastSavedIndex,
    this.config = const QuizConfig(),
    this.isPremiumLimited = false,
    this.showPremiumDialog = false,
    this.userAnswers = const {},
  });

  Question? get currentQuestion =>
      questions.isNotEmpty && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  bool get isCorrect =>
      selectedIndex != null &&
      currentQuestion != null &&
      selectedIndex == currentQuestion!.correctIndex;

  QuizSessionState copyWith({
    List<Question>? questions,
    int? currentIndex,
    int? selectedIndex,
    bool? showResult,
    int? correctCount,
    bool? isLoading,
    bool? isFinished,
    int? lastSavedIndex,
    QuizConfig? config,
    bool clearSelectedIndex = false,
    bool? isPremiumLimited,
    bool? showPremiumDialog,
    Map<int, int>? userAnswers,
  }) {
    return QuizSessionState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedIndex:
          clearSelectedIndex ? null : (selectedIndex ?? this.selectedIndex),
      showResult: showResult ?? this.showResult,
      correctCount: correctCount ?? this.correctCount,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      lastSavedIndex: lastSavedIndex ?? this.lastSavedIndex,
      config: config ?? this.config,
      isPremiumLimited: isPremiumLimited ?? this.isPremiumLimited,
      showPremiumDialog: showPremiumDialog ?? this.showPremiumDialog,
      userAnswers: userAnswers ?? this.userAnswers,
    );
  }
}

class QuizSessionNotifier extends StateNotifier<QuizSessionState> {
  final Ref _ref;

  QuizSessionNotifier(this._ref) : super(const QuizSessionState());

  /// 設定に基づいてクイズセッションを開始
  Future<void> startSession(QuizConfig config) async {
    state = const QuizSessionState(isLoading: true);
    final repo = _ref.read(questionRepositoryProvider);
    final subscription = _ref.read(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;

    List<Question> questions;

    switch (config.mode) {
      case QuizMode.allRandom:
        questions = await repo.loadShuffledQuestions();
        break;
      case QuizMode.category:
        // まずカテゴリの全問題を取得（シャッフルはProのみ）
        var categoryQuestions = await repo.loadByCategory(
          config.category!,
          shuffle: !isFree,
        );
        
        // Freeユーザーは2022年・2023年の問題のみ
        if (isFree) {
          categoryQuestions = categoryQuestions
              .where((q) => q.year?.startsWith('2022') == true || 
                           q.year?.startsWith('2023') == true)
              .toList();
        }
        
        // フィルター適用（全ユーザー）
        final progress = _ref.read(progressProvider);
        switch (config.categoryFilter) {
          case CategoryFilter.wrongOnly:
            final wrongIds = progress.wrongIds;
            categoryQuestions = categoryQuestions
                .where((q) => wrongIds.contains(q.id))
                .toList();
            break;
          case CategoryFilter.unansweredOnly:
            final answeredIds = progress.answeredIds;
            categoryQuestions = categoryQuestions
                .where((q) => !answeredIds.contains(q.id))
                .toList();
            break;
          case CategoryFilter.all:
            // フィルターなし
            break;
        }
        
        // 問題数制限（Proのみ）
        final limit = isFree ? null : config.questionCount;
        if (limit != null && categoryQuestions.length > limit) {
          categoryQuestions = categoryQuestions.sublist(0, limit);
        }
        
        questions = categoryQuestions;
        break;

      case QuizMode.year:
        questions = await repo.loadByYear(config.year!);
        break;
      case QuizMode.wrongOnly:
        // targetIdsが指定されていればそれ優先（今回の結果から復習など）
        // 指定なければ全履歴から（トップ画面からの復習など）
        if (config.targetIds != null && config.targetIds!.isNotEmpty) {
          questions = await repo.loadByIds(config.targetIds!.toSet());
        } else {
          final wrongIds = _ref.read(progressProvider).wrongIds;
          questions = await repo.loadByIds(wrongIds);
        }
        break;
      case QuizMode.bookmarked:
        final bookmarkedIds = _ref.read(progressProvider).bookmarkedIds;
        questions = await repo.loadByIds(bookmarkedIds);
        break;
      case QuizMode.continueSession:
        // continueSessionは resumeSession() で処理
        questions = await repo.loadQuestions();
        break;
    }

    // 出題数制限 (設定が優先だが、上記カテゴリ制限で既に減っている場合もある)
    if (config.questionCount != null &&
        config.questionCount! < questions.length) {
      questions = questions.sublist(0, config.questionCount!);
    }

    // 総問題数を進捗に反映（全体の問題数）
    final allQuestions = await repo.loadQuestions();
    await _ref
        .read(progressProvider.notifier)
        .loadProgress(allQuestions.length);

    state = QuizSessionState(
      questions: questions,
      currentIndex: 0,
      isLoading: false,
      config: config,
      isPremiumLimited: config.mode == QuizMode.category && isFree,
    );

    await _saveCurrentIndex(0);
  }

  /// 新しいクイズセッション開始（ランダム） - 後方互換
  Future<void> startNewSession() async {
    await startSession(const QuizConfig(mode: QuizMode.allRandom));
  }

  /// 続きから再開
  Future<void> resumeSession() async {
    state = const QuizSessionState(isLoading: true);
    final repo = _ref.read(questionRepositoryProvider);
    final questions = await repo.loadQuestions();

    await _ref.read(progressProvider.notifier).loadProgress(questions.length);

    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('last_question_index') ?? 0;
    final clampedIndex = savedIndex.clamp(0, questions.length - 1);

    state = QuizSessionState(
      questions: questions,
      currentIndex: clampedIndex,
      isLoading: false,
      lastSavedIndex: clampedIndex,
      config: const QuizConfig(mode: QuizMode.continueSession),
    );
  }

  /// 選択肢をタップ
  void selectAnswer(int optionIndex) {
    if (state.showResult) return; // 結果表示中は操作不可

    final correctIdx = state.currentQuestion?.correctIndex;
    final isCorrect = optionIndex == correctIdx;

    final newAnswers = Map<int, int>.from(state.userAnswers);
    newAnswers[state.currentIndex] = optionIndex;

    state = state.copyWith(
      selectedIndex: optionIndex,
      showResult: true,
      correctCount:
          isCorrect ? state.correctCount + 1 : state.correctCount,
      userAnswers: newAnswers,
    );

    // 進捗を記録
    if (state.currentQuestion != null) {
      _ref
          .read(progressProvider.notifier)
          .recordAnswer(state.currentQuestion!.id, isCorrect);
    }
  }

  /// 次の問題へ
  Future<void> nextQuestion() async {
    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.questions.length) {
      if (state.isPremiumLimited) {
        // 制限により終了する場合、ダイアログを表示
        state = state.copyWith(showPremiumDialog: true);
      } else {
        state = state.copyWith(isFinished: true);
      }
      return;
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      showResult: false,
      clearSelectedIndex: true,
    );

    await _saveCurrentIndex(nextIndex);
  }

  /// 現在のインデックスを保存
  Future<void> _saveCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_question_index', index);
  }
}
