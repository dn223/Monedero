# ADR 0011: Exposición por link público: web servida por la API y quick tunnel de Cloudflare

- **Estado:** Aceptado
- **Fecha:** 2026-10-25
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

El ingeniero debe poder probar la demo completa desde su propia computadora o celular, sin estar frente a la laptop del equipo. Restricciones: costo cero, sin crear cuentas y sin desplegar en Contabo (eso cuesta y requiere aprobación del equipo, Fase 8). Además, la cámara del navegador (escanear QR) solo funciona en un origen seguro (`https` o `localhost`), y los códigos de verificación llegan a Mailpit, que solo se ve en la laptop.

Opciones evaluadas: ngrok (requiere cuenta), Tailscale Funnel (requiere cuenta), desplegar en un hosting gratuito (requiere cuenta y otra base de datos) y el *quick tunnel* de Cloudflare (`trycloudflare.com`), que no pide cuenta.

## Decisión

1. **Un solo origen.** La API sirve el build web de Flutter (`WEB_DIR`, montado desde `apps/app/build`) en `/`; las rutas `/v1/...` y `/health` siguen siendo la API. Un solo link abre la app y llama a la API sin CORS. La web publicada usa su propio origen como servidor (`AppConfig.apiBaseUrl` en modo release).
2. **Túnel en Docker.** Servicio `tunnel` con la imagen `cloudflare/cloudflared` en el perfil `compartir` de `docker-compose.yml` (no se instala nada en Windows). `dart run tool/share.dart` compila la web, levanta todo, siembra e imprime el link `https://….trycloudflare.com` con un QR en la consola. `dart run tool/down.dart` lo detiene.
3. **Demo sin Mailpit.** Solo con `DEMO_MODE=true`, la API devuelve en la respuesta los códigos de verificación y de pérdida (`demoCode`) y guarda en memoria los últimos correos (`GET /v1/demo/inbox`, solo los del titular autenticado). La app los muestra en pantalla.
4. **APK sin recompilar.** La app guarda la URL del servidor en el dispositivo (pantalla "Servidor"): se pega o se escanea el QR del link.

## Consecuencias

- Costo cero y sin cuentas; la demo funciona en cualquier red con Internet y la cámara funciona porque el link es `https`.
- El link es **público y temporal**: cualquiera que lo tenga entra a la demo, y en modo demo hay cuentas y códigos visibles. Se levanta solo para la exposición y se detiene al terminar. Los límites de solicitudes (ADR 0010) frenan abusos.
- El link cambia cada vez que se recrea el túnel; Cloudflare no garantiza disponibilidad de los quick tunnels (son para pruebas). Si falla, el plan B es la red local (`http://<IP>:8080`) o la PC del equipo.
- `demoCode` y el buzón nunca existen con `DEMO_MODE=false`; en producción los códigos solo viajan por correo.
- Producción (Fase 8) reemplaza todo esto por dominio propio, HTTPS con Caddy y SMTP real.
