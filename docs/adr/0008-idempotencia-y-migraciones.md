# ADR 0008: Semántica de idempotencia, migrador propio y sembrado en Dart

- **Estado:** Aceptado
- **Fecha:** 2026-10-22
- **Autores:** David Navarrete · Claude Code (con ideas del plan de Kevin)

## Contexto

Las reglas 5 y 6 exigen que una operación repetida no se aplique dos veces y que las migraciones aplicadas no se reescriban. Hay que definir qué pasa con claves repetidas con otro contenido, con operaciones rechazadas y con reposiciones (que generan dos movimientos). Además, los datos de demostración necesitan hashes bcrypt y firmas HMAC con la llave del servidor, que no se pueden escribir en SQL puro.

## Decisión

- **Idempotencia:**
  - La clave vive en `transactions.idempotency_key` y `replacements.idempotency_key`, ambas `UNIQUE`.
  - Se verifica **después** de bloquear la tarjeta (`FOR UPDATE`), así dos envíos simultáneos de la misma clave se serializan; si chocan en tarjetas distintas, el `UNIQUE` de la base decide.
  - Misma clave y mismo contenido → comprobante original. Misma clave con otro contenido → `422 IDEMPOTENCY_KEY_REUSED`.
  - Una operación **rechazada no consume** la clave (no se inserta nada). Idea tomada del plan de Kevin.
  - La reposición guarda su clave en `replacements` y deriva `<clave>:out` y `<clave>:in` para sus dos movimientos.
- **Migrador propio** (`api/lib/src/db/migrator.dart`): aplica `db/migrations/NNNN_*.sql` en orden con el dueño del esquema, registra un **checksum SHA-256** y se detiene si una migración aplicada cambió. También crea el rol `monedero_app` con su contraseña del `.env`.
- **Sembrado en Dart** (`api/lib/src/seed.dart`), idempotente; los saldos iniciales son recargas reales en el libro.

## Consecuencias

- ✅ Reintentos seguros desde la app y la caja; probado con 5 envíos en serie y en paralelo.
- ✅ "No reescribir migraciones" deja de depender de la disciplina: el migrador lo impide.
- ⚠️ El dueño del esquema en Docker es superusuario de PostgreSQL (así lo crea la imagen oficial); en producción se usará un dueño sin superusuario (Fase 6).
- ⚠️ No hay renovación de tokens (refresh) todavía: el JWT dura 15 minutos y luego se inicia sesión otra vez. Queda en el roadmap.
