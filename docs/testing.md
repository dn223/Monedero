# Pruebas

## 1. Cómo correrlas

| Qué | Comando (desde la raíz) | Requiere Docker |
|---|---|---|
| **Todo** (formato, análisis, guardia de dinero y pruebas) | `dart run tool/check.dart` | No en Fase 1; sí desde la Fase 2 (integración) |
| Unitarias de `core` | `cd packages/core && dart test` | No |
| API (unitarias e integración) | `cd api && dart test` | Integración: sí |
| Widgets de la app | `cd apps/app && flutter test` | No |
| Análisis estático | `flutter analyze` | No |
| Formato | `dart run tool/check.dart --fix` | No |

En GitHub Actions (`.github/workflows/ci.yml`) se corre lo mismo en cada pull request.

## 2. Tipos de prueba

| Tipo | Dónde | Qué demuestra |
|---|---|---|
| Unitarias | `packages/core/test` | Luhn, validación de montos, firma de tarjeta, serialización de DTOs y errores |
| Unitarias de la API | `api/test` | Rutas, CORS, formato de errores y configuración, sin base de datos |
| Integración | `api/test/integration` (Fase 2) | Reglas de negocio contra **PostgreSQL real** en Docker: transacciones, bloqueos, permisos, triggers |
| Widgets | `apps/app/test` | Pantallas y flujos principales con la API simulada (`MockClient`) |
| Guardia de dinero | `tool/check.dart` | Que no aparezca `double`/`num` para dinero en Dart ni tipos decimales en SQL |

## 3. Pruebas obligatorias de diseño

Demuestran que la arquitectura protege el dinero aunque haya concurrencia, reintentos o fallas. Se implementan en la Fase 2.

| # | Prueba | Qué debe pasar | Regla | Estado |
|---|---|---|---|---|
| 1 | 1,000 débitos concurrentes sobre la misma tarjeta | El saldo nunca es negativo, se rechazan exactamente los que exceden y la conciliación da **cero diferencias** | 3, 4, 6, 7 | Fase 2 |
| 2 | Misma operación enviada 5 veces con la misma `Idempotency-Key` | Se aplica **una sola vez**; las 5 respuestas son idénticas | 5 | Fase 2 |
| 3 | Reposición con falla forzada a mitad de la transacción | Todo se revierte; el saldo sigue intacto en la tarjeta bloqueada y no existe tarjeta nueva | 11 | Fase 2 |
| 4 | `UPDATE` o `DELETE` de un movimiento | La base lo rechaza (por permisos **y** por trigger, probados por separado) | 6 | Fase 2 |
| 5 | Firma inválida o UID cambiado | La operación se rechaza con `INVALID_CARD_SIGNATURE` y el saldo no cambia | 10 | Fase 2 |

## 4. Estado actual (Fase 1)

| Paquete | Pruebas | Resultado |
|---|---|---|
| `packages/core` | 5 | ✅ |
| `api` | 8 | ✅ |
| `apps/app` | 2 | ✅ |

## 5. Reglas

- Nunca se desactiva, salta (`skip`) ni debilita una prueba para que pase. Si una prueba está mal, se corrige y se explica en el pull request.
- Las pruebas de integración usan una base propia de pruebas y la limpian; nunca tocan los datos de la demo.
- Cada error de negocio nuevo (`ApiErrorCode`) necesita al menos una prueba que lo provoque.
