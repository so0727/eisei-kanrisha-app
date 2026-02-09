import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/question.dart';
import '../../providers/user_subscription_provider.dart';

/// 問題データの読み込みを担当するリポジトリ
class QuestionRepository {
  static List<Question>? _cachedQuestions;

  List<Question>? get cachedQuestions => _cachedQuestions;

  /// JSONファイルから問題データを読み込む
  Future<List<Question>> loadQuestions() async {
    if (_cachedQuestions != null) {
      return _cachedQuestions!;
    }

    final jsonString = await rootBundle.loadString('assets/json/questions.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    _cachedQuestions = jsonList
        .map((json) => Question.fromJson(json as Map<String, dynamic>))
        .toList();

    return _cachedQuestions!;
  }

  /// ランダム順で全問題を取得
  Future<List<Question>> loadShuffledQuestions() async {
    final questions = await loadQuestions();
    final shuffled = List<Question>.from(questions)..shuffle();
    return shuffled;
  }

  /// カテゴリでフィルタして取得
  /// [shuffle] がfalseの場合、固定順（ID順）で返す
  Future<List<Question>> loadByCategory(String category, {int? limit, bool shuffle = true}) async {
    final questions = await loadQuestions();
    final filtered = questions.where((q) => q.category == category).toList();
    if (shuffle) {
      filtered.shuffle();
    }
    if (limit != null && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  /// 年度でフィルタして取得
  Future<List<Question>> loadByYear(String year) async {
    final questions = await loadQuestions();
    return questions.where((q) => q.year == year).toList();
  }

  /// 指定IDの問題のみ取得（間違えた問題の復習用）
  Future<List<Question>> loadByIds(Set<int> ids) async {
    final questions = await loadQuestions();
    return questions.where((q) => ids.contains(q.id)).toList()..shuffle();
  }

  /// 全カテゴリ名を取得（ソート済み）
  Future<List<String>> getCategories() async {
    final questions = await loadQuestions();
    final categories = questions.map((q) => q.category).toSet().toList()
      ..sort();
    return categories;
  }

  /// 全年度を取得（降順ソート）
  Future<List<String>> getYears() async {
    final questions = await loadQuestions();
    final years = questions.map((q) => q.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  /// カテゴリ別の問題数を取得
  Future<Map<String, int>> getCategoryCounts() async {
    final questions = await loadQuestions();
    final Map<String, int> counts = {};
    for (final q in questions) {
      counts[q.category] = (counts[q.category] ?? 0) + 1;
    }
    return counts;
  }

  /// カテゴリ別の問題数を取得（Freeプラン: 2022-2023年のみ）
  Future<Map<String, int>> getFreeCategoryCounts() async {
    final questions = await loadQuestions();
    final freeQuestions = questions.where((q) => 
        q.year?.startsWith('2022') == true || 
        q.year?.startsWith('2023') == true);
    final Map<String, int> counts = {};
    for (final q in freeQuestions) {
      counts[q.category] = (counts[q.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 年度別の問題数を取得
  Future<Map<String, int>> getYearCounts() async {
    final questions = await loadQuestions();
    final Map<String, int> counts = {};
    for (final q in questions) {
      counts[q.year] = (counts[q.year] ?? 0) + 1;
    }
    return counts;
  }

  /// 課金状態に応じて問題を取得
  /// Free: isPremium=false のみ
  /// Pro: 全て
  Future<List<Question>> fetchQuestions(UserSubscriptionStatus status) async {
    final allQuestions = await loadQuestions();
    if (status == UserSubscriptionStatus.pro) {
      return allQuestions;
    }
    // FreeユーザーはPremium問題を除外
    return allQuestions.where((q) => !q.isPremium).toList();
  }

  /// キャッシュをクリア
  void clearCache() {
    _cachedQuestions = null;
  }
}
