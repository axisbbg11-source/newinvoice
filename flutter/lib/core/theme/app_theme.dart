import 'package:flutter/material.dart';

/// App colors — exact values from design spec
class AppColors {
  AppColors._();

  // Brand colors
  static const Color brand = Color(0xFF1E2A52); // Navy — primary buttons, active tab, FAB
  static const Color brandDark = Color(0xFF141B38); // Gradient end / pressed state
  static const Color brandTint = Color(0xFFE7E9F2); // Light backgrounds behind brand icons/badges

  // Surfaces
  static const Color pageBackground = Color(0xFFF4F6FB); // Scaffold background
  static const Color card = Color(0xFFFFFFFF); // All cards/surfaces

  // Semantic — status colors (consistent everywhere)
  static const Color emerald = Color(0xFF189B63); // "paid" status, money-in icon
  static const Color emeraldTint = Color(0xFFE4F6ED); // paid chip background
  static const Color amber = Color(0xFFE68A00); // "pending" status, premium badge
  static const Color amberTint = Color(0xFFFFF2DE); // pending chip background
  static const Color rose = Color(0xFFE23744); // "overdue" status, money-out icon, logout
  static const Color roseTint = Color(0xFFFDEAEA); // overdue chip background

  // Quick action colors
  static const Color purple = Color(0xFF7C4DFF); // client quick-action icon
  static const Color purpleTint = Color(0xFFF1ECFF); // client icon background

  // Text
  static const Color text = Color(0xFF12141A); // headings, amounts
  static const Color muted = Color(0xFF767E8C); // labels, secondary text

  // Borders
  static const Color line = Color(0xFFE7EAF0); // card borders, dividers

  // Backward compatibility aliases for existing code
  static const Color primary = brand;
  static const Color primaryLight = brandTint;
  static const Color accent = emerald;
  static const Color accentLight = emeraldTint;
  static const Color surface = card;
  static const Color surfaceAlt = pageBackground;
  static const Color border = line;
  static const Color textPrimary = text;
  static const Color textSecondary = muted;
  static const Color textMuted = muted;
  static const Color success = emerald;
  static const Color warning = amber;
  static const Color danger = rose;
  static const Color successLight = emeraldTint;
  static const Color warningLight = amberTint;
  static const Color dangerLight = roseTint;

  // Helper method to create consistent card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A12141A),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: Color(0x0D12141A),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      );

  // Chip decoration helpers
  static BoxDecoration chipDecoration(Color bgColor) => BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      );
}

/// App text styles — Inter font, exact sizes from design spec
class AppTextStyles {
  AppTextStyles._();

  // Balance amount: 44px / weight 800 / letter-spacing -0.02em
  static const TextStyle balanceAmount = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.02,
    color: AppColors.text,
  );

  // Section titles: 19px / weight 600
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  // Card titles: 14.5px / weight 700
  static const TextStyle cardTitle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  // Labels/eyebrows: 11-12px / weight 700 / uppercase / letter-spacing .06em
  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.06,
    color: AppColors.muted,
  );

  // Body/secondary: 12-13px / weight 400-600, muted color
  static const TextStyle body = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  // Page title: 26px / weight 600
  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    color: AppColors.text,
  );

  // Brand name: 18px / weight 600
  static const TextStyle brandName = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    color: AppColors.text,
  );

  // Form title: 18px / weight 600
  static const TextStyle formTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  // Stat value: 16px / weight 800
  static const TextStyle statValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );

  // Amount (row): 15.5px / weight 600
  static const TextStyle amount = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  // Total amount: 22px / weight 600
  static const TextStyle totalAmount = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  // Chip text: 10px / weight 800 / uppercase
  static const TextStyle chip = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.03,
  );

  // Button text
  static const TextStyle button = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  // Invoice ID: 11px / weight 700
  static const TextStyle invoiceId = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.02,
    color: AppColors.muted,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBackground,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        secondary: AppColors.purple,
        surface: AppColors.card,
        error: AppColors.rose,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.muted,
        ),
      ),
      // Form field styles
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIconColor: AppColors.muted,
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rose, width: 1),
        ),
      ),
      // Primary button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // Secondary button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: const BorderSide(color: AppColors.line, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emerald,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
    );
  }

  // Card decoration helper
  static BoxDecoration get cardDecoration => AppColors.cardDecoration;
}