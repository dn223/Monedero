# Changelog

Todos los cambios notables de este proyecto se documentan aquí.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

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
