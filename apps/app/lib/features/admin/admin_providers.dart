import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session.dart';

/// Llama a la API con la sesión de administración.
Future<Map<String, Object?>> adminCall(
  Ref ref,
  Future<Map<String, Object?>> Function(ApiClient api, String token) action,
) => ref.read(adminSessionProvider.notifier).run(action);

List<Map<String, Object?>> _items(Map<String, Object?> body) =>
    (body['items']! as List).cast<Map<String, Object?>>();

/// Indicadores del tablero (`GET /v1/admin/stats`).
final adminStatsProvider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) =>
      adminCall(ref, (api, token) => api.get('/v1/admin/stats', token: token)),
);

/// Conciliación saldo vs. suma de movimientos (regla 7).
final reconciliationProvider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) => adminCall(
    ref,
    (api, token) => api.get('/v1/admin/reconciliation', token: token),
  ),
);

/// Tarjetas que coinciden con la búsqueda (número, titular o correo).
final adminCardsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
      (ref, query) async => _items(
        await adminCall(
          ref,
          (api, token) => api.get(
            '/v1/admin/cards?q=${Uri.encodeQueryComponent(query)}',
            token: token,
          ),
        ),
      ),
    );

/// Titulares que coinciden con la búsqueda, con su tarjeta vigente.
final adminHoldersProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
      (ref, query) async => _items(
        await adminCall(
          ref,
          (api, token) => api.get(
            '/v1/admin/cardholders?q=${Uri.encodeQueryComponent(query)}',
            token: token,
          ),
        ),
      ),
    );

/// Cajas registradas.
final adminTerminalsProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>(
      (ref) async => _items(
        await adminCall(
          ref,
          (api, token) => api.get('/v1/admin/terminals', token: token),
        ),
      ),
    );

/// Movimientos de una tarjeta (vista de administración).
final adminCardTransactionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
      (ref, cardId) async => _items(
        await adminCall(
          ref,
          (api, token) =>
              api.get('/v1/admin/cards/$cardId/transactions', token: token),
        ),
      ),
    );
