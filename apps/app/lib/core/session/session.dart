import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../api/api_client.dart';
import '../config/server_settings.dart';
import '../providers.dart';
import '../storage.dart';

/// Sesión iniciada: JWT de corta duración y token de renovación (refresh).
class Session {
  /// Crea la sesión.
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.role,
    required this.userId,
    required this.fullName,
  });

  /// Construye la sesión desde la respuesta de inicio de sesión o de
  /// renovación de la API.
  factory Session.fromApi(Map<String, Object?> json, {DateTime? now}) =>
      Session(
        accessToken: json['accessToken']! as String,
        refreshToken: json['refreshToken']! as String,
        accessExpiresAt: (now ?? DateTime.now()).add(
          Duration(seconds: json['expiresInSeconds']! as int),
        ),
        role: Role.fromWire(json['role']! as String),
        userId: json['userId']! as String,
        fullName: json['fullName']! as String,
      );

  /// Lee la sesión guardada en el dispositivo.
  factory Session.fromJson(Map<String, Object?> json) => Session(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    accessExpiresAt: DateTime.parse(json['accessExpiresAt']! as String),
    role: Role.fromWire(json['role']! as String),
    userId: json['userId']! as String,
    fullName: json['fullName']! as String,
  );

  /// JWT para el encabezado `Authorization`.
  final String accessToken;

  /// Token para pedir un JWT nuevo sin volver a escribir la contraseña.
  final String refreshToken;

  /// Momento en que vence [accessToken].
  final DateTime accessExpiresAt;

  /// Rol validado por la API.
  final Role role;

  /// Id del titular o del personal.
  final String userId;

  /// Nombre para saludar.
  final String fullName;

  /// Primer nombre, para saludos cortos.
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// `true` si el JWT vence en menos de 30 segundos.
  bool get accessExpired => DateTime.now().isAfter(
    accessExpiresAt.subtract(const Duration(seconds: 30)),
  );

  /// Serializa para guardar en el dispositivo.
  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
    'role': role.wireName,
    'userId': userId,
    'fullName': fullName,
  };
}

/// Sesión de un rol de la app (titular, caja o administración).
///
/// Cada rol guarda su propia sesión, así en un mismo navegador se pueden
/// abrir tres pestañas (titular, caja y administración) durante la demo.
/// [run] agrega el token a cada llamada y, si venció, lo renueva una sola
/// vez con el token de renovación (rotación: el anterior deja de servir).
class SessionNotifier extends Notifier<Session?> {
  /// Crea la sesión del espacio [slot]; acepta sesiones de [allowedRoles].
  SessionNotifier(this.slot, this.allowedRoles);

  /// Rol del espacio (titular, caja o administración).
  final Role slot;

  /// Roles que pueden usar este espacio (la caja acepta también
  /// administración, igual que la API).
  final Set<Role> allowedRoles;

  Future<Session>? _refreshing;

  String get _key => 'session.${slot.wireName}';

  @override
  Session? build() {
    // Si cambia el servidor, las sesiones del anterior ya no sirven.
    ref.listen(serverUrlProvider, (previous, next) {
      if (previous != null && previous != next) _store(null);
    });
    return _load();
  }

  /// Guarda la sesión que devolvió la API al iniciar sesión.
  ///
  /// Lanza [ApiException] si el rol no corresponde a este espacio (por
  /// ejemplo, un cajero que intenta entrar a administración).
  void signIn(Map<String, Object?> apiSession) {
    final session = Session.fromApi(apiSession);
    if (!allowedRoles.contains(session.role)) {
      throw const ApiException(
        'Esta cuenta no tiene permiso para entrar aquí.',
        apiError: ApiError(ApiErrorCode.forbidden, 'Rol no permitido.'),
      );
    }
    _store(session);
  }

  /// Cierra la sesión: revoca el token de renovación en la API (si hay
  /// conexión) y la borra del dispositivo.
  Future<void> signOut() async {
    final current = state;
    _store(null);
    if (current == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/v1/auth/logout',
            body: {'refreshToken': current.refreshToken},
          );
    } on ApiException {
      // Sin conexión: el token vencerá solo.
    }
  }

  /// Ejecuta [action] con un JWT vigente; si la API responde
  /// `UNAUTHORIZED`, renueva la sesión y reintenta una vez.
  Future<T> run<T>(
    Future<T> Function(ApiClient api, String token) action,
  ) async {
    final api = ref.read(apiClientProvider);
    var session = state;
    if (session == null) throw _expired;
    if (session.accessExpired) session = await _refresh(session);
    try {
      return await action(api, session.accessToken);
    } on ApiException catch (error) {
      if (error.code != ApiErrorCode.unauthorized) rethrow;
      session = await _refresh(session);
      return action(api, session.accessToken);
    }
  }

  static const _expired = ApiException(
    'Tu sesión venció. Inicia sesión de nuevo.',
    apiError: ApiError(ApiErrorCode.unauthorized, 'Sesión vencida.'),
  );

  /// Una sola renovación a la vez, aunque varias llamadas la pidan juntas.
  Future<Session> _refresh(Session current) =>
      _refreshing ??= _doRefresh(current)
          .whenComplete(() => _refreshing = null);

  Future<Session> _doRefresh(Session current) async {
    try {
      final body = await ref
          .read(apiClientProvider)
          .post(
            '/v1/auth/refresh',
            body: {'refreshToken': current.refreshToken},
          );
      final next = Session.fromApi(body);
      _store(next);
      return next;
    } on ApiException catch (error) {
      if (error.isNetwork) rethrow; // Sin red: se conserva la sesión.
      // Otra pestaña del mismo rol pudo renovar primero: usa la guardada.
      final preferences = ref.read(sharedPreferencesProvider);
      await preferences.reload();
      final stored = _load();
      if (stored != null && stored.refreshToken != current.refreshToken) {
        state = stored;
        return stored;
      }
      _store(null);
      throw _expired;
    }
  }

  Session? _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null; // Formato viejo o dañado: se pide iniciar sesión.
    }
  }

  void _store(Session? session) {
    final preferences = ref.read(sharedPreferencesProvider);
    if (session == null) {
      unawaited(preferences.remove(_key));
    } else {
      unawaited(preferences.setString(_key, jsonEncode(session.toJson())));
    }
    state = session;
  }
}

/// Sesión del titular.
final holderSessionProvider = NotifierProvider<SessionNotifier, Session?>(
  () => SessionNotifier(Role.cardholder, const {Role.cardholder}),
);

/// Sesión de la caja (cajero o administración).
final cashierSessionProvider = NotifierProvider<SessionNotifier, Session?>(
  () => SessionNotifier(Role.cashier, const {Role.cashier, Role.admin}),
);

/// Sesión de administración.
final adminSessionProvider = NotifierProvider<SessionNotifier, Session?>(
  () => SessionNotifier(Role.admin, const {Role.admin}),
);
