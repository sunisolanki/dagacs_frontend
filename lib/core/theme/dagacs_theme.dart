import 'package:flutter/material.dart';

/// DAGACS design token palette — Education + Technology + Reliability.
///
/// A professional blue / teal system. All target screens resolve colours,
/// spacing, radii and type through these tokens (or through [DagacsTheme]),
/// which keeps the look consistent even when a screen is rendered with a plain
/// Material theme (e.g. widget tests that do not install the app theme).
abstract final class DagacsColors {
  // Brand (blue)
  static const Color brandPrimary = Color(0xFF0B5FA5);
  static const Color brandDark = Color(0xFF08406E);
  static const Color brandSoft = Color(0xFFDDEBF8);

  // Accent (teal)
  static const Color accent = Color(0xFF0E8E8E);
  static const Color accentSoft = Color(0xFFDDEEEE);

  // Neutrals
  static const Color background = Color(0xFFF2F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEAF1F8);
  static const Color textPrimary = Color(0xFF17202A);
  static const Color textSecondary = Color(0xFF5C6672);
  static const Color border = Color(0xFFD7E0EA);

  // Semantic
  static const Color success = Color(0xFF168A5E);
  static const Color successBg = Color(0xFFDCF3E9);
  static const Color warning = Color(0xFFA86B00);
  static const Color warningBg = Color(0xFFFCEFD7);
  static const Color error = Color(0xFFC0392B);
  static const Color errorBg = Color(0xFFFCECEA);
  static const Color info = Color(0xFF2E6FB0);
  static const Color infoBg = Color(0xFFDDECFA);

  // Shared shadows (subtle, never heavy).
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0A1A2E),
      blurRadius: 14,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Color(0x1A0A1A2E),
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
  ];
}

/// Consistent spacing scale.
abstract final class DagacsSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Consistent rounded-corner scale.
abstract final class DagacsRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Typography hierarchy used by the target screens.
abstract final class DagacsTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: DagacsColors.textPrimary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: DagacsColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DagacsColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: DagacsColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: DagacsColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: DagacsColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: DagacsColors.textSecondary,
  );
}

/// Extra design tokens surfaced through the theme so screens share one source
/// of truth while still working under a default Material theme.
@immutable
class DagacsTheme extends ThemeExtension<DagacsTheme> {
  const DagacsTheme({
    required this.background,
    required this.surfaceAlt,
    required this.border,
    required this.textSecondary,
    required this.brandSoft,
    required this.accentSoft,
    this.elevation = 0,
  });

  final Color background;
  final Color surfaceAlt;
  final Color border;
  final Color textSecondary;
  final Color brandSoft;
  final Color accentSoft;
  final double elevation;

  static const DagacsTheme light = DagacsTheme(
    background: DagacsColors.background,
    surfaceAlt: DagacsColors.surfaceAlt,
    border: DagacsColors.border,
    textSecondary: DagacsColors.textSecondary,
    brandSoft: DagacsColors.brandSoft,
    accentSoft: DagacsColors.accentSoft,
    elevation: 0,
  );

  /// Resolves to the app-registered theme, or the built-in light tokens when
  /// the app theme is absent (widget tests that render target screens inside a
  /// default [MaterialApp]).
  static DagacsTheme of(BuildContext context) =>
      Theme.of(context).extension<DagacsTheme>() ?? light;

  @override
  DagacsTheme copyWith({
    Color? background,
    Color? surfaceAlt,
    Color? border,
    Color? textSecondary,
    Color? brandSoft,
    Color? accentSoft,
    double? elevation,
  }) {
    return DagacsTheme(
      background: background ?? this.background,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      brandSoft: brandSoft ?? this.brandSoft,
      accentSoft: accentSoft ?? this.accentSoft,
      elevation: elevation ?? this.elevation,
    );
  }

  @override
  DagacsTheme lerp(ThemeExtension<DagacsTheme>? other, double t) {
    if (other is! DagacsTheme) return this;
    return DagacsTheme(
      background: Color.lerp(background, other.background, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      elevation: t * other.elevation,
    );
  }
}

/// Builds the single DAGACS light theme.
ThemeData buildDagacsTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: DagacsColors.brandPrimary)
      .copyWith(
    primary: DagacsColors.brandPrimary,
    onPrimary: Colors.white,
    primaryContainer: DagacsColors.brandSoft,
    onPrimaryContainer: DagacsColors.brandDark,
    secondary: DagacsColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: DagacsColors.accentSoft,
    surface: DagacsColors.surface,
    onSurface: DagacsColors.textPrimary,
    onSurfaceVariant: DagacsColors.textSecondary,
    outline: DagacsColors.border,
    outlineVariant: DagacsColors.border,
    surfaceContainerHighest: DagacsColors.surfaceAlt,
    error: DagacsColors.error,
    onError: Colors.white,
    errorContainer: DagacsColors.errorBg,
  );

  const text = TextTheme(
    displaySmall: DagacsTextStyles.display,
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: DagacsColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: DagacsColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: DagacsColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: DagacsColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: DagacsColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: DagacsColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: DagacsColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: DagacsColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: DagacsColors.background,
    textTheme: text,
    extensions: const [DagacsTheme.light],
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: DagacsColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: DagacsTextStyles.screenTitle,
      iconTheme: const IconThemeData(color: DagacsColors.textSecondary),
      actionsIconTheme:
          const IconThemeData(color: DagacsColors.textSecondary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: DagacsColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DagacsRadius.lg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DagacsColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DagacsRadius.xl),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: DagacsSpace.xl),
        backgroundColor: DagacsColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DagacsRadius.md),
        ),
        textStyle: DagacsTextStyles.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: DagacsColors.brandPrimary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        foregroundColor: DagacsColors.brandPrimary,
        side: const BorderSide(color: DagacsColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DagacsRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: DagacsColors.brandPrimary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DagacsRadius.lg),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: DagacsColors.surface,
      labelStyle: DagacsTextStyles.inputLabel,
      hintStyle: TextStyle(
        fontSize: 14,
        color: DagacsColors.textSecondary,
      ),
      prefixIconColor: DagacsColors.textSecondary,
      suffixIconColor: DagacsColors.textSecondary,
      contentPadding:
          EdgeInsets.symmetric(horizontal: DagacsSpace.lg, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
        borderSide: BorderSide(color: DagacsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
        borderSide: BorderSide(color: DagacsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
        borderSide: BorderSide(color: DagacsColors.brandPrimary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
        borderSide: BorderSide(color: DagacsColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(DagacsRadius.md)),
        borderSide: BorderSide(color: DagacsColors.error, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DagacsColors.textPrimary,
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DagacsRadius.md),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(
      color: DagacsColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DagacsColors.brandPrimary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Breakpoints for responsive grids inside the target screens.
abstract final class DagacsBreakpoints {
  static const double narrow = 640;
  static const double wide = 1100;

  /// 3 columns on large screens, 2 on medium, 1 on phones.
  static int columnsFor(double width) {
    if (width >= wide) return 3;
    if (width >= narrow) return 2;
    return 1;
  }
}