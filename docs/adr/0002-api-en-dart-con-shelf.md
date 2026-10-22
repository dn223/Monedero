# ADR 0002: API en Dart con `shelf` + `shelf_router` (no Dart Frog)

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

La API se escribe en **Dart** para compartir modelos y validaciones con la app Flutter mediante `packages/core` y para que el equipo use un solo lenguaje. El encargo pedía usar **Dart Frog** si seguía mantenido y, si no, `shelf` + `shelf_router`.

Verificación del 2026-10-21:

| | Dart Frog | shelf / shelf_router |
|---|---|---|
| Publicador | `dart-frog.dev` (comunitario; antes Very Good Ventures) | `tools.dart.dev` (equipo de Dart) |
| Última versión | `dart_frog` 1.2.6, hace ~11 meses; CLI 1.2.14 en marzo de 2026 | `shelf` 1.4.3 y `shelf_router` 1.1.5, publicadas el 2026-10-16 |
| Actividad reciente | Mayoría de commits automáticos (dependencias, CI); último commit en julio de 2026 | Mantenido junto al SDK |
| Workspaces / monorepo | Soporte agregado en 2025, pero sigue abierto el issue #1947: `dart_frog build` no maneja paquetes con rutas relativas (nuestro caso con `packages/core`) | Funciona con pub workspaces sin pasos extra |
| Generación de código | Rutas por archivos, con servidor generado | Ninguna; las rutas se declaran en código |

Dart Frog se basa en `shelf`, así que no aporta capacidades que necesitemos y sí agrega una herramienta, generación de código y un riesgo concreto de compilación en Docker.

## Decisión

Usar **`shelf` + `shelf_router`**, con el servidor compilado a ejecutable nativo (`dart compile exe`) dentro de una imagen `scratch`.

## Consecuencias

- ✅ Paquetes mantenidos por el equipo de Dart; menos dependencias.
- ✅ Sin generación de código: cualquier IA o persona ve todas las rutas en `api/lib/src/app.dart` y los módulos.
- ✅ Imagen de producción pequeña y sin shell.
- ⚠️ Middlewares (autenticación, idempotencia, CORS) y la organización por módulos se escriben a mano, lo que exige disciplina (ver `AGENTS.md`).
- 🔁 Si Dart Frog retoma un desarrollo activo y cierra el issue de rutas relativas, se puede reevaluar en un ADR nuevo; migrar es posible porque también usa `shelf`.
