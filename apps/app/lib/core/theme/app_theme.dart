import 'package:flutter/material.dart';

import '../../brand/brand.dart';

/// Temas Material 3 de la app, derivados del color de [Brand].
///
/// Criterios de diseño (ver docs/architecture.md § Interfaz):
/// - El dinero y los códigos son los protagonistas: cifras tabulares y
///   pesos fuertes ([AppText.money]) para que los montos se alineen.
/// - Jerarquía de esquinas: 24 en la tarjeta virtual, 16 en contenedores,
///   12 en campos y botones.
/// - Colores de gráficos y de estado en [AppPalette], con su versión para
///   el tema oscuro (validados para daltonismo).
abstract final class AppTheme {
  /// Tema claro.
  static ThemeData get light => _build(Brightness.light);

  /// Tema oscuro.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.seedColor,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
    );
    final text = base.textTheme;
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [
        brightness == Brightness.light ? AppPalette.light : AppPalette.dark,
      ],
    );
  }
}

/// Estilos de texto para cifras.
abstract final class AppText {
  /// [style] con cifras tabulares, para que los montos se alineen en
  /// columnas y no "bailen" al cambiar.
  static TextStyle money(TextStyle? style) => (style ?? const TextStyle())
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Colores que Material 3 no trae: series de gráficos y estado "bien".
///
/// Las dos series (recargas y cobros) son los dos primeros colores de la
/// paleta categórica de referencia del skill de visualización, validados
/// con su script: separación para daltonismo ΔE 24.7 (claro) y 26.8
/// (oscuro), contraste ≥ 3:1 con la superficie.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Crea la paleta.
  const AppPalette({
    required this.topUp,
    required this.debit,
    required this.good,
    required this.onGood,
  });

  /// Paleta del tema claro.
  static const light = AppPalette(
    topUp: Color(0xFF2A78D6),
    debit: Color(0xFFEB6834),
    good: Color(0xFF1B6E3A),
    onGood: Color(0xFFFFFFFF),
  );

  /// Paleta del tema oscuro (pasos propios, no una inversión automática).
  static const dark = AppPalette(
    topUp: Color(0xFF3987E5),
    debit: Color(0xFFD95926),
    good: Color(0xFF7DD99A),
    onGood: Color(0xFF00391A),
  );

  /// Serie "recargas" en los gráficos.
  final Color topUp;

  /// Serie "cobros" en los gráficos.
  final Color debit;

  /// Estado correcto (conciliación en cero).
  final Color good;

  /// Texto e íconos sobre [good].
  final Color onGood;

  /// Paleta del tema de [context].
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? topUp,
    Color? debit,
    Color? good,
    Color? onGood,
  }) => AppPalette(
    topUp: topUp ?? this.topUp,
    debit: debit ?? this.debit,
    good: good ?? this.good,
    onGood: onGood ?? this.onGood,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      topUp: Color.lerp(topUp, other.topUp, t)!,
      debit: Color.lerp(debit, other.debit, t)!,
      good: Color.lerp(good, other.good, t)!,
      onGood: Color.lerp(onGood, other.onGood, t)!,
    );
  }
}
