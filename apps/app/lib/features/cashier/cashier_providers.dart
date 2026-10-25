import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/session/session.dart';
import '../../core/storage.dart';

/// Caja vinculada a este dispositivo: su credencial y lo que muestra.
class TerminalLink {
  /// Crea el vínculo.
  const TerminalLink({
    required this.token,
    required this.terminalId,
    required this.name,
    required this.payCode,
  });

  /// Lee el vínculo guardado.
  factory TerminalLink.fromJson(Map<String, Object?> json) => TerminalLink(
    token: json['token']! as String,
    terminalId: json['terminalId']! as String,
    name: json['name']! as String,
    payCode: json['payCode'] as String?,
  );

  /// Credencial del terminal (`X-Terminal-Token`). Se muestra una sola vez
  /// al crear la caja; aquí queda guardada en el dispositivo.
  final String token;

  /// Id del terminal.
  final String terminalId;

  /// Nombre de la caja.
  final String name;

  /// Código de 6 dígitos que el titular escribe para pagar desde su app.
  final String? payCode;

  /// Serializa para guardar.
  Map<String, Object?> toJson() => {
    'token': token,
    'terminalId': terminalId,
    'name': name,
    'payCode': payCode,
  };
}

/// Caja vinculada a este dispositivo (independiente de quién inicie
/// sesión: así funciona una caja real con varios cajeros por turno).
class TerminalNotifier extends Notifier<TerminalLink?> {
  static const _key = 'terminal.link';

  @override
  TerminalLink? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return null;
    try {
      return TerminalLink.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  /// Vincula la caja con la credencial [token]: la API la valida y
  /// devuelve su nombre y código de pago.
  Future<void> link(String token) async {
    final info = await ref
        .read(cashierSessionProvider.notifier)
        .run(
          (api, jwt) =>
              api.get('/v1/cards/terminal', token: jwt, terminal: token),
        );
    _save(
      TerminalLink(
        token: token,
        terminalId: info['terminalId']! as String,
        name: info['name']! as String,
        payCode: info['payCode'] as String?,
      ),
    );
  }

  /// Solo modo demo: crea una caja "Caja demo N" para este dispositivo y
  /// la vincula.
  Future<void> createDemo() async {
    final created = await ref
        .read(cashierSessionProvider.notifier)
        .run((api, jwt) => api.post('/v1/demo/terminals', token: jwt));
    await link(created['terminalToken']! as String);
  }

  /// Desvincula la caja de este dispositivo.
  void unlink() => _save(null);

  void _save(TerminalLink? link) {
    final preferences = ref.read(sharedPreferencesProvider);
    if (link == null) {
      unawaited(preferences.remove(_key));
    } else {
      unawaited(preferences.setString(_key, jsonEncode(link.toJson())));
    }
    state = link;
  }
}

/// Caja vinculada a este dispositivo.
final terminalProvider = NotifierProvider<TerminalNotifier, TerminalLink?>(
  TerminalNotifier.new,
);

/// Llamadas de la caja: sesión del cajero + credencial de la caja.
class CashierApi {
  /// Crea el servicio.
  CashierApi(this._ref);

  final Ref _ref;

  /// Llama a la API como cajero con la credencial de la caja. Si la caja
  /// fue revocada (`TERMINAL_NOT_AUTHORIZED`), la desvincula para pedir
  /// otra.
  Future<Map<String, Object?>> call(
    Future<Map<String, Object?>> Function(
      ApiClient api,
      String token,
      String terminal,
    )
    action,
  ) async {
    final terminal = _ref.read(terminalProvider);
    if (terminal == null) {
      throw const ApiException(
        'Vincula esta caja primero.',
        apiError: ApiError(ApiErrorCode.terminalNotAuthorized, 'Sin caja.'),
      );
    }
    try {
      return await _ref
          .read(cashierSessionProvider.notifier)
          .run((api, token) => action(api, token, terminal.token));
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.terminalNotAuthorized) {
        _ref.read(terminalProvider.notifier).unlink();
      }
      rethrow;
    }
  }

  /// Tarjetas activas de demostración con sus credenciales (solo modo
  /// demo; fuera de él, lista vacía).
  Future<List<Map<String, Object?>>> demoCards() async {
    if (!_ref.read(demoModeProvider)) return const [];
    final body = await _ref
        .read(cashierSessionProvider.notifier)
        .run((api, token) => api.get('/v1/demo/cards', token: token));
    return (body['items']! as List).cast<Map<String, Object?>>();
  }
}

/// Servicio de llamadas de la caja.
final cashierApiProvider = Provider<CashierApi>(CashierApi.new);

/// Últimos movimientos hechos en esta caja (incluye los pagos que hacen
/// los titulares con el código de caja). La pantalla lo refresca cada pocos
/// segundos.
final terminalActivityProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      ref.watch(terminalProvider.select((t) => t?.token));
      final body = await ref
          .read(cashierApiProvider)
          .call(
            (api, token, terminal) => api.get(
              '/v1/cards/terminal-activity',
              token: token,
              terminal: terminal,
            ),
          );
      return (body['items']! as List).cast<Map<String, Object?>>();
    });
