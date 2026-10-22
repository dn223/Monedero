# Instrucciones para GitHub Copilot

Lee y sigue **[AGENTS.md](../AGENTS.md)** en la raíz del repositorio: es la fuente única de instrucciones para cualquier IA (comandos, invariantes de negocio, convenciones, definición de terminado y protocolo de traspaso).

Recordatorios críticos (el detalle está en `AGENTS.md`, sección 4):
- Dinero siempre en centavos como `int`/`BIGINT`; nunca `double`.
- Toda operación que cambia saldo: transacción con `SELECT ... FOR UPDATE` e `Idempotency-Key`.
- La tabla `transactions` es de solo inserción.
- Si un cambio toca una de esas reglas, detente y pregunta al humano.
