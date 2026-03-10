import 'package:flutter/material.dart';

class Themes {
  static ThemeData get darkTheme {
    return _buildTheme(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF0F1115),
      surfaceColor: const Color(0xFF1A1D22),
      textColor: Colors.white,
    );
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
      scaffoldColor: const Color(0xFFF6F8FC),
      surfaceColor: Colors.white,
      textColor: const Color(0xFF1D232F),
    );
  }

  static ThemeData get neonGreenTheme {
    return _buildTheme(
      seedColor: const Color(0xFF39FF14),
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF050505),
      surfaceColor: const Color(0xFF101010),
      textColor: const Color(0xFFD9FFD1),
    );
  }

  static ThemeData get neonOrangeTheme {
    return _buildTheme(
      seedColor: const Color(0xFFFF7A00),
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF0A0704),
      surfaceColor: const Color(0xFF19110A),
      textColor: const Color(0xFFFFE8D2),
    );
  }

  static ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
    required Color scaffoldColor,
    required Color surfaceColor,
    required Color textColor,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textColor),
        bodyLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: scheme.onSurface),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(scheme.onPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
