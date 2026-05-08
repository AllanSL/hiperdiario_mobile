import 'package:flutter/material.dart';

/// Tema do HiperDiário
class AppTheme {
  /// Tema padrão (escala 1.0)
  static ThemeData get defaultTheme => buildTheme(1.0);

  /// Gera um [ThemeData] com os tamanhos escalados pelo [factor].
  ///
  /// [factor] = 1.0 → Normal, 1.3 → Grande, 1.6 → Extra Grande
  ///
  /// Usa escala suavizada (f) para que fontes cresçam sem quebrar layouts:
  ///   Normal → f = 1.0 | Grande → f ≈ 1.15 | Extra Grande → f ≈ 1.30
  static ThemeData buildTheme(double factor) {
    // Escala suavizada — cresce 50% da diferença do factor original.
    // Garante textos maiores para acessibilidade sem estourar containers.
    final double f = 1.0 + (factor - 1.0) * 0.5;

    final baseBodyLarge = 20.0 * f;
    final baseBodyMedium = 18.0 * f;
    final baseLabelLarge = 18.0 * f;
    final baseTitleLarge = 22.0 * f;
    final baseBodySmall = 14.0 * f;

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal);

    return ThemeData(
      colorScheme: colorScheme,
      visualDensity: VisualDensity.comfortable,
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(fontSize: 18.0 * f, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: baseBodyLarge),
        bodyMedium: TextStyle(fontSize: baseBodyMedium),
        bodySmall: TextStyle(fontSize: baseBodySmall),
        labelLarge: TextStyle(
          fontSize: baseLabelLarge,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(fontSize: 14.0 * f),
        labelSmall: TextStyle(fontSize: 12.0 * f),
      ),
      iconTheme: IconThemeData(size: 24.0 * f),
      buttonTheme: ButtonThemeData(minWidth: 64 * f, height: 48 * f),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle: TextStyle(fontSize: baseLabelLarge),
        iconSize: 24.0 * f,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12.0 * f)),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 24.0 * f)),
        height: 64.0 * f,
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        toolbarHeight: 56.0 * f,
        iconTheme: IconThemeData(size: 24.0 * f, color: colorScheme.primary),
      ),
      // Drawer mais largo para acomodar textos grandes
      drawerTheme: DrawerThemeData(width: 304.0 * f),
      // ListTile: título não quebra sílaba, usa tamanho escalado
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(fontSize: 16.0 * f, color: Colors.black87),
        subtitleTextStyle: TextStyle(
          fontSize: baseBodySmall,
          color: Colors.grey.shade600,
        ),
        leadingAndTrailingTextStyle: TextStyle(fontSize: baseBodySmall),
        iconColor: Colors.grey.shade700,
        minLeadingWidth: 24.0 * f,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0 * f),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4.0 * f),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * f,
          vertical: 12.0 * f,
        ),
        labelStyle: TextStyle(fontSize: 16.0 * f),
        floatingLabelStyle: TextStyle(fontSize: 13.0 * f),
        prefixIconColor: colorScheme.primary,
      ),
      // Chip com texto sempre escuro e legível
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: 12.0 * f,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.0 * f, vertical: 4.0 * f),
        brightness: Brightness.light,
      ),
      // Diálogos com texto escalado
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        contentTextStyle: TextStyle(
          fontSize: baseBodyMedium,
          color: Colors.black87,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        menuPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  /// Gera um [ThemeData] escuro com os tamanhos escalados pelo [factor].
  static ThemeData buildDarkTheme(double factor) {
    final double f = 1.0 + (factor - 1.0) * 0.5;

    final baseBodyLarge = 20.0 * f;
    final baseBodyMedium = 18.0 * f;
    final baseLabelLarge = 18.0 * f;
    final baseTitleLarge = 22.0 * f;
    final baseBodySmall = 14.0 * f;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.comfortable,
      brightness: Brightness.dark,
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(fontSize: 18.0 * f, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: baseBodyLarge),
        bodyMedium: TextStyle(fontSize: baseBodyMedium),
        bodySmall: TextStyle(fontSize: baseBodySmall),
        labelLarge: TextStyle(
          fontSize: baseLabelLarge,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(fontSize: 14.0 * f),
        labelSmall: TextStyle(fontSize: 12.0 * f),
      ),
      iconTheme: IconThemeData(size: 24.0 * f),
      buttonTheme: ButtonThemeData(minWidth: 64 * f, height: 48 * f),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle: TextStyle(fontSize: baseLabelLarge),
        iconSize: 24.0 * f,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12.0 * f)),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 24.0 * f)),
        height: 64.0 * f,
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        toolbarHeight: 56.0 * f,
        iconTheme: IconThemeData(size: 24.0 * f, color: colorScheme.primary),
      ),
      drawerTheme: DrawerThemeData(width: 304.0 * f),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 16.0 * f,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: baseBodySmall,
          color: colorScheme.onSurfaceVariant,
        ),
        leadingAndTrailingTextStyle: TextStyle(fontSize: baseBodySmall),
        iconColor: colorScheme.onSurfaceVariant,
        minLeadingWidth: 24.0 * f,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0 * f),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4.0 * f),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0 * f,
          vertical: 12.0 * f,
        ),
        labelStyle: TextStyle(fontSize: 16.0 * f),
        floatingLabelStyle: TextStyle(fontSize: 13.0 * f),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontSize: 12.0 * f, fontWeight: FontWeight.w600),
        padding: EdgeInsets.symmetric(horizontal: 8.0 * f, vertical: 4.0 * f),
        brightness: Brightness.dark,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
          fontSize: baseTitleLarge,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: baseBodyMedium,
          color: colorScheme.onSurface,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        menuPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }
}

/// Scroll behavior sem bounce/glow
class NoBounceSrollBehavior extends ScrollBehavior {
  const NoBounceSrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
