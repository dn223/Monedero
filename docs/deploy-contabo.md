# Despliegue en producción (Contabo) — solo preparado

> ⚠️ **No se ejecuta en esta fase.** No contrates el VPS ni el almacenamiento hasta que el equipo lo decida. Los archivos de `deploy/` se completan en la **Fase 6**; este documento ya fija la estructura de la guía.

## Arquitectura de producción

| Pieza | Elección |
|---|---|
| Servidor | VPS de Contabo, plan más barato (Ubuntu LTS) |
| HTTPS | Caddy (certificados automáticos de Let's Encrypt) |
| API | Mismo `api/Dockerfile` que en local |
| Base de datos | PostgreSQL 17 en el mismo VPS, sin exponer el puerto a Internet |
| Respaldos | pgBackRest con archivado continuo de WAL hacia **Backblaze B2** |
| Correo | Proveedor SMTP real (por definir) en lugar de Mailpit |
| Modo demo | **`DEMO_MODE=false` siempre** |

## Contenido previsto de la guía (Fase 6)

1. **Preparar el VPS:** usuario sin root, llaves SSH, desactivar contraseña por SSH, actualizaciones automáticas de seguridad.
2. **Firewall:** solo 22 (SSH, idealmente restringido), 80 y 443. PostgreSQL nunca expuesto.
3. **Docker y Compose** en el VPS.
4. **Dominio y DNS** apuntando al VPS (un subdominio gratuito sirve para la prueba).
5. **Secretos:** `deploy/.env.prod` creado en el servidor a partir de `deploy/.env.prod.example`, con permisos `600`; nunca en el repositorio.
6. **Levantar:** `docker compose -f deploy/docker-compose.prod.yml up -d`.
7. **Caddy:** `deploy/Caddyfile` con el dominio, encabezados de seguridad y proxy a la API.
8. **pgBackRest → Backblaze B2:** bucket privado, llave de aplicación con permisos mínimos, cifrado del repositorio, `archive_command`, respaldo completo semanal e incremental diario.
9. **Restauración:** procedimiento probado de restauración a un punto en el tiempo (PITR) en una máquina aparte. **Un respaldo que no se ha restaurado no cuenta.**
10. **Monitoreo:** `/health` con un monitor externo gratuito, alertas de disco, `pgbackrest check` y revisión de la conciliación.
11. **Actualizaciones:** cómo desplegar una versión nueva y cómo revertir.

## Archivos (Fase 6)

| Archivo | Propósito |
|---|---|
| `deploy/docker-compose.prod.yml` | Caddy, API, PostgreSQL y pgBackRest |
| `deploy/Caddyfile` | HTTPS y proxy inverso |
| `deploy/pgbackrest/pgbackrest.conf.example` | Configuración de ejemplo hacia B2 |
| `deploy/.env.prod.example` | Variables de producción con `DEMO_MODE=false` |
