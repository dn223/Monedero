# Pruebas

## 1. Cómo correrlas

| Qué | Comando (desde la raíz) | Requiere Docker |
|---|---|---|
| **Todo** (formato, análisis, guardia de dinero y pruebas) | `dart run tool/check.dart` | **Sí** (`dart run tool/up.dart` antes) |
| Unitarias de `core` | `cd packages/core && dart test` | No |
| API (unitarias e integración) | `cd api && dart test` | Sí |
| Widgets de la app | `cd apps/app && flutter test` | No |
| Análisis estático | `flutter analyze` | No |
| Formato | `dart run tool/check.dart --fix` | No |

En GitHub Actions (`.github/workflows/ci.yml`) se corre lo mismo en cada pull request.

## 2. Tipos de prueba

| Tipo | Dónde | Qué demuestra |
|---|---|---|
| Unitarias | `packages/core/test` | Luhn, validación de montos, firma de tarjeta, serialización de DTOs y errores |
| Unitarias de la API | `api/test` | Rutas, CORS, formato de errores y configuración, sin base de datos |
| Integración | `api/test/integration` (cada archivo crea y migra su propia base: `monedero_test`, `monedero_test_fase5`; corren de a uno, ver `api/dart_test.yaml`) | Reglas de negocio contra **PostgreSQL real** en Docker: transacciones, bloqueos, permisos, triggers, renovación de sesión, modo demo, tablero y reinicio |
| Widgets | `apps/app/test` | Flujos reales con la API simulada (`FakeApi` sobre `MockClient`) y almacenamiento simulado |
| Íconos | `apps/app/tool/icons` (no corre con `flutter test`) | Genera los íconos desde la marca: `flutter test tool/icons/generate_icons_test.dart --update-goldens` |
| Guardia de dinero | `tool/check.dart` | Que no aparezca `double`/`num` para dinero en Dart ni tipos decimales en SQL |

## 3. Pruebas obligatorias de diseño

Demuestran que la arquitectura protege el dinero aunque haya concurrencia, reintentos o fallas. Están en `api/test/integration/design_test.dart`.

| # | Prueba | Qué debe pasar | Regla | Estado |
|---|---|---|---|---|
| 1 | 1,000 débitos concurrentes de $0.25 sobre una tarjeta con $100 | Exactamente 400 aplicados y 600 rechazados por saldo; saldo final $0; ningún saldo negativo; **conciliación en cero** | 3, 4, 6, 7 | ✅ |
| 2 | Misma operación 5 veces (en serie y en paralelo) con la misma `Idempotency-Key` | Se aplica **una sola vez**; respuestas idénticas; otra operación con la misma clave → `IDEMPOTENCY_KEY_REUSED`; una operación rechazada no consume la clave | 5 | ✅ |
| 3 | Reposición con falla forzada después de sacar el saldo | Todo se revierte: saldo intacto en la tarjeta `BLOCKED`, sin tarjeta nueva ni auditoría; sin falla, se conserva el saldo | 11 | ✅ |
| 4 | `UPDATE` o `DELETE` de un movimiento | Rechazado por permisos (usuario de la API, error 42501) **y** por trigger (dueño del esquema) | 6 | ✅ |
| 5 | Firma inválida o UID cambiado | `INVALID_CARD_SIGNATURE` y el saldo no cambia | 10 | ✅ |

## 4. Estado actual (Fase 6)

| Paquete | Pruebas | Resultado |
|---|---|---|
| `packages/core` | 22 (Luhn, montos, formato, firma, errores, QR de tarjeta, vínculo de caja y URL del servidor) | ✅ |
| `api` | 31 (unitarias de rutas, CORS, límite de solicitudes y app web; integración: las 5 obligatorias, reglas de caja, renovación y cierre de sesión, códigos y buzón demo, cajas demo, tablero, búsqueda y reinicio de la demo) | ✅ |
| `apps/app` | 6 (inicio, sin servidor, inicio de sesión del titular, renovación automática de sesión, cobro en caja con comprobante, tablero de administración) | ✅ |

Además se probó a mano la app publicada (build release servido por la API) a ancho de escritorio y de celular, en tema claro y oscuro, y por el link público del túnel: inicio de sesión de los tres roles, recarga, cobro con PIN, saldo insuficiente, ticket, tablero y gráfico.

## 5. Reglas

- Nunca se desactiva, salta (`skip`) ni debilita una prueba para que pase. Si una prueba está mal, se corrige y se explica en el pull request.
- Las pruebas de integración usan una base propia de pruebas y la limpian; nunca tocan los datos de la demo.
- Cada error de negocio nuevo (`ApiErrorCode`) necesita al menos una prueba que lo provoque.
