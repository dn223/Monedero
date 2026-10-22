## Qué cambia

<!-- Resumen en 1–3 frases. Enlaza el issue si existe: "Cierra #N". -->

## Por qué

<!-- Problema que resuelve o funcionalidad que agrega. -->

## Cómo probarlo

<!-- Pasos concretos: comandos, pantallas, datos de prueba. -->

1. `dart run tool/up.dart`
2. …

## Invariantes de dinero (AGENTS.md § 4)

- [ ] Este PR **no** toca dinero, saldos, movimientos ni permisos de la base, **o**
- [ ] Sí los toca y se consultó al equipo antes; se explica abajo:

<!-- Explicación si aplica. -->

## Definición de terminado (AGENTS.md § 7)

- [ ] `dart run tool/check.dart` en verde (formato, análisis sin advertencias, guardia de dinero y pruebas).
- [ ] No se desactivó, saltó ni debilitó ninguna prueba.
- [ ] Pruebas nuevas para lo nuevo.
- [ ] Documentación actualizada (`docs/`, `docs/openapi.yaml` si cambia la API).
- [ ] Entrada en `CHANGELOG.md` (*Sin publicar*).
- [ ] Entrada en `docs/BITACORA.md`.
- [ ] ADR nuevo si hubo una decisión técnica.
- [ ] No se subieron secretos ni archivos `.env`.

## IA utilizada

<!-- Ej. Claude Code, Codex, Cursor, Copilot, Gemini, ninguna. -->
