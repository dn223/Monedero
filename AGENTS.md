# AGENTS.md — Instrucciones para cualquier IA (y personas) en este repositorio

> **Fuente única de instrucciones.** Claude Code, Codex, Cursor, Copilot, Gemini
> o cualquier otra IA debe leer este archivo completo antes de tocar el código.
> `CLAUDE.md`, `GEMINI.md` y `.github/copilot-instructions.md` solo remiten aquí.

---

## 1. Resumen del proyecto

1. **Monedero** (nombre provisional, ver `NAMING.md`) es un monedero electrónico prepago recargable de **circuito cerrado**, como la tarjeta prepago de un supermercado.
2. Cada tarjeta tiene un número único de 16 dígitos (Luhn) y un saldo. Se **recarga en caja** y se **gasta en compras** dentro del comercio.
3. Proyecto académico de la UFG (Gestión de la Calidad del Software), diseñado y documentado **como si manejara dinero real**.
4. Una sola app **Flutter** (Android + Web) con tres roles: **titular**, **caja** y **administración**.
5. **API en Dart** (`shelf` + `shelf_router`) sobre **PostgreSQL 17**, que es la única fuente de verdad del saldo.
6. Código compartido (modelos, validaciones, DTOs) en `packages/core`, unido con **pub workspaces**.
7. En esta fase **no hay NFC ni tarjetas físicas**: las tarjetas se simulan con QR (`CardReader` → `SimulatedCardReader`).
8. Todo corre **local y gratis** con Docker Compose (PostgreSQL, API, Mailpit). Producción en Contabo solo se **prepara** en `deploy/`.
9. Cada operación que cambia saldo es **atómica, idempotente y auditable**; la base de datos es la última barrera.
10. El equipo trabaja con varias IA: el protocolo de traspaso (sección 8) es obligatorio.

Documentación: [setup](docs/setup.md) · [arquitectura](docs/architecture.md) · [dominio y glosario](docs/domain.md) · [API](docs/api.md) ([OpenAPI](docs/openapi.yaml)) · [base de datos](docs/database.md) · [pruebas](docs/testing.md) · [demo](docs/demo.md) · [NFC](docs/nfc.md) · [despliegue](docs/deploy-contabo.md) · [ADR](docs/adr/) · [bitácora](docs/BITACORA.md) · [roadmap](docs/ROADMAP.md)

---

## 2. Comandos exactos

Todos se ejecutan **desde la raíz del repositorio** y funcionan igual en Windows (PowerShell) y macOS (zsh).

| Tarea | Comando |
|---|---|
| Diagnóstico del equipo | `dart run tool/doctor.dart` |
| Instalar dependencias (todo el workspace) | `flutter pub get` |
| Levantar base, API y Mailpit | `dart run tool/up.dart` |
| Detener (conserva datos) | `dart run tool/down.dart` |
| Detener y borrar la base | `dart run tool/down.dart --borrar-datos` |
| Ver logs de la API | `docker compose logs -f api` |
| **Verificación completa** (formato + análisis + guardia de dinero + pruebas) | `dart run tool/check.dart` |
| Formatear | `dart run tool/check.dart --fix` |
| Analizar (lint) | `flutter analyze` |
| Pruebas de `core` | `cd packages/core && dart test` |
| Pruebas de la API | `cd api && dart test` |
| Pruebas de la app | `cd apps/app && flutter test` |
| App web | `cd apps/app && flutter run -d chrome --web-port 5000` |
| App en emulador Android | `cd apps/app && flutter run` (usa `http://10.0.2.2:8080`) |
| App en teléfono (misma Wi-Fi) | `cd apps/app && flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8080` |
| Aplicar migraciones | `dart run tool/migrate.dart` *(desde la Fase 2)* |
| Sembrar datos de demostración | `dart run tool/seed.dart` *(desde la Fase 2)* |
| Reiniciar la demo | `dart run tool/reset_demo.dart` *(desde la Fase 2)* |

Correos de verificación: <http://localhost:8025> (Mailpit). Nada se envía a Internet.

---

## 3. Mapa del repositorio

```
apps/app/            App Flutter (Android + Web). Roles titular, caja y administración.
  lib/brand/         brand.dart: ÚNICO archivo de nombre, colores y logotipo.
  lib/core/          Configuración, cliente de API, tema, rutas, proveedores Riverpod.
  lib/features/      Una carpeta por funcionalidad (home, holder, cashier, admin…).
  lib/card_reader/   CardReader, SimulatedCardReader y el esqueleto NfcMifareCardReader (Fase 4).
api/                 API en Dart (shelf). bin/server.dart arranca; lib/src/ contiene todo.
  lib/src/http/      Middlewares (CORS, errores, auth, idempotencia) y respuestas JSON.
  lib/src/modules/   Un módulo por agregado: auth, cards, transactions, replacements, terminals, admin.
  test/              Unitarias y de integración (contra PostgreSQL real en Docker).
packages/core/       Dart puro compartido: errores, DTOs, Luhn, montos, firma de tarjeta.
db/migrations/       SQL versionado NNNN_descripcion.sql. Nunca se edita uno ya aplicado.
db/seed/             Datos de demostración.
deploy/              Producción en Contabo (solo preparado, NO se ejecuta).
docs/                Documentación en español. docs/adr/ = decisiones técnicas.
tool/                Scripts multiplataforma en Dart (up, down, check, doctor…).
.github/             CI, plantillas de issue y de pull request, instrucciones de Copilot.
```

---

## 4. Invariantes que ninguna IA puede romper

> **Si un cambio toca cualquiera de estas reglas, DETENTE y pregunta al humano antes de continuar.** No las "simplifiques", no las desactives para que una prueba pase y no las muevas solo a la app.

1. **Dinero en centavos y entero.** `BIGINT` en la base, `int` en Dart. **Prohibido `double`** (o `num`, `NUMERIC`, `REAL`, `MONEY`) para dinero en cualquier capa. `tool/check.dart` incluye una guardia automática.
2. **Recarga:** solo múltiplos de $5 (500 centavos) y mayores que cero.
3. **Débito:** mayor que cero y menor o igual al saldo; **sin sobregiro**. Los débitos mayores de $25 (`PIN_REQUIRED_ABOVE_CENTS`, configurable) exigen el PIN del titular.
4. **Atomicidad:** toda operación que cambia saldo corre en una transacción de PostgreSQL: `SELECT ... FOR UPDATE` de la tarjeta → actualizar saldo → insertar movimiento, todo dentro de la misma transacción.
5. **Idempotencia:** toda operación que cambia saldo exige el encabezado `Idempotency-Key` (UUID generado por el cliente). Si se repite, se devuelve el resultado original sin volver a aplicar. La clave es **única en la base**.
6. **Última barrera en la base:** `CHECK (balance_cents >= 0)`. La tabla `transactions` es de **solo inserción**: el usuario de la API no tiene `UPDATE` ni `DELETE` sobre ella, y además un trigger lo impide.
7. **Invariante contable:** el saldo de cada tarjeta es igual a la suma de sus movimientos. Existe una vista de conciliación y un endpoint de administración que la muestra.
8. **Estados de tarjeta:** `PENDING`, `ACTIVE`, `BLOCKED`, `REPLACED`. Solo una tarjeta `ACTIVE` recibe recargas o débitos.
9. **Número de tarjeta:** 16 dígitos aleatorios con dígito verificador Luhn y prefijo configurable (`CARD_NUMBER_PREFIX`). Único; se regenera si choca.
10. **Firma de tarjeta:** UID de 7 bytes (hex) y firma `HMAC-SHA256(CARD_MASTER_KEY, número + UID)` truncada a 16 bytes. Toda operación de caja valida número, UID y firma. **La llave maestra solo vive en el servidor.**
11. **Pérdida y reposición:** reportar pérdida exige confirmar identidad con un código por correo y bloquea la tarjeta de inmediato (`BLOCKED`). La reposición crea la tarjeta nueva, traslada el saldo, marca la anterior `REPLACED` y registra auditoría **en una sola transacción**; si algo falla, se revierte todo.
12. **Sin operación sin conexión:** toda operación que cambia saldo exige la API. La app solo puede cachear el último saldo para mostrarlo, marcado como "no actualizado".

