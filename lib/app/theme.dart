import 'package:flutter/material.dart';


/// アプリ全体のダークテーマ定義
/// デザインリファレンス:
/// - 配色: NewsPicks Dark Mode（目に優しいダークグレー + オフホワイト）
/// - 操作感: mikan（サクサクめくるテンポ）
/// - ボタンサイズ: Yahoo!カーナビ（巨大タッチターゲット 60dp+）
/// - Primary: 衛生管理者の「緑十字」に由来するネオングリーン
class AppTheme {
  // ===== カラーパレット（ライトテーマ） =====
  static const Color background = Color(0xFFFFFFFF); // 白背景
  static const Color cardColor = Color(0xFFF5F5F5); // 薄いグレーのカード
  static const Color primary = Color(0xFF00C853); // Green（緑十字）
  static const Color accent = Color(0xFFFF9800); // Orange
  static const Color correct = Color(0xFF00C853); // 正解 = Green
  static const Color incorrect = Color(0xFFE53935); // 不正解の赤
  static const Color textPrimary = Color(0xFF212121); // 黒 (タイトル・強調)
  static const Color textBody = Color(0xFF424242); // 長文 (解説・本文)
  static const Color textSecondary = Color(0xFF757575); // 薄めラベル
  static const Color divider = Color(0xFFE0E0E0);

  /// Noto Sans JP ベースの TextTheme
  static TextTheme get _notoSansTextTheme {
    return const TextTheme(
      // 画面タイトル
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        height: 1.4,
      ),
      // セクションタイトル
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        height: 1.4,
      ),
      // サブタイトル
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
      ),
      // 問題文テキスト（あえて大きく 22sp）
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.6,
      ),
      // ボタンテキスト
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.5,
      ),
      // 本文（最低18sp, textBody色）
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.normal,
        color: textBody,
        height: 1.6,
      ),
      // 補足テキスト
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.5,
      ),
      // ラベル
      labelLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        surface: background,
        primary: primary,
        secondary: accent,
        error: incorrect,
      ),
      textTheme: _notoSansTextTheme,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(
            color: primary.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: primary,
            );
          }
          return const TextStyle(
            fontSize: 13,
            color: textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 28);
          }
          return const IconThemeData(color: textSecondary, size: 28);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 8,
          shadowColor: primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 24,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: cardColor,
        linearMinHeight: 8,
      ),
    );
  }
}
