// Genera los íconos de la app (Android y web) a partir del logotipo de
// `lib/brand/brand.dart`, para que el ícono siga a la marca centralizada.
//
// No corre con `flutter test` normal (vive fuera de test/). Para regenerar
// después de cambiar la marca, desde apps/app:
//
//   flutter test tool/icons/generate_icons_test.dart --update-goldens
//
// Usa el motor de Flutter para dibujar, así no hace falta ningún programa
// de imágenes externo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monedero/brand/brand.dart';

/// Ícono: cuadrado redondeado con el degradado de la marca y el logotipo.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size, required this.maskable});

  final double size;

  /// `true`: fondo a sangre y logotipo dentro de la zona segura (80 %),
  /// para que Android/Chrome lo recorten en círculo o gota sin cortar nada.
  final bool maskable;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(Brand.seedColor, Colors.black, 0.45)!;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: maskable ? null : BorderRadius.circular(size * 0.22),
          gradient: LinearGradient(
            colors: [Brand.seedColor, dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Brand.logoIcon,
            size: size * (maskable ? 0.5 : 0.62),
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    // Las pruebas no cargan la fuente de íconos de Material por defecto.
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });

  const android = '../../android/app/src/main/res';
  const web = '../../web';
  final targets = <(String, double, bool)>[
    ('$android/mipmap-mdpi/ic_launcher.png', 48, false),
    ('$android/mipmap-hdpi/ic_launcher.png', 72, false),
    ('$android/mipmap-xhdpi/ic_launcher.png', 96, false),
    ('$android/mipmap-xxhdpi/ic_launcher.png', 144, false),
    ('$android/mipmap-xxxhdpi/ic_launcher.png', 192, false),
    ('$web/icons/Icon-192.png', 192, false),
    ('$web/icons/Icon-512.png', 512, false),
    ('$web/icons/Icon-maskable-192.png', 192, true),
    ('$web/icons/Icon-maskable-512.png', 512, true),
    ('$web/favicon.png', 64, false),
  ];

  for (final (path, size, maskable) in targets) {
    testWidgets('ícono $path', (tester) async {
      tester.view
        ..physicalSize = Size(size, size)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: _AppIcon(size: size, maskable: maskable),
            ),
          ),
        ),
      );
      await expectLater(find.byKey(key), matchesGoldenFile(path));
    });
  }
}
