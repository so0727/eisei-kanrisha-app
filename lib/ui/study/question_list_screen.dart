import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../data/models/question.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../common/bookmark_button.dart';
import '../common/premium_upgrade_dialog.dart';
import '../home/quiz_settings_sheet.dart';

/// カテゴリ別問題一覧画面
class QuestionListScreen extends ConsumerStatefulWidget {
  final String category;
  
  const QuestionListScreen({super.key, required this.category});

  @override
  ConsumerState<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends ConsumerState<QuestionListScreen> {
  List<Question> _questions = [];
  bool _isLoaded = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final repo = ref.read(questionRepositoryProvider);
    final questions = await repo.loadByCategory(widget.category, shuffle: false);
    // 年度順にソート（新しい順）
    questions.sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoaded = true;
      });
    }
  }

  /// 検索フィルター適用後のリスト
  List<Question> get _filteredQuestions {
    if (_searchQuery.isEmpty) return _questions;
    final query = _searchQuery.toLowerCase();
    return _questions.where((q) {
      final text = q.questionText?.toLowerCase() ?? '';
      final options = q.options?.join(' ').toLowerCase() ?? '';
      return text.contains(query) || options.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final filteredQuestions = _filteredQuestions;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.category,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        actions: [
          // クイズ開始ボタン
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showQuizSettings();
            },
            icon: const Icon(Icons.play_arrow, color: AppTheme.primary, size: 20),
            label: const Text('クイズ', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: !_isLoaded
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // 検索バー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.cardColor,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'このカテゴリ内を検索...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                // 問題数サマリー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: AppTheme.cardColor,
                  child: Row(
                    children: [
                      Text(
                        _searchQuery.isEmpty
                            ? '全${_questions.length}問'
                            : '${filteredQuestions.length}件 / ${_questions.length}問',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isFree)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '2022-2023年のみ',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.divider),
                // 問題リスト
                Expanded(
                  child: filteredQuestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text(
                                '「$_searchQuery」に一致する問題がありません',
                                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredQuestions.length,
                          itemBuilder: (context, index) {
                            final question = filteredQuestions[index];
                            // 元リスト内でのインデックスを取得
                            final originalIndex = _questions.indexOf(question) + 1;
                            return _buildQuestionTile(
                              context,
                              question,
                              originalIndex,
                              isFree,
                              progress,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }


  Widget _buildQuestionTile(
    BuildContext context,
    Question question,
    int number,
    bool isFree,
    ProgressState progress,
  ) {
    // Freeユーザーは2022-2023年のみ
    final isLocked = isFree &&
        question.year != null &&
        !question.year!.startsWith('2022') &&
        !question.year!.startsWith('2023');

    // 回答済み・正解判定
    final isAnswered = progress.answeredIds.contains(question.id);
    final isCorrect = progress.correctIds.contains(question.id);
    final isWrong = isAnswered && !isCorrect;

    final questionText = question.questionText ?? '';
    final truncatedText = questionText.length > 60
        ? '${questionText.substring(0, 60)}...'
        : questionText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isLocked) {
              showDialog(
                context: context,
                builder: (_) => const PremiumUpgradeDialog(),
              );
              return;
            }
            HapticFeedback.lightImpact();
            _showQuestionDetail(context, question);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLocked
                  ? AppTheme.cardColor.withValues(alpha: 0.5)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isWrong
                    ? AppTheme.incorrect.withValues(alpha: 0.5)
                    : isCorrect
                        ? AppTheme.correct.withValues(alpha: 0.5)
                        : AppTheme.divider,
                width: isAnswered ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 問題番号
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isWrong
                        ? AppTheme.incorrect.withValues(alpha: 0.15)
                        : isCorrect
                            ? AppTheme.correct.withValues(alpha: 0.15)
                            : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isWrong
                            ? AppTheme.incorrect
                            : isCorrect
                                ? AppTheme.correct
                                : AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 問題内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (question.year != null)
                            Text(
                              question.year!.split('_').first,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          const Spacer(),
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, size: 10, color: AppTheme.accent),
                                  SizedBox(width: 2),
                                  Text(
                                    'Pro',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isAnswered && !isLocked)
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              size: 18,
                              color: isCorrect ? AppTheme.correct : AppTheme.incorrect,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        truncatedText,
                        style: TextStyle(
                          fontSize: 13,
                          color: isLocked
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                BookmarkButton(questionId: question.id, size: 20),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: isLocked
                      ? AppTheme.textSecondary.withValues(alpha: 0.3)
                      : AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuestionDetail(BuildContext context, Question question) {
    final correctIndex = question.correctIndex;
    final options = question.options;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 年度・カテゴリ
              Row(
                children: [
                  if (question.year != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        question.year!.split('_').first,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BookmarkButton(questionId: question.id),
                ],
              ),
              const SizedBox(height: 16),
              // 問題文
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.questionText ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 選択肢
              const Text(
                '選択肢',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...options.asMap().entries.map((entry) {
                final idx = entry.key;
                final option = entry.value;
                final isCorrect = idx == correctIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppTheme.correct.withValues(alpha: 0.15)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCorrect
                          ? AppTheme.correct
                          : AppTheme.divider,
                      width: isCorrect ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppTheme.correct
                              : AppTheme.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            color: isCorrect
                                ? AppTheme.correct
                                : AppTheme.textPrimary,
                            fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (isCorrect)
                        const Icon(Icons.check_circle, color: AppTheme.correct, size: 20),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              // 解説
              if (question.explanationSummary.isNotEmpty) ...[
                const Text(
                  '解説',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    question.explanationSummary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuizSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuizSettingsSheet(
        mode: QuizMode.category,
        category: widget.category,
      ),
    );
  }
}
