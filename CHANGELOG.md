# Changelog

Todos los cambios notables de este proyecto se documentan aquí.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

### Agregado — Observaciones del ingeniero: módulos
- Módulos de la aplicación que administración enciende o apaga en **Administración → Módulos**: asistente virtual, registro de titulares, pago con código de caja, QR de la tarjeta y cambio de PIN (migración `0004_app_modules.sql`, `AppModule` en `core`, ADR 0014).
- La API hace cumplir cada módulo con `403 MODULE_DISABLED`; cada cambio queda en `module_changes` con quién y cuándo. `GET /v1/modules` (público) y `PUT /v1/admin/modules/{key}`.
- Asistente virtual (chatbot) del titular por reglas, sin servicios externos: responde saldo y último movimiento reales, recargas, pagos, PIN, pérdida y reposición (`POST /v1/assistant/messages`).
- La app del titular oculta las funciones apagadas y lo nota en 5 segundos sin recargar.
- Versión 0.7.0.

### Agregado — Fase 6 (Android instalable y exposición por link)
- APK release firmado con un keystore propio fuera del repositorio (`~/.monedero/`), con firma de depuración como respaldo (ADR 0013).
- Ícono propio para Android y web, generado desde `brand.dart` (`apps/app/tool/icons/generate_icons_test.dart`).
- Web instalable (PWA): manifiesto completo, pantalla de carga y metadatos en español.
- La API sirve el build web en el mismo origen (`WEB_DIR`); `dart run tool/share.dart` levanta todo con un quick tunnel de Cloudflare (perfil `compartir`, imagen `cloudflare/cloudflared:2026.9.3`) e imprime el link público con su QR (ADR 0011).
- La app guarda la URL del servidor (pantalla "Servidor": pegar o escanear el link) sin recompilar.
- `tool/up.dart` y `tool/share.dart` agregan a `.env` las variables nuevas de `.env.example`; `tool/down.dart` también detiene el túnel.
- Guías `docs/exposicion.md` y `docs/android.md`; guion de demo desde la app y capturas en el README.
- Documento de la presentación del avance (`docs/monedero-doc.pdf`) actualizado a las fases 1 a 6; su fuente queda versionada en `docs/presentacion/monedero-doc.html`.
- Presentación de entrada de 6 diapositivas (incluye módulos y asistente) con el estilo de la app (`docs/presentacion-intro.pdf`, fuente en `docs/presentacion/intro-slides.html`), para abrir la exposición antes de mostrar el sistema.

### Agregado — Fase 5 (administración y endurecimiento)
- Administración conectada: tablero (saldo en circulación, tarjetas por estado, conciliación y gráfico de recargas y cobros de 14 días con vista de tabla), tarjetas (buscar, entregar, reponer, movimientos), titulares (emitir y entregar), cajas (crear con QR de vínculo, revocar) y reiniciar la demo.
- API: tokens de renovación rotativos (migración `0003_refresh_tokens.sql`, `POST /v1/auth/refresh` y `/logout`), límite de solicitudes por minuto (`RATE_LIMITED`), `GET /v1/admin/stats` y `POST /v1/admin/demo/reset` (ADR 0010 y 0012).

### Agregado — Fase 4 (titular y caja conectados)
- Inicio de sesión real de los tres roles, con una sesión guardada por rol y renovación automática.
- Titular: registro con verificación de correo, tarjeta virtual con saldo (caché "no actualizado" sin conexión), movimientos, QR real, pago con código de caja, cambio de PIN, reporte de pérdida y buzón de correos en modo demo.
- Caja: vínculo del dispositivo con la credencial de terminal (o caja demo propia), `CardReader`/`SimulatedCardReader` (QR con cámara, lista demo, número), cobro con PIN, recarga y comprobante tipo ticket; `NfcMifareCardReader` como esqueleto para la Fase 7.
- `core`: `QrPayloads` (QR de tarjeta, vínculo de caja y URL del servidor) y el código `RATE_LIMITED`.
- API: códigos de verificación y de pérdida en pantalla y buzón solo con `DEMO_MODE=true`, `POST /v1/auth/cardholders/resend-code`, `GET /v1/cards/terminal`, `POST /v1/demo/terminals`, `GET /v1/demo/inbox`; la búsqueda de titulares incluye su tarjeta vigente. `docs/openapi.yaml` documenta además las rutas de pago con código de caja que faltaban.

