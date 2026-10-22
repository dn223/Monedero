# Bitácora de sesiones

Registro de cada sesión de trabajo, **la más reciente primero**. Al terminar una sesión, agrega una entrada con la plantilla (ver `AGENTS.md`, sección 8).

```markdown
## AAAA-MM-DD — <integrante> — <IA usada>
**Qué se hizo:**
- …
**Pendiente:**
- …
**Problemas conocidos:**
- …
```

---

## 2026-10-22 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo:**
- Repositorio publicado en GitHub: `dn223/Monedero` (`main` = Fase 1).
- Fase 2 completa en la rama `feat/fase-2-api`: `core` (dinero, Luhn, firma), migración inicial con barreras en la base, migrador con checksum, API completa y sembrado de demo.
- Las 5 pruebas obligatorias pasan contra PostgreSQL real (16 pruebas de API, 15 de `core`).
- `tool/demo.dart` recorre los 8 pasos de la demo con códigos leídos de Mailpit; conciliación en $0.00.

**Pendiente:**
- Fase 3: app del titular. Renovación de tokens (refresh). Botón "Reiniciar demo" vía API (Fase 5).
- Completar apellidos de Leonardo, Bayron y Steven; tabla de responsables.

**Problemas conocidos:**
- `tool/check.dart` ahora necesita Docker levantado (`dart run tool/up.dart`) por las pruebas de integración.
- Con 1,000 operaciones simultáneas sobre la misma tarjeta, las solicitudes esperan conexión del pool; el tiempo de espera es configurable (`openPool(acquireTimeout:)`).

---

## 2026-10-21 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

> Nota: en paralelo, Kevin (con Claude Code, en su equipo) propuso un plan casi idéntico e instaló WSL y Docker, pero no escribió código. Este repositorio es el que tiene la Fase 1 implementada.

**Qué se hizo:**
- Revisión del entorno en Windows 11 Home: instalación de WSL 2 (3.0.3, sin distribución) y Docker Desktop 4.96.2; Flutter actualizado a 3.47.7.
- Decisión de usar `shelf` + `shelf_router` en lugar de Dart Frog (ADR 0002).
- Fase 1: monorepo con pub workspaces (`packages/core`, `api`, `apps/app`), API mínima con `GET /health`, CORS y formato de errores; app con marca centralizada, Material 3 claro/oscuro y comprobación de la API.
- Docker Compose (PostgreSQL 17.11, Mailpit v1.31.6, API) y scripts `tool/` (`up`, `down`, `doctor`, `check` con guardia de dinero).
- Documentación base, ADR 0001–0007, `NAMING.md`, plantillas de GitHub y CI.

**Pendiente:**
- Aprobación de la Fase 1 por el equipo.
- Crear el repositorio en GitHub, subirlo y proteger `main`.
- Fase 2: base de datos, `core` y API con las 5 pruebas obligatorias.

**Problemas conocidos:**
- En PowerShell 5.1, al redirigir la salida de los scripts a un archivo, los acentos pueden verse mal; en la consola o en Windows Terminal se ven bien.
- `test` queda en 1.31.1 porque Flutter 3.47.7 fija `test_api` 0.7.12.
