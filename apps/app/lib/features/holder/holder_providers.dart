import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/storage.dart';

/// Lo que ve el titular: su tarjeta vigente y sus movimientos.
class HolderSnapshot {
  /// Crea la foto.
  const HolderSnapshot({
    required this.card,
    required this.transactions,
    this.staleSince,
  });

  /// Tarjeta vigente (la más reciente que no fue repuesta), o `null` si aún
  /// no tiene. Sin conexión solo trae los datos guardados (sin credenciales).
  final Map<String, Object?>? card;

  /// Movimientos de la tarjeta vigente, el más reciente primero.
  final List<Map<String, Object?>> transactions;

  /// Si no hubo conexión: desde cuándo es el saldo guardado (regla 12:
  /// se muestra marcado como "no actualizado" y no permite operar).
  final DateTime? staleSince;

  /// `true` si los datos vienen de la caché.
  bool get isStale => staleSince != null;
}

/// Tarjeta y movimientos del titular desde la API.
///
/// Si no hay conexión, devuelve el último saldo guardado en el dispositivo
/// marcado como no actualizado; nunca guarda credenciales de la tarjeta.
final holderSnapshotProvider = FutureProvider.autoDispose<HolderSnapshot>((
  ref,
) async {
  final userId = ref.watch(holderSessionProvider.select((s) => s?.userId));
  if (userId == null) {
    throw const ApiException('Inicia sesión para ver tu tarjeta.');
  }
  final session = ref.read(holderSessionProvider.notifier);
  final preferences = ref.read(sharedPreferencesProvider);
  final cacheKey = 'holder.cache.$userId';
  try {
    final body = await session.run(
      (api, token) => api.get('/v1/me/cards', token: token),
    );
    final cards = (body['items']! as List).cast<Map<String, Object?>>();
    final card =
        cards.where((c) => c['status'] != 'REPLACED').firstOrNull ??
        cards.firstOrNull;
    if (card == null) {
      return const HolderSnapshot(card: null, transactions: []);
    }
    final tx = await session.run(
      (api, token) =>
          api.get('/v1/me/cards/${card['cardId']}/transactions', token: token),
    );
    await preferences.setString(
      cacheKey,
      jsonEncode({
        'numberMasked': card['numberMasked'],
        'cardholderName': card['cardholderName'],
        'status': card['status'],
        'balanceCents': card['balanceCents'],
        'at': DateTime.now().toIso8601String(),
      }),
    );
    return HolderSnapshot(
      card: card,
      transactions: (tx['items']! as List).cast<Map<String, Object?>>(),
    );
  } on ApiException catch (error) {
    final cached = preferences.getString(cacheKey);
    if (!error.isNetwork || cached == null) rethrow;
    final data = jsonDecode(cached) as Map<String, Object?>;
    return HolderSnapshot(
      card: {...data, 'number': data['numberMasked']},
      transactions: const [],
      staleSince: DateTime.parse(data['at']! as String),
    );
  }
});

/// Correos que recibió el titular (solo modo demo): códigos y avisos de
/// movimiento, para quien prueba sin acceso a Mailpit.
final holderInboxProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      ref.watch(holderSessionProvider.select((s) => s?.userId));
      if (!ref.watch(demoModeProvider)) return const [];
      final body = await ref
          .read(holderSessionProvider.notifier)
          .run((api, token) => api.get('/v1/demo/inbox', token: token));
      return (body['items']! as List).cast<Map<String, Object?>>();
    });