### Cambiado
- Versión 0.6.0 de la app y de la API.
- Las vistas de diseño de la Fase 3 (`features/preview`) se reemplazaron por las pantallas reales.
- Las pruebas de integración usan una base por archivo y corren de a una (`api/dart_test.yaml`).

### Corregido
- `CHANGELOG.md` tenía doble codificación UTF-8 (acentos ilegibles).

### Agregado — Fase 3 (vistas de diseño)
- Vistas de titular (`/titular`), caja (`/caja`) y administración (`/admin`) con datos de ejemplo, en el estilo de la app; botones de rol habilitados en la pantalla inicial.
- Fases reordenadas: 4 conecta titular y caja, 5 conecta administración, 6 Android, pulido y despliegue.
- Presentación (`docs/presentacion.pdf`) y guía del proyecto para el equipo (`docs/guia-del-proyecto.pdf`).

### Agregado — Fase 2 (base de datos y API)
- `core`: `Money` (recarga múltiplo de $5, formato USD, parseo sin `double`), `CardNumber` (Luhn y generación con prefijo), `CardSignature` (UID simulado y HMAC-SHA256 truncado), `CardStatus`, `TransactionType`, `Role` y nuevos `ApiErrorCode`.
- Migración `0001_initial_schema.sql`: titulares, personal, terminales, tarjetas, movimientos de solo inserción (permisos + trigger), reposiciones, códigos de verificación y vista `card_reconciliation`.
- Migrador con checksum (`api/bin/migrate.dart`) y scripts `tool/migrate.dart`, `tool/seed.dart`, `tool/reset_demo.dart`; `tool/up.dart` ahora migra y siembra.
- API: autenticación con JWT por rol, registro y verificación por correo (Mailpit), terminales con credencial, emisión y entrega, recarga y cobro idempotentes con `SELECT … FOR UPDATE` y PIN sobre $25 con límite de intentos, reporte de pérdida con código, reposición atómica, conciliación, búsquedas y lista de tarjetas demo.
- Pruebas de integración contra PostgreSQL real, incluidas las 5 obligatorias (1,000 cobros concurrentes, idempotencia, reposición con falla forzada, movimientos inalterables y firma inválida).
- `tool/demo.dart`: recorre los 8 pasos de la demo contra la API real.
- CI con servicio PostgreSQL para las pruebas de integración.
- ADR 0008: semántica de idempotencia, migrador y sembrado.

### Agregado — Fase 1
- Monorepo con pub workspaces: `packages/core`, `api` y `apps/app`.
- `packages/core`: `ApiError`, `ApiErrorCode` y `HealthStatus` compartidos.
- API (`shelf` + `shelf_router`): `GET /health`, CORS limitado a orígenes configurados, formato estándar de errores y manejo de excepciones sin filtrar detalles.
- App Flutter (Android + Web): archivo único de marca (`brand.dart`), temas Material 3 claro y oscuro, go_router, Riverpod y pantalla inicial con estado de la API.
- Identificador Android neutral `sv.edu.ufg.monedero`.
- Docker Compose con PostgreSQL 17.11, Mailpit v1.31.6 y la API (imagen `scratch` con ejecutable nativo).
- Scripts multiplataforma: `tool/up.dart`, `tool/down.dart`, `tool/doctor.dart` y `tool/check.dart` (con guardia contra `double` para dinero).
- `.env.example` con generación automática de secretos al crear `.env`.
- Documentación base: `AGENTS.md`, guías de setup, arquitectura, dominio, API/OpenAPI, base de datos, pruebas, demo, NFC y despliegue; ADR 0001–0007; `NAMING.md`.
- GitHub: CI (análisis, formato, pruebas y construcción de la imagen), plantillas de pull request y de propuesta de nombre.
- Capturas de la pantalla inicial en tema claro y oscuro (`docs/img/`).
