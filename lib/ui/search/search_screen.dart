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

/// 検索結果プロバイダー
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchResultsProvider = FutureProvider<List<Question>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty || query.length < 2) {
    return [];
  }
  final repo = ref.watch(questionRepositoryProvider);
  final questions = await repo.loadQuestions();
  final lowerQuery = query.toLowerCase();
  return questions.where((q) {
    final text = q.questionText?.toLowerCase() ?? '';
    final options = q.options?.join(' ').toLowerCase() ?? '';
    final explanation = q.explanationSummary.toLowerCase();
    return text.contains(lowerQuery) || options.contains(lowerQuery) || explanation.contains(lowerQuery);
  }).toList();

});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 画面が開いたら自動でフォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final subscription = ref.watch(userSubscriptionProvider);
    final isFree = subscription == UserSubscriptionStatus.free;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'キーワードで検索...',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppTheme.divider),
          Expanded(
            child: results.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => Center(
                child: Text('エラーが発生しました: $e'),
              ),
              data: (questions) {
                if (query.isEmpty) {
                  return _buildEmptyState('キーワードを入力して\n問題を検索できます');
                }
                if (query.length < 2) {
                  return _buildEmptyState('2文字以上で検索してください');
                }
                if (questions.isEmpty) {
                  return _buildEmptyState('「$query」に一致する問題が\n見つかりませんでした');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionTile(
                      context,
                      questions[index],
                      isFree,
                      query,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(
    BuildContext context,
    Question question,
    bool isFree,
    String query,
  ) {
    // Freeユーザーは2022-2023年のみ
    final isLocked = isFree &&
        question.year != null &&
        !question.year!.startsWith('2022') &&
        !question.year!.startsWith('2023');

    final questionText = question.questionText ?? '';
    final truncatedText = questionText.length > 80
        ? '${questionText.substring(0, 80)}...'
        : questionText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            // 詳細を表示
            _showQuestionDetail(context, question);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLocked
                  ? AppTheme.cardColor.withValues(alpha: 0.5)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        question.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (question.year != null)
                      Text(
                        question.year!.split('_').first,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    const Spacer(),
                    if (isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 12, color: AppTheme.accent),
                            SizedBox(width: 4),
                            Text(
                              'Pro',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    BookmarkButton(questionId: question.id, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _highlightQuery(truncatedText, query),
                  style: TextStyle(
                    fontSize: 14,
                    color: isLocked
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _highlightQuery(String text, String query) {
    // シンプルにテキストをそのまま返す（ハイライトはRichTextで実装）
    return text;
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
}