Seguridad mínima que también es invariante: JWT de corta duración, credencial por terminal, **roles validados en la API** (no solo en la app), secretos solo en `.env`, CORS limitado, límite de intentos de PIN y códigos, y **modo demo desactivado por defecto**.

---

## 5. Convenciones

### Idioma
- Documentación, mensajes al usuario y comentarios `///` **en español**.
- Identificadores (clases, funciones, tablas, columnas, rutas, JSON) **en inglés**. El glosario de `docs/domain.md` los relaciona.

### Código Dart
- Estilo: `dart format` y las reglas de `analysis_options.yaml`. **Cero advertencias.**
- Toda clase, función o constante pública lleva un comentario `///`.
- Archivos `snake_case.dart`; clases `PascalCase`; miembros `camelCase`.
- Variables de dinero terminan en `Cents` (`amountCents`, `balanceCents`) y son `int`.
- Lógica de negocio pura (validaciones, Luhn, montos) en `packages/core`; la API la vuelve a ejecutar siempre.
- App: estado con **Riverpod** (sin generación de código), navegación con **go_router**, Material 3. Una carpeta por funcionalidad en `lib/features/`.
- La app nunca muestra textos de error del servidor como lógica: decide por `ApiErrorCode`.

### Base de datos
- Tablas en plural `snake_case` (`cards`, `transactions`); columnas `snake_case`.
- Dinero: `*_cents BIGINT`. Fechas: `*_at TIMESTAMPTZ` en UTC. Identificadores: `UUID`.
- Migraciones `db/migrations/NNNN_descripcion.sql` (4 dígitos, en orden). **Una migración aplicada nunca se edita: se crea otra.**

### API
- Rutas de negocio bajo `/v1/...` (`/health` queda fuera). Sustantivos en plural y `kebab-case`.
- JSON en `camelCase`. Montos como enteros en centavos (`"amountCents": 735`). Fechas ISO-8601 UTC.
- Operaciones que cambian saldo: `POST` con `Idempotency-Key` obligatorio.
- Respuesta exitosa: el recurso directamente. Respuesta de error, siempre:
  ```json
  {"error": {"code": "INSUFFICIENT_FUNDS", "message": "Saldo insuficiente.", "details": {}}}
  ```
  Los códigos viven en `ApiErrorCode` (`packages/core`) y se documentan en `docs/api.md` y `docs/openapi.yaml`.
- Nunca se devuelven trazas, SQL ni secretos al cliente; el detalle va al log del servidor.

### Errores
- Errores de negocio esperados → `ApiError` con su código y HTTP adecuado (400, 401, 403, 404, 409, 422, 429).
- Errores inesperados → `500 INTERNAL_ERROR` (middleware `handleErrors`).

### Git
- Ramas `feat/...`, `fix/...`, `docs/...`, `chore/...` desde `main` (protegida). Conventional Commits. Detalle en `CONTRIBUTING.md`.

---

## 6. Cómo agregar una funcionalidad de principio a fin

1. **Migración** nueva en `db/migrations/` (si cambia el esquema) + permisos para `monedero_app`.
2. **`packages/core`**: modelos, DTOs, validaciones y sus pruebas unitarias.
3. **API**: módulo en `api/lib/src/modules/`, ruta, autorización por rol, transacción si toca saldo.
4. **Pruebas** de la API (integración contra PostgreSQL real), incluidos los casos de error.
5. **App**: pantalla en `lib/features/`, proveedores Riverpod, pruebas de widgets.
6. **Documentación**: `docs/api.md`, `docs/openapi.yaml`, `docs/database.md`, `docs/domain.md` según aplique.
7. **ADR** en `docs/adr/` si tomaste una decisión técnica (formato: contexto, decisión, consecuencias).

---

## 7. Definición de terminado

Una tarea está terminada solo si:

