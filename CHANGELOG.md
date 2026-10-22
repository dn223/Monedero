# Changelog

Todos los cambios notables de este proyecto se documentan aquí.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

### Agregado
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
