import 'package:flutter/material.dart';

/// App colors — clean, professional palette inspired by top apps (Google Pay, Paytm)
/// Logo color: Navy Blue (#1E2A52)
class AppColors {
  AppColors._();

  // Brand colors - Based on your logo (Navy Blue #1E2A52)
  static const Color brand = Color(0xFF1E3A5F); // Professional navy - primary actions
  static const Color brandDark = Color(0xFF152C47); // Darker navy - pressed states
  static const Color brandLight = Color(0xFFE8EEF4); // Light navy - backgrounds, badges

  // Surfaces - Clean white/gray palette
  static const Color pageBackground = Color(0xFFF8FAFC); // Light gray-white background
  static const Color card = Color(0xFFFFFFFF); // Pure white cards
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Secondary surfaces

  // Semantic — refined status colors (consistent, professional)
  static const Color success = Color(0xFF16A34A); // Green - paid status
  static const Color successLight = Color(0xFFDCFCE7); // Light green background
  static const Color warning = Color(0xFFCA8A04); // Amber - pending status
  static const Color warningLight = Color(0xFFFEF9C3); // Light amber background
  static const Color error = Color(0xFFDC2626); // Red - overdue status
  static const Color errorLight = Color(0xFFFEE2E2); // Light red background
  static const Color info = Color(0xFF2563EB); // Blue - informational
  static const Color infoLight = Color(0xFFDBEAFE); // Light blue background

  // Text - Clean grays
  static const Color textPrimary = Color(0xFF1E293B); // Dark slate - headings
  static const Color textSecondary = Color(0xFF64748B); // Medium gray - secondary text
  static const Color textMuted = Color(0xFF94A3B8); // Light gray - hints, labels
  static const Color textOnBrand = Color(0xFFFFFFFF); // White text on brand color

  // Borders - Subtle
  static const Color border = Color(0xFFE2E8F0); // Light gray borders
  static const Color borderFocused = Color(0xFF1E3A5F); // Navy focus border

  // Quick action accent colors - Muted/professional versions
  static const Color accent1 = Color(0xFF7C3AED); // Purple - for variety
  static const Color accent1Light = Color(0xFFF3E8FF);
  static const Color accent2 = Color(0xFF0891B2); // Cyan
  static const Color accent2Light = Color(0xFFE0F2FE);

  // Backward compatibility aliases
  static const Color primary = brand;
  static const Color primaryLight = brandLight;
  static const Color secondary = accent1;
  static const Color secondaryLight = accent1Light;
  static const Color accent = success;
  static const Color accentLight = successLight;
  static const Color surface = card;
  static const Color surfaceAlt = pageBackground;
  static const Color text = textPrimary;
  static const Color muted = textSecondary;
  static const Color line = border;
  static const Color emerald = success;
  static const Color emeraldTint = successLight;
  static const Color amber = warning;
  static const Color amberTint = warningLight;
  static const Color rose = error;
  static const Color roseTint = errorLight;
  static const Color purple = accent1;
  static const Color purpleTint = accent1Light;
  static const Color danger = error;
  static const Color dangerLight = errorLight;
  // Legacy aliases
  static const Color brandTint = brandLight;

  // Helper method to create consistent card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // Subtle card decoration for less prominent cards
  static BoxDecoration get cardDecorationSubtle => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      );

  // Chip decoration helpers
  static BoxDecoration chipDecoration(Color bgColor) => BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      );
}

/// App text styles — Clean, professional typography
class AppTextStyles {
  AppTextStyles._();

  // Balance amount: Large display for totals
  static const TextStyle balanceAmount = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    color: AppColors.textPrimary,
  );

  // Section titles: Bold headings
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Card titles: Medium weight
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Labels/eyebrows: Small uppercase
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );

  // Body text: Regular weight
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Page title: Large heading
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    color: AppColors.textPrimary,
  );

  // Brand name: App name styling
  static const TextStyle brandName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
    color: AppColors.textPrimary,
  );

  // Form title: Form headings
  static const TextStyle formTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Stat value: Numeric values
  static const TextStyle statValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Amount (row): Inline amounts
  static const TextStyle amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Total amount: Large totals
  static const TextStyle totalAmount = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Chip text: Status badges
  static const TextStyle chip = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.03,
  );

  // Button text
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Invoice ID: Small labels
  static const TextStyle invoiceId = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.02,
    color: AppColors.textMuted,
  );

  // App bar title
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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
        secondary: AppColors.accent1,
        surface: AppColors.card,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      // Form field styles
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIconColor: AppColors.textMuted,
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      // Primary button - Clean solid color
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // Secondary button - Clean outline
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      // List tile theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
      ),
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // Card decoration helper
  static BoxDecoration get cardDecoration => AppColors.cardDecoration;
  static BoxDecoration get cardDecorationSubtle => AppColors.cardDecorationSubtle;
}