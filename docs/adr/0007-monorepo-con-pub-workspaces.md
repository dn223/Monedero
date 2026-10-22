# ADR 0007: Monorepo con pub workspaces

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

La app y la API comparten modelos, errores y validaciones (`packages/core`). Con repositorios separados o dependencias `path` sueltas, cada paquete resuelve sus propias versiones y es fácil que diverjan. Dart 3.6+ ofrece **pub workspaces**: un `pubspec.yaml` raíz con `workspace:`, un único `pubspec.lock` y resolución compartida.

## Decisión

- Un solo repositorio con los miembros `packages/core`, `api` y `apps/app`, declarados en el `pubspec.yaml` raíz; cada miembro usa `resolution: workspace`.
- La raíz también contiene los scripts de `tool/`, escritos en Dart puro (`dart:io`) para que funcionen igual en Windows y macOS.
- Se instala todo con `flutter pub get` desde la raíz (hace falta Flutter porque `apps/app` es miembro).
- **Compilación de la API en Docker:** la imagen `dart` no trae Flutter, así que `api/Dockerfile` quita la línea `- apps/app` del `pubspec.yaml` raíz dentro de la imagen y resuelve solo `api` y `packages/core`.

## Consecuencias

- ✅ Un solo `pubspec.lock`: app y API usan exactamente las mismas versiones de `core` y de sus dependencias comunes.
- ✅ Un cambio en `core` se prueba contra la app y la API en el mismo pull request.
- ⚠️ Flutter fija algunas versiones (por ejemplo `test_api`), lo que limita la versión de `test` en los paquetes de Dart puro (hoy `test` 1.31.1). Se revisa al actualizar Flutter.
- ⚠️ Si se agrega otro miembro Flutter, hay que quitarlo también en `api/Dockerfile`.
