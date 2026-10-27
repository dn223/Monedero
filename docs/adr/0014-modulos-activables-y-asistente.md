# ADR 0014: Módulos activables desde administración y asistente virtual por reglas

- **Estado:** Aceptado
- **Fecha:** 2026-10-27
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

En la revisión del avance, el ingeniero pidió ver que el proyecto "tenga módulos". Lo que quiere es poder encender y apagar partes de la aplicación desde el sistema, por ejemplo un chatbot, de modo que un usuario ya no pueda usar esa función, y que eso lo controle el backend. Monedero no tenía chatbot, y las funciones del titular siempre estaban disponibles.

## Decisión

- **Módulos en la base.** La tabla `app_modules` (migración `0004`) guarda si cada módulo está encendido y quién lo cambió por última vez. `module_changes` registra cada cambio y es de solo inserción. Nombres y descripciones viven en `AppModule` (`packages/core`) para que la API y la app digan lo mismo.
- **La API hace cumplir.** Cada ruta de un módulo llama a `ModuleService.require`: si el módulo está apagado, responde `403 MODULE_DISABLED`. Ocultar el botón en la app es solo comodidad.
- **Primeros cinco módulos, todos del titular:**
  - asistente virtual (`assistant`);
  - registro (`self_registration`);
  - pago con código de caja (`holder_payments`);
  - QR de la tarjeta (`card_qr`): apagado, la API deja de enviar las credenciales que forman el QR;
  - cambio de PIN (`pin_change`).
- **No son módulos:**
  - recargas y cobros en caja, reporte de pérdida y reposición. Apagarlos dejaría a un titular sin poder bloquear una tarjeta perdida o sin acceso a su saldo, y las reglas de la sección 4 de `AGENTS.md` no dependen de un interruptor.
- **Administración → Módulos.** Es una pantalla con un interruptor por módulo, que muestra quién hizo el último cambio. `GET /v1/modules` es público para que la app sepa qué mostrar incluso antes de iniciar sesión. La app del titular vuelve a consultarlo cada 5 segundos, así que un cambio se ve sin recargar la página.
- **Asistente por reglas, sin servicios externos:**
  - Reconoce la intención por palabras clave (sin acentos ni mayúsculas) y responde con el saldo y el último movimiento reales del titular.
  - No sugiere funciones de módulos apagados.
  - No guarda las conversaciones.
  - Un modelo de lenguaje en la nube costaría dinero, exigiría una llave secreta y enviaría datos del titular a un tercero.

## Consecuencias

- Administración puede retirar una función al instante y sin desplegar; el cambio queda auditado.
- Cada módulo nuevo exige tres pasos:
  - agregarlo a `AppModule`;
  - insertarlo con una migración nueva;
  - llamar a `require` en sus rutas.
  La prueba `api/test/integration/modules_test.dart` verifica la lista.
- El asistente solo entiende las preguntas previstas. Si no entiende, responde con lo que sí sabe hacer. Podría cambiarse por un modelo de lenguaje sin tocar la app, porque la ruta sigue siendo la misma.
