# ADR 0001: PostgreSQL como base de datos en lugar de Firestore

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

El sistema guarda saldos de clientes. Necesita: transacciones ACID que cubran varias filas (tarjeta + movimiento, o dos tarjetas en una reposición), bloqueo de fila para serializar débitos concurrentes, restricciones declarativas (`CHECK`, `UNIQUE`), permisos por usuario a nivel de tabla, triggers, consultas de conciliación con `SUM` y respaldos con restauración a un punto en el tiempo. Además el proyecto debe costar $0 en la demo y poco en producción, sin depender de un proveedor.

Opciones: **Firestore** (Firebase) y **PostgreSQL**.

Firestore ofrece transacciones, pero con reintentos optimistas, límites por documento y sin restricciones declarativas como `CHECK (balance_cents >= 0)`; las reglas de seguridad no sustituyen a una restricción en la base; la conciliación con agregaciones es limitada y cobra por lectura; y el respaldo continuo con restauración a un punto en el tiempo depende del plan. También ata el proyecto a Google Cloud.

## Decisión

Usar **PostgreSQL 17** como única fuente de verdad del saldo, accedido solo desde la API.

## Consecuencias

- ✅ `SELECT … FOR UPDATE`, `CHECK`, `UNIQUE`, triggers y `GRANT` implementan las reglas 4 a 7 en la propia base.
- ✅ Corre gratis en Docker y en un VPS barato; respaldo continuo con pgBackRest.
- ✅ SQL estándar, fácil de explicar en el informe académico.
- ⚠️ Hay que operar el servidor (actualizaciones, respaldos, monitoreo), documentado en `deploy-contabo.md`.
- ⚠️ No hay sincronización en tiempo real "gratis" como en Firestore; tampoco se necesita: no se permite operar sin conexión (regla 12).
