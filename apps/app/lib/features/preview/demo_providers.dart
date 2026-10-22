import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Titular de la demostración (sembrado por `tool/seed.dart`).
const demoHolderEmail = 'ana@demo.local';

/// Sesión de caja sin contraseña (solo con `DEMO_MODE=true` en la API):
/// token del cajero, credencial del terminal y código de caja.
final cashierSessionProvider = FutureProvider<Map<String, Object?>>((
  ref,
) async {
  final s = await ref.watch(apiClientProvider).post('/v1/demo/cashier-session');
  if (s['payCode'] is! String || s['accessToken'] is! String) {
    throw const ApiException('La API no devolvió la sesión de caja.');
  }
  return s;
});

/// Pagos recibidos en la caja de la demostración.
final terminalActivityProvider = FutureProvider<List<Map<String, Object?>>>((
  ref,
) async {
  final session = await ref.watch(cashierSessionProvider.future);
  final body = await ref
      .watch(apiClientProvider)
      .get(
        '/v1/demo/terminal-activity/${session['payCode']}',
        token: session['accessToken']! as String,
      );
  return (body['items']! as List).cast<Map<String, Object?>>();
});

/// Token del titular de la demostración.
final holderTokenProvider = FutureProvider<String>((ref) async {
  final body = await ref
      .watch(apiClientProvider)
      .post('/v1/demo/holder-session', body: {'email': demoHolderEmail});
  return body['accessToken']! as String;
});

/// Tarjeta vigente del titular y sus movimientos, desde la API.
final holderCardProvider =
    FutureProvider<
      ({Map<String, Object?> card, List<Map<String, Object?>> items})
    >((ref) async {
      final api = ref.watch(apiClientProvider);
      final token = await ref.watch(holderTokenProvider.future);
      final cards =
          (await api.get('/v1/me/cards', token: token))['items']! as List;
      final card = cards.cast<Map<String, Object?>>().firstWhere(
        (c) => c['status'] == 'ACTIVE',
        orElse: () => cards.first as Map<String, Object?>,
      );
      final tx = await api.get(
        '/v1/me/cards/${card['cardId']}/transactions',
        token: token,
      );
      return (
        card: card,
        items: (tx['items']! as List).cast<Map<String, Object?>>(),
      );
    });
