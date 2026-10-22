# ADR 0006: Riverpod y go_router, sin generación de código

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

El encargo propone go_router para la navegación y Riverpod para el estado. Riverpod se puede usar con generación de código (`riverpod_generator` + `build_runner`) o declarando los proveedores a mano. El equipo trabaja con varias IA distintas, y la generación de código agrega archivos `*.g.dart`, un paso extra (`build_runner`) que se olvida con facilidad, y errores confusos cuando los archivos generados se desactualizan.

## Decisión

- **go_router 18** para la navegación, con una rama de rutas por rol (`/titular`, `/caja`, `/admin`) y redirecciones según la sesión.
- **flutter_riverpod 3** con proveedores declarados a mano (`Provider`, `FutureProvider`, `NotifierProvider`), **sin** `riverpod_generator` ni `build_runner`.
- Las dependencias externas (cliente HTTP, lector de tarjetas, reloj) se inyectan por proveedores para poder reemplazarlas en pruebas con `overrides`.

## Consecuencias

- ✅ Sin pasos de compilación extra; todo el código fuente es visible y editable.
- ✅ Pruebas de widgets simples: se reemplaza `httpClientProvider` por un `MockClient`.
- ⚠️ Algo más de código repetitivo al declarar proveedores.
- ⚠️ Riverpod 3 reintenta automáticamente los proveedores que fallan; en pruebas se desactiva con `ProviderScope(retry: …)`.
