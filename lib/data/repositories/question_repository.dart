import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/question.dart';
import '../../providers/user_subscription_provider.dart';

/// 問題データの読み込みを担当するリポジトリ
class QuestionRepository {
  static List<Question>? _cachedQuestions;

  List<Question>? get cachedQuestions => _cachedQuestions;

  /// 旧形式カテゴリ（関係法令・労働衛生）を5カテゴリ形式に正規化
  static String _normalizeCategory(String category) {
    if (category == '関係法令') return '関係法令（有害業務以外）';
    if (category == '労働衛生') return '労働衛生（有害業務以外）';
    return category;
  }

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
  /// 旧形式「関係法令」「労働衛生」は5カテゴリにマッピングして取得
  Future<List<Question>> loadByCategory(String category, {int? limit, bool shuffle = true}) async {
    final questions = await loadQuestions();
    final filtered = questions.where((q) {
      final norm = _normalizeCategory(q.category ?? '');
      return norm == category || q.category == category;
    }).toList();
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

  /// 全カテゴリ名を取得（試験の出題順でソート）
  /// 旧形式「関係法令」「労働衛生」は5カテゴリに集約して重複を解消
  Future<List<String>> getCategories() async {
    const order = [
      '関係法令（有害業務）',
      '労働衛生（有害業務）',
      '関係法令（有害業務以外）',
      '労働衛生（有害業務以外）',
      '労働生理',
    ];
    final questions = await loadQuestions();
    final normalized = questions.map((q) => _normalizeCategory(q.category ?? '')).toSet();
    return order.where((c) => normalized.contains(c)).toList();
  }

  /// 全年度を取得（新しい順でソート: 2025年10月→2025年4月→2024年10月→...）
  Future<List<String>> getYears() async {
    final questions = await loadQuestions();
    final years = questions.map((q) => q.year).toSet().toList();
    years.sort((a, b) {
      final pa = a.split('_');
      final pb = b.split('_');
      if (pa.length != 2 || pb.length != 2) return b.compareTo(a);
      final ya = int.tryParse(pa[0]) ?? 0;
      final yb = int.tryParse(pb[0]) ?? 0;
      if (ya != yb) return yb.compareTo(ya);
      final na = int.tryParse(pa[1]) ?? 0;
      final nb = int.tryParse(pb[1]) ?? 0;
      final ma = (na == 1 || na == 4) ? 4 : (na == 2 || na == 10 ? 10 : na);
      final mb = (nb == 1 || nb == 4) ? 4 : (nb == 2 || nb == 10 ? 10 : nb);
      return mb.compareTo(ma);
    });
    return years;
  }

  /// カテゴリ別の問題数を取得
  /// 旧形式「関係法令」「労働衛生」は5カテゴリに集約してカウント
  Future<Map<String, int>> getCategoryCounts() async {
    final questions = await loadQuestions();
    final Map<String, int> counts = {};
    for (final q in questions) {
      final cat = _normalizeCategory(q.category ?? '');
      counts[cat] = (counts[cat] ?? 0) + 1;
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
      final cat = _normalizeCategory(q.category ?? '');
      counts[cat] = (counts[cat] ?? 0) + 1;
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
