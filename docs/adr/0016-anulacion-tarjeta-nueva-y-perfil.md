# ADR 0016: Anulación por contramovimiento, tarjeta nueva pedida por el titular y perfil

- **Estado:** Aceptado
- **Fecha:** 2026-11-18
- **Autores:** David Navarrete · Claude Code

## Contexto

El ingeniero pidió tres funciones nuevas:

1. **Anulación de transacciones.**
2. Un **módulo de transferencia** del dinero de una tarjeta a otra cuando el usuario quiere una tarjeta nueva.
3. Un **apartado para editar los datos del usuario**, por ejemplo el PIN de la tarjeta.

La anulación toca las reglas del dinero: los movimientos son de **solo inserción** (regla 6), porque el usuario de la API no tiene `UPDATE` ni `DELETE` y un trigger lo impide. Además, el saldo siempre debe ser igual a la suma de los movimientos (regla 7). Por eso el equipo decidió (2026-11-18):

- Solo **administración** anula, con un motivo obligatorio.
- La transferencia es una **tarjeta nueva pedida por el titular** desde la app, confirmada con un código por correo.
- El perfil permite cambiar nombre, contraseña, correo y PIN.
- Anulación y transferencia son **módulos activables** ([ADR 0014](0014-modulos-activables-y-asistente.md)).

## Decisión

- **Anulación = contramovimiento.** Anular nunca edita ni borra el movimiento original. En una transacción con `SELECT … FOR UPDATE` de la tarjeta se inserta un movimiento nuevo:
  - `REVERSAL_IN` para un cobro: devuelve el dinero.
  - `REVERSAL_OUT` para una recarga: retira el dinero.
  
  Se ajusta el saldo y se registra la auditoría en `reversals`.
- **Reglas de la anulación:**
  - Solo recargas y cobros; no reposiciones ni otras anulaciones.
  - Cada movimiento una sola vez (`UNIQUE (original_transaction_id)`).
  - Con `Idempotency-Key` propia.
  - Tarjeta `ACTIVE` o `BLOCKED`. Una tarjeta `PENDING` no tiene movimientos, y en una `REPLACED` el saldo ya se trasladó.
  - Anular una recarga **nunca** deja saldo negativo (regla 3): si el titular ya gastó ese dinero, se rechaza con `INSUFFICIENT_FUNDS`.
- **La conciliación** (`card_reconciliation`) suma `REVERSAL_IN` y resta `REVERSAL_OUT`, así la regla 7 se sigue cumpliendo.
- **Tarjeta nueva pedida por el titular:** reutiliza la reposición (regla 11), con la misma transacción única. La diferencia es que la tarjeta debe estar `ACTIVE`, se confirma con un código (`REQUEST_CARD`) y se registra `replacements.requested_by` con `reason = REQUESTED`. La tarjeta nueva nace `ACTIVE` porque la identidad ya se confirmó.
- **Perfil:** nombre, contraseña (pide la actual), correo (el código va al **correo nuevo** y se guarda en `verification_codes.new_email`) y PIN (sin cambios, módulo `pin_change`). Una contraseña actual incorrecta responde `400` y no `401`, para que la app no cierre la sesión.
- **Migración nueva** `0006`. Ninguna migración aplicada se editó.

## Consecuencias

- ✅ El historial sigue siendo inalterable y auditable: se ve el movimiento original, su anulación y el motivo.
- ✅ La conciliación sigue en cero. Las pruebas de integración lo verifican después de anular y de pedir tarjeta nueva.
- ✅ Administración puede apagar la anulación o la tarjeta nueva sin desplegar nada.
- ⚠️ No existen las anulaciones parciales: se anula el monto completo. Si hace falta una devolución parcial, se registra como recarga.
- ⚠️ Cambiar la contraseña no revoca las otras sesiones abiertas (tokens de renovación). Queda pendiente para producción.
- ⚠️ Una anulación no se puede "desanular". Si fue un error, se registra un movimiento nuevo (recarga o cobro).
