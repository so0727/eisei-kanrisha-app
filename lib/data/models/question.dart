/// 問題データモデル
class Question {
  final int id;
  final String year;
  final String category;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanationSummary;
  final String mnemonic;
  final bool isHazardous;
  final bool isPremium;

  const Question({
    required this.id,
    required this.year,
    required this.category,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanationSummary,
    required this.mnemonic,
    required this.isHazardous,
    required this.isPremium,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      year: json['year'] as String,
      category: json['category'] as String,
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List),
      correctIndex: json['correct_index'] as int,
      explanationSummary: json['explanation_summary'] as String,
      mnemonic: json['mnemonic'] as String,
      isHazardous: json['is_hazardous'] as bool,
      // デフォルトはfalse（JSONにない場合の互換性のため）
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'category': category,
      'question_text': questionText,
      'options': options,
      'correct_index': correctIndex,
      'explanation_summary': explanationSummary,
      'mnemonic': mnemonic,
      'is_hazardous': isHazardous,
      'is_premium': isPremium,
    };
  }
}
