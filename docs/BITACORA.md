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
