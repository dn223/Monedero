import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_page.dart';
import '../../features/cashier/cashier_page.dart';
import '../../features/holder/holder_page.dart';
import '../../features/holder/register_page.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/server_page.dart';

/// Rutas de la app. Cada rol tiene una sola ruta que decide qué mostrar
/// según su sesión: inicio de sesión o su pantalla principal. Los roles se
/// validan otra vez en la API en cada llamada.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: HomePage.path,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: HolderPage.path,
        builder: (context, state) => const HolderPage(),
      ),
      GoRoute(
        path: RegisterPage.path,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: CashierPage.path,
        builder: (context, state) => const CashierPage(),
      ),
      GoRoute(
        path: AdminPage.path,
        builder: (context, state) => const AdminPage(),
      ),
      GoRoute(
        path: ServerPage.path,
        builder: (context, state) => const ServerPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
