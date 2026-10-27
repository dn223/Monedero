# ADR 0015: La caja entra con su código y la base empieza solo con administración

- **Estado:** Aceptado
- **Fecha:** 2026-10-27
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

Para la exposición, el equipo quiere un sistema que se vea real. Pide cuatro cosas:

- que no aparezca la palabra "demo";
- que no haya cuentas de prueba precargadas;
- que haya una sola cuenta de administración;
- que la caja se abra solo con el código que le entrega administración, sin usuario de cajero.

Los titulares se registran desde la app. Tampoco hay correo real todavía, así que el código de verificación debe seguir viéndose en la app.

## Decisión

**Base sin datos de ejemplo.**
- Con `SAMPLE_DATA=false`, que es el valor por defecto, se siembra solo la cuenta de administración (`ADMIN_EMAIL` / `ADMIN_PASSWORD`).
- `tool/up.dart` genera esa contraseña en `.env`; nunca entra al repositorio.
- Con `SAMPLE_DATA=true` se siembran los ejemplos de antes (Ana, Bruno y un cajero). Las pruebas de integración usan esta opción.
- Las sesiones sin contraseña (`/v1/demo/*-session`) solo existen con datos de ejemplo.

**La caja entra con su código.**
- Al crear una caja, administración recibe un código de 12 caracteres (`K7M4-Q2XP-HT9W`, ver `TerminalCode`) que se muestra una sola vez.
- La base solo guarda su SHA-256.
- Al crear la caja se crea también su usuario de personal con rol `CASHIER` (migración `0005`, `terminals.cashier_id`). Nadie conoce la contraseña de ese usuario.
- `POST /v1/auth/terminals/login {code}` devuelve la sesión de ese usuario y la credencial de la caja.
- Revocar la caja desactiva el código y el usuario a la vez, así que la sesión ya no se renueva.

**Sin la palabra "demo" en pantalla.**
- Los códigos de verificación y el buzón siguen visibles en la app, con `DEMO_MODE=true` en el servidor.
- La lista de tarjetas activas de la caja también sigue: reemplaza al lector NFC hasta la Fase 7.
- Se quitaron las cuentas "Entrar como…", "Crear caja de demostración" y el botón "Reiniciar demo". El reinicio sigue disponible con `tool/reset_demo.dart`.

## Consecuencias

**Seguridad:**
- Cada cobro y recarga sigue registrado con su caja y con un usuario, el de la caja.
- La API sigue validando el rol y la credencial de la caja en cada operación (sección 4 de `AGENTS.md`).
- El código de la caja es su credencial. Quien lo tenga opera como esa caja hasta que administración la revoque.
- El límite de solicitudes de inicio de sesión frena los intentos de adivinarlo.

**Exposición:**
- Hay que registrarse para probar.
- El ingeniero puede crear su propia cuenta de titular desde el link, y administración le emite la tarjeta.

**Producción:**
- La Fase 8 cambia los códigos en pantalla por correo real (`DEMO_MODE=false`). Allí la lista de tarjetas de la caja desaparece y se lee la tarjeta por NFC.
