import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../data/models/question.dart';
import '../../providers/quiz_provider.dart';
import '../common/bookmark_button.dart';

/// ブックマーク問題一覧画面
class BookmarkedListScreen extends ConsumerStatefulWidget {
  const BookmarkedListScreen({super.key});

  @override
  ConsumerState<BookmarkedListScreen> createState() =>
      _BookmarkedListScreenState();
}

class _BookmarkedListScreenState extends ConsumerState<BookmarkedListScreen> {
  List<Question> _questions = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final repo = ref.read(questionRepositoryProvider);
    final progress = ref.read(progressProvider);
    final bookmarkedIds = progress.bookmarkedIds;

    if (bookmarkedIds.isEmpty) {
      if (mounted) {
        setState(() {
          _questions = [];
          _isLoaded = true;
        });
      }
      return;
    }

    final questions = await repo.loadByIds(bookmarkedIds);
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ブックマーク',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
      ),
      body: !_isLoaded
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _questions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    return _buildQuestionTile(context, question, progress);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'ブックマークした問題がありません',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '問題一覧でブックマークアイコンをタップして追加',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(
      BuildContext context, Question question, ProgressState progress) {
    final isAnswered = progress.answeredIds.contains(question.id);
    final isCorrect = progress.correctIds.contains(question.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showQuestionDetail(context, question),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 番号
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${question.id}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 問題テキスト
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.questionText ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${question.year ?? ''} | ${question.category ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ステータスと操作
                Column(
                  children: [
                    if (isAnswered)
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color:
                            isCorrect ? AppTheme.correct : AppTheme.incorrect,
                      ),
                    const SizedBox(height: 4),
                    BookmarkButton(questionId: question.id, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuestionDetail(BuildContext context, Question question) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
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
              // 年度とカテゴリ
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      question.year ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.category ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  BookmarkButton(questionId: question.id),
                ],
              ),
              const SizedBox(height: 16),
              // 問題文
              Text(
                question.questionText ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              // 選択肢
              ...List.generate(question.options?.length ?? 0, (i) {
                final isCorrect = i == question.correctIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppTheme.correct.withValues(alpha: 0.15)
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? AppTheme.correct
                            : AppTheme.divider,
                        width: isCorrect ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isCorrect)
                          const Icon(Icons.check_circle,
                              color: AppTheme.correct, size: 20),
                        if (isCorrect) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.options?[i] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: isCorrect
                                  ? AppTheme.correct
                                  : AppTheme.textPrimary,
                              fontWeight: isCorrect
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              // 解説
              if (question.explanationSummary?.isNotEmpty == true) ...[
                const Text(
                  '解説',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    question.explanationSummary ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
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
}
