import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_page.dart';
import '../../features/preview/admin_preview_page.dart';
import '../../features/preview/cashier_preview_page.dart';
import '../../features/preview/holder_preview_page.dart';

/// Rutas de la app. Las vistas de los roles son, por ahora, vistas de
/// diseño con datos de ejemplo; se conectan a la API en las fases 4 y 5.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: HomePage.path,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: HolderPreviewPage.path,
        builder: (context, state) => const HolderPreviewPage(),
      ),
      GoRoute(
        path: CashierPreviewPage.path,
        builder: (context, state) => const CashierPreviewPage(),
      ),
      GoRoute(
        path: AdminPreviewPage.path,
        builder: (context, state) => const AdminPreviewPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