- [ ] `dart run tool/check.dart` termina en verde (formato, análisis **sin advertencias**, guardia de dinero y todas las pruebas).
- [ ] Ninguna prueba fue desactivada, saltada (`skip`) o debilitada para que pase.
- [ ] La documentación y `docs/openapi.yaml` reflejan el cambio.
- [ ] Hay entrada en `CHANGELOG.md` (sección *Sin publicar*).
- [ ] Hay entrada en `docs/BITACORA.md`.
- [ ] Si hubo decisión técnica, existe su ADR.

---

## 8. Protocolo de traspaso entre personas e IA

**Al empezar una sesión:**
1. Lee este `AGENTS.md` completo.
2. Lee `docs/ROADMAP.md`.
3. Lee las **últimas 3 entradas** de `docs/BITACORA.md`.
4. Corre `dart run tool/doctor.dart` y `dart run tool/check.dart` para conocer el estado real.

**Al terminar una sesión**, agrega una entrada al **inicio** de `docs/BITACORA.md` con:
- fecha, integrante y IA usada;
- qué se hizo;
- qué quedó pendiente;
- problemas conocidos.

Y actualiza la sección 9 de este archivo.

---

## 9. Estado actual y siguientes pasos

**Estado actual** (2026-10-21, Fase 1):
- Monorepo con pub workspaces (`packages/core`, `api`, `apps/app`).
- API mínima: `GET /health`, CORS limitado, formato de errores estándar.
- App con marca centralizada, Material 3 claro/oscuro y verificación de conexión con la API.
- Docker Compose con PostgreSQL 17.11, Mailpit y la API. Scripts `tool/` (up, down, doctor, check).
- Documentación base, ADR 0001–0007, plantillas de GitHub y CI.

**Siguientes pasos** (Fase 2 — base de datos y API):
1. Migrador propio con checksums + migraciones iniciales, roles `monedero_owner`/`monedero_app`, trigger de solo inserción y vista de conciliación.
2. `core`: Luhn, validación de montos, firma HMAC y DTOs.
3. API: autenticación (JWT), tarjetas, recarga y débito idempotentes con `FOR UPDATE`, pérdida, reposición, terminales y conciliación.
4. Las 5 pruebas obligatorias de diseño (ver `docs/testing.md`).
5. `tool/migrate.dart`, `tool/seed.dart`, `tool/reset_demo.dart`.

---

## 10. Responsables por área

| Área | Responsable | Respaldo |
|---|---|---|
| Base de datos y migraciones | _por definir_ | _por definir_ |
| API | _por definir_ | _por definir_ |
| `packages/core` | _por definir_ | _por definir_ |
| App: titular | _por definir_ | _por definir_ |
| App: caja y simulación de tarjetas | _por definir_ | _por definir_ |
| App: administración web | _por definir_ | _por definir_ |
| Pruebas y calidad | _por definir_ | _por definir_ |
| Documentación e informe académico | _por definir_ | _por definir_ |
| Despliegue (Contabo) y respaldos | _por definir_ | _por definir_ |

Integrantes (6): Kevin Alexander González Calderón, Cesar Rodrigo Cerón Cruz, David Alexis Navarrete Gálvez (`dn223`), Leonardo, Bayron y Steven (`sm224m`) *(apellidos por completar)*. Kevin usa la cuenta `PatoPsicko`.

---

## 11. Lo que una IA NO debe hacer

- ❌ Subir secretos o archivos `.env` reales (solo `.env.example` con marcadores).
- ❌ Cambiar el identificador del paquete (`sv.edu.ufg.monedero`) ni el `applicationId`.
- ❌ Usar `double` (o `num`/`NUMERIC`/`REAL`/`MONEY`) para dinero.
- ❌ Desactivar, saltar o debilitar pruebas para que pasen.
- ❌ Ejecutar despliegues, contratar servicios o gastar dinero.
- ❌ Reescribir migraciones ya aplicadas en lugar de crear nuevas.
- ❌ Mover una regla de la sección 4 solo a la app o quitarla de la base.
- ❌ Activar el modo demo en la configuración de producción.
- ❌ Inventar números de versión: verifica en pub.dev / Docker Hub y regístralos en `docs/setup.md`.
