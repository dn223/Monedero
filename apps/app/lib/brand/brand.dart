import 'package:flutter/material.dart';

/// Configuración de marca de la app: **el único archivo de código que se
/// toca para cambiar el nombre visible, los colores o el logotipo.**
///
/// El nombre definitivo aún no se decide (ver `NAMING.md`). El identificador
/// del paquete Android (`sv.edu.ufg.monedero`) es neutral y **no** cambia
/// con la marca.
///
/// Fuera del código también hay que actualizar la etiqueta de Android, el
/// título web y los íconos; la lista completa está en `NAMING.md`.
abstract final class Brand {
  /// Nombre visible de la app (provisional).
  static const String appName = 'Monedero';

  /// Frase corta que acompaña al nombre.
  static const String tagline = 'Tu tarjeta prepago, siempre a la mano';

  /// Nombre de la institución que respalda el prototipo.
  static const String organization = 'Universidad Francisco Gavidia';

  /// Color semilla de Material 3; de él se derivan los temas claro y oscuro.
  static const Color seedColor = Color(0xFF0B6E4F);

  /// Logotipo provisional. Cuando exista un logotipo propio, reemplazar por
  /// un `Image.asset` dentro de [logo].
  static const IconData logoIcon = Icons.account_balance_wallet_rounded;

  /// Widget del logotipo con el tamaño indicado.
  static Widget logo({double size = 48, Color? color}) =>
      Icon(logoIcon, size: size, color: color);
}
