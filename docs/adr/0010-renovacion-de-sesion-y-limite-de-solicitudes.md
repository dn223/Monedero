# ADR 0010: Renovación de sesión con tokens rotativos y límite de solicitudes en memoria

- **Estado:** Aceptado
- **Fecha:** 2026-10-25
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

El JWT dura 15 minutos (invariante de seguridad: "JWT de corta duración"). Sin renovación, una persona que deja la caja abierta 20 minutos tenía que volver a escribir su contraseña, y durante una exposición eso corta la demo. Además la API no tenía ningún freno contra muchas solicitudes seguidas (fuerza bruta de contraseñas, abuso del link público).

Opciones evaluadas para la sesión: alargar el JWT (rompe la invariante), guardar la contraseña en la app (inaceptable) o un token de renovación. Para el límite: un proxy delante (Caddy o Cloudflare con reglas, que requieren cuenta o despliegue), una tabla en PostgreSQL o contadores en memoria.

## Decisión

1. **Token de renovación rotativo.** Cada inicio de sesión entrega, además del JWT, un `refreshToken` aleatorio de 32 bytes. En la base solo queda su SHA-256 (`refresh_tokens`, migración `0003`), con vencimiento de 7 días (`REFRESH_TOKEN_TTL_DAYS`). `POST /v1/auth/refresh` revoca el token usado y entrega un par nuevo (rotación): un token robado sirve una sola vez. `POST /v1/auth/logout` lo revoca. Si el personal fue desactivado, la renovación falla.
2. **La app renueva sola.** `SessionNotifier.run` agrega el JWT a cada llamada; si vence o la API responde `UNAUTHORIZED`, renueva una vez (una sola renovación en curso aunque haya varias llamadas) y reintenta con la misma `Idempotency-Key`. Si otra pestaña del mismo rol ya renovó, adopta la sesión guardada.
3. **Límite de solicitudes en memoria**, por cliente y por minuto, solo en `/v1/...`: 600 en general y 30 en inicio de sesión, registro, renovación y sesiones demo (`RATE_LIMIT_PER_MINUTE`, `RATE_LIMIT_AUTH_PER_MINUTE`). Al pasarse responde `429 RATE_LIMITED` con `Retry-After`. Detrás del túnel todas las solicitudes llegan desde el contenedor `cloudflared`, así que con `RATE_LIMIT_TRUST_PROXY=true` el cliente se identifica por `CF-Connecting-IP`.

## Consecuencias

- La sesión dura días sin debilitar el JWT de 15 minutos, y cerrar sesión de verdad invalida el acceso.
- Se descartó la detección de reutilización que revoca toda la familia de tokens: con varias pestañas del mismo rol en el mismo navegador cerraba sesiones legítimas. Queda como mejora si se pasa a cookies `HttpOnly`.
- En la web los tokens viven en `localStorage` (vía `shared_preferences`). Es aceptable para el prototipo; en producción conviene una cookie `HttpOnly` para el token de renovación.
- Los contadores se pierden al reiniciar la API y no se comparten entre réplicas. Con una sola instancia (la demo y el VPS previsto) basta; con varias habría que moverlos a PostgreSQL o Redis.
- `RATE_LIMIT_TRUST_PROXY=true` sin un proxy delante permite falsificar el encabezado y saltarse el límite; en producción solo se activa detrás de un proxy confiable.
