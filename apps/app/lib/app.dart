import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand/brand.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Raíz de la app: tema claro/oscuro según el sistema y navegación con
/// go_router.
class MonederoApp extends ConsumerWidget {
  /// Crea la app.
  const MonederoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: Brand.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    locale: const Locale('es', 'SV'),
    supportedLocales: const [Locale('es', 'SV'), Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
}
