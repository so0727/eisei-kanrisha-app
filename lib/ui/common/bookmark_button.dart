import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../providers/quiz_provider.dart';

class BookmarkButton extends ConsumerWidget {
  final int questionId;
  final Color? color;
  final double size;

  const BookmarkButton({
    super.key,
    required this.questionId,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // progressProviderのbookmarkedIdsを監視
    final isBookmarked = ref.watch(progressProvider.select(
      (state) => state.bookmarkedIds.contains(questionId),
    ));

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        color:
            isBookmarked ? AppTheme.primary : (color ?? AppTheme.textSecondary),
        size: size,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        // progressProvider経由でブックマークを切り替え
        ref.read(progressProvider.notifier).toggleBookmark(questionId);
      },
      tooltip: isBookmarked ? 'ブックマークを解除' : 'ブックマークに追加',
    );
  }
}
