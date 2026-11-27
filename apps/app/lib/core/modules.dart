import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import 'providers.dart';

/// Estado de los módulos (`GET /v1/modules`, ruta pública).
///
/// La app oculta lo que administración apagó; la API además lo bloquea con
/// `MODULE_DISABLED`, así que ocultar es solo comodidad. Se refresca con
/// `ref.invalidate`.
final modulesProvider = FutureProvider<Map<AppModule, bool>>((ref) async {
  final body = await ref.watch(apiClientProvider).get('/v1/modules');
  return {
    for (final m in (body['items']! as List).cast<Map<String, Object?>>())
      ?AppModule.fromKey(m['key']! as String): m['enabled'] == true,
  };
});

/// `true` si [AppModule] está encendido. Mientras no se sabe, o si el
/// servidor no conoce los módulos, se considera encendido: la API decide.
final moduleOnProvider = Provider.family<bool, AppModule>(
  (ref, module) => ref.watch(modulesProvider).value?[module] ?? true,
);
