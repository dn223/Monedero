# Changelog

Todos los cambios notables de este proyecto se documentan aquÃ­.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

### Agregado â€” Fase 3 (vistas de diseÃ±o)
- Vistas de titular (`/titular`), caja (`/caja`) y administraciÃ³n (`/admin`) con datos de ejemplo, en el estilo de la app; botones de rol habilitados en la pantalla inicial.
- Fases reordenadas: 4 conecta titular y caja, 5 conecta administraciÃ³n, 6 Android, pulido y despliegue.
- PresentaciÃ³n (`docs/presentacion.pdf`) y guÃ­a del proyecto para el equipo (`docs/guia-del-proyecto.pdf`).

### Agregado â€” Fase 2 (base de datos y API)
- `core`: `Money` (recarga mÃºltiplo de $5, formato USD, parseo sin `double`), `CardNumber` (Luhn y generaciÃ³n con prefijo), `CardSignature` (UID simulado y HMAC-SHA256 truncado), `CardStatus`, `TransactionType`, `Role` y nuevos `ApiErrorCode`.
- MigraciÃ³n `0001_initial_schema.sql`: titulares, personal, terminales, tarjetas, movimientos de solo inserciÃ³n (permisos + trigger), reposiciones, cÃ³digos de verificaciÃ³n y vista `card_reconciliation`.
- Migrador con checksum (`api/bin/migrate.dart`) y scripts `tool/migrate.dart`, `tool/seed.dart`, `tool/reset_demo.dart`; `tool/up.dart` ahora migra y siembra.
- API: autenticaciÃ³n con JWT por rol, registro y verificaciÃ³n por correo (Mailpit), terminales con credencial, emisiÃ³n y entrega, recarga y cobro idempotentes con `SELECT â€¦ FOR UPDATE` y PIN sobre $25 con lÃ­mite de intentos, reporte de pÃ©rdida con cÃ³digo, reposiciÃ³n atÃ³mica, conciliaciÃ³n, bÃºsquedas y lista de tarjetas demo.
- Pruebas de integraciÃ³n contra PostgreSQL real, incluidas las 5 obligatorias (1,000 cobros concurrentes, idempotencia, reposiciÃ³n con falla forzada, movimientos inalterables y firma invÃ¡lida).
- `tool/demo.dart`: recorre los 8 pasos de la demo contra la API real.
- CI con servicio PostgreSQL para las pruebas de integraciÃ³n.
- ADR 0008: semÃ¡ntica de idempotencia, migrador y sembrado.

### Agregado â€” Fase 1
- Monorepo con pub workspaces: `packages/core`, `api` y `apps/app`.
- `packages/core`: `ApiError`, `ApiErrorCode` y `HealthStatus` compartidos.
- API (`shelf` + `shelf_router`): `GET /health`, CORS limitado a orÃ­genes configurados, formato estÃ¡ndar de errores y manejo de excepciones sin filtrar detalles.
- App Flutter (Android + Web): archivo Ãºnico de marca (`brand.dart`), temas Material 3 claro y oscuro, go_router, Riverpod y pantalla inicial con estado de la API.
- Identificador Android neutral `sv.edu.ufg.monedero`.
- Docker Compose con PostgreSQL 17.11, Mailpit v1.31.6 y la API (imagen `scratch` con ejecutable nativo).
- Scripts multiplataforma: `tool/up.dart`, `tool/down.dart`, `tool/doctor.dart` y `tool/check.dart` (con guardia contra `double` para dinero).
- `.env.example` con generaciÃ³n automÃ¡tica de secretos al crear `.env`.
- DocumentaciÃ³n base: `AGENTS.md`, guÃ­as de setup, arquitectura, dominio, API/OpenAPI, base de datos, pruebas, demo, NFC y despliegue; ADR 0001â€“0007; `NAMING.md`.
- GitHub: CI (anÃ¡lisis, formato, pruebas y construcciÃ³n de la imagen), plantillas de pull request y de propuesta de nombre.
- Capturas de la pantalla inicial en tema claro y oscuro (`docs/img/`).
