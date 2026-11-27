import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local del dispositivo (en la web, `localStorage`).
///
/// Guarda la sesión de cada rol, la URL del servidor, la caja vinculada y
/// el último saldo visto del titular. **Nunca** guarda operaciones
/// pendientes: sin conexión no se mueve dinero (regla 12).
///
/// Se reemplaza en `main()` con la instancia ya cargada, y en las pruebas
/// con `SharedPreferences.setMockInitialValues`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se inicializa en main().'),
);
