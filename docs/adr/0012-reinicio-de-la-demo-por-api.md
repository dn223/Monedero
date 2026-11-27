# ADR 0012: Reinicio de la demo desde la API con el dueño del esquema, solo en modo demo

- **Estado:** Aceptado
- **Fecha:** 2026-10-25
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

Durante la exposición hay que poder volver a los datos de demostración con un botón ("Reiniciar demo" en administración), sin abrir una consola en la laptop. Reiniciar implica borrar movimientos, pero el usuario de la API (`monedero_app`) no tiene `DELETE` sobre `transactions` y un trigger impide borrarlos o vaciarlos (invariante 6). Ese candado no debe aflojarse.

Opciones evaluadas: una función `SECURITY DEFINER` que desactive el trigger (quedaría también en producción y daría a la API una forma de borrar el libro), dar más permisos a `monedero_app` (rompe la invariante) o que la API abra, solo en modo demo, una conexión con el dueño del esquema, igual que hace `tool/reset_demo.dart`.

## Decisión

`POST /v1/admin/demo/reset` (rol administrador) usa `DemoResetService`, que solo existe si `DEMO_MODE=true` **y** la API recibe `POSTGRES_OWNER_PASSWORD`. Abre una conexión con el dueño, borra el esquema, migra y siembra, exactamente como `tool/reset_demo.dart`. Con `DEMO_MODE=false` la ruta responde `DEMO_MODE_DISABLED`; si falta la contraseña del dueño, responde que el reinicio por API no está configurado. Las migraciones viajan dentro de la imagen de la API (`/app/db/migrations`).

## Consecuencias

- El candado de la base sobre `transactions` no cambia: la API sigue sin poder borrar movimientos con su propio usuario.
- En la demo, la API conoce la contraseña del dueño (ya estaba en su entorno porque `docker-compose.yml` le pasa todo `.env`). En producción **no** se le debe pasar `POSTGRES_OWNER_PASSWORD` y el modo demo está apagado.
- Al reiniciar, las sesiones abiertas dejan de servir (los usuarios se vuelven a crear); la app cierra las sesiones de ese navegador y los demás dispositivos vuelven a iniciar sesión.
