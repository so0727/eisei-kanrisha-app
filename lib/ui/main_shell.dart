import 'package:flutter/material.dart';
import '../app/theme.dart';
import 'common/banner_ad_widget.dart';
import 'home/home_screen.dart';
import 'study/study_screen.dart';
import 'stats/stats_screen.dart';

/// BottomNavigationBar付きのメインシェル
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    StudyScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.divider, width: 1),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: AppTheme.background,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
              height: 72,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, size: 28),
                  selectedIcon:
                      Icon(Icons.home, size: 28, color: AppTheme.primary),
                  label: 'ホーム',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined, size: 28),
                  selectedIcon:
                      Icon(Icons.menu_book, size: 28, color: AppTheme.primary),
                  label: '学習',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined, size: 28),
                  selectedIcon:
                      Icon(Icons.bar_chart, size: 28, color: AppTheme.primary),
                  label: '成績',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
