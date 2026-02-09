import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/quiz_provider.dart';
import '../ui/home/settings_screen.dart';
import '../ui/main_shell.dart';
import '../ui/number_slot/number_slot_screen.dart';
import '../ui/quiz/quiz_screen.dart';
import '../ui/result/result_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/study/bookmarked_list_screen.dart';
import '../ui/study/question_list_screen.dart';

/// アプリ全体のルーティング定義
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/question_list',
      name: 'question_list',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final category = extra?['category'] as String? ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: QuestionListScreen(category: category),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/bookmarked_list',
      name: 'bookmarked_list',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const BookmarkedListScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/quiz',

      name: 'quiz',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final fromContinue = extra?['fromContinue'] as bool? ?? false;
        final config = extra?['config'] as QuizConfig?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: QuizScreen(
            fromContinue: fromContinue,
            config: config,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/result',
      name: 'result',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        // ホットリスタート時などにextraがnullの場合はホームに戻る
        if (extra == null) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ResultScreen(correctCount: 0, totalCount: 0),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        }
        return CustomTransitionPage(
          key: state.pageKey,
          child: ResultScreen(
            correctCount: extra['correctCount'] as int,
            totalCount: extra['totalCount'] as int,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
    GoRoute(
      path: '/number-slot',
      name: 'number-slot',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const NumberSlotScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
  ],
);
