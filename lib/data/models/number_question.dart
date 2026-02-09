/// 数字問題データモデル（Number Slotモード用）
class NumberQuestion {
  final String id;
  final String category;
  final String context;
  final String questionText; // {slot} をプレースホルダーとして使用
  final num correctValue;
  final List<num> options;
  final String unit;
  final String explanationShort;

  const NumberQuestion({
    required this.id,
    required this.category,
    required this.context,
    required this.questionText,
    required this.correctValue,
    required this.options,
    required this.unit,
    required this.explanationShort,
  });

  factory NumberQuestion.fromJson(Map<String, dynamic> json) {
    return NumberQuestion(
      id: json['id'] as String,
      category: json['category'] as String,
      context: json['context'] as String,
      questionText: json['question_text'] as String,
      correctValue: json['correct_value'] as num,
      options: List<num>.from(json['options'] as List),
      unit: json['unit'] as String,
      explanationShort: json['explanation_short'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'context': context,
      'question_text': questionText,
      'correct_value': correctValue,
      'options': options,
      'unit': unit,
      'explanation_short': explanationShort,
    };
  }

  /// 問題文の {slot} を指定値に置き換える
  String getFilledText(int value) {
    return questionText.replaceAll('{slot}', '$value');
  }

  /// 問題文の {slot} を空欄表示に置き換える
  String getBlankText() {
    return questionText.replaceAll('{slot}', '___');
  }
}
