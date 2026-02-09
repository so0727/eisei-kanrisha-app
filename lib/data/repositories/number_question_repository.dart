import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/number_question.dart';

/// 数字問題データの読み込みを担当するリポジトリ
class NumberQuestionRepository {
  List<NumberQuestion>? _cachedQuestions;

  /// JSONファイルから問題データを読み込む
  /// JSONファイルから問題データを読み込む
  Future<List<NumberQuestion>> loadQuestions() async {
    if (_cachedQuestions != null) {
      print('Using cached number questions.');
      return _cachedQuestions!;
    }

    try {
      print('Loading number_questions.json from assets...');
      final jsonString =
          await rootBundle.loadString('assets/data/number_questions.json');
      print('Loaded JSON string length: ${jsonString.length}');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      _cachedQuestions = jsonList
          .map((json) => NumberQuestion.fromJson(json as Map<String, dynamic>))
          .toList();
      print('Parsed ${_cachedQuestions!.length} number questions.');

      return _cachedQuestions!;
    } catch (e, stack) {
      print('Error loading/parsing number questions: $e\n$stack');
      return []; // Return empty list on error
    }
  }

  /// ランダム順で全問題を取得
  Future<List<NumberQuestion>> loadShuffledQuestions() async {
    final questions = await loadQuestions();
    final shuffled = List<NumberQuestion>.from(questions)..shuffle();
    return shuffled;
  }

  /// カテゴリでフィルタして取得
  Future<List<NumberQuestion>> loadByCategory(String category) async {
    final questions = await loadQuestions();
    return questions.where((q) => q.category == category).toList()..shuffle();
  }

  /// 問題数を取得
  Future<int> getQuestionCount() async {
    final questions = await loadQuestions();
    return questions.length;
  }

  /// 全カテゴリ名を取得
  Future<List<String>> getCategories() async {
    final questions = await loadQuestions();
    final categories = questions.map((q) => q.category).toSet().toList()
      ..sort();
    return categories;
  }

  /// キャッシュをクリア
  void clearCache() {
    _cachedQuestions = null;
  }
}
