-- 0006: anulación por contramovimiento, tarjeta nueva pedida por el titular
-- y cambio de correo (observaciones del ingeniero, ver docs/adr/0016).
--
-- Los movimientos siguen siendo de solo inserción (regla 6): anular NO edita
-- ni borra el original; inserta un contramovimiento REVERSAL_IN o
-- REVERSAL_OUT y deja la auditoría en `reversals`.

-- Nuevos tipos de movimiento ------------------------------------------------
ALTER TABLE transactions DROP CONSTRAINT transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check
  CHECK (type IN ('TOP_UP', 'DEBIT', 'REPLACEMENT_OUT', 'REPLACEMENT_IN',
                  'REVERSAL_IN', 'REVERSAL_OUT'));

-- Auditoría de anulaciones: cada movimiento se anula una sola vez -----------
CREATE TABLE reversals (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_transaction_id  UUID        NOT NULL UNIQUE REFERENCES transactions (id),
  reversal_transaction_id  UUID        NOT NULL UNIQUE REFERENCES transactions (id),
  reason                   TEXT        NOT NULL CHECK (length(trim(reason)) >= 5),
  idempotency_key          TEXT        NOT NULL UNIQUE,
  performed_by             UUID        NOT NULL REFERENCES staff_users (id),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Regla 7: la conciliación suma también los contramovimientos ---------------
CREATE OR REPLACE VIEW card_reconciliation AS
SELECT c.id                                   AS card_id,
       c.number,
       c.status,
       c.balance_cents,
       COALESCE(SUM(CASE WHEN t.type IN ('TOP_UP', 'REPLACEMENT_IN', 'REVERSAL_IN')
                         THEN t.amount_cents ELSE -t.amount_cents END), 0)::BIGINT
                                              AS ledger_cents,
       c.balance_cents
         - COALESCE(SUM(CASE WHEN t.type IN ('TOP_UP', 'REPLACEMENT_IN', 'REVERSAL_IN')
                             THEN t.amount_cents ELSE -t.amount_cents END), 0)::BIGINT
                                              AS difference_cents,
       COUNT(t.id)                            AS transaction_count
FROM cards c
LEFT JOIN transactions t ON t.card_id = c.id
GROUP BY c.id;

-- Tarjeta nueva pedida por el titular (sin pérdida) ---------------------------
ALTER TABLE replacements ALTER COLUMN performed_by DROP NOT NULL;
ALTER TABLE replacements ADD COLUMN requested_by UUID REFERENCES cardholders (id);
ALTER TABLE replacements ADD CONSTRAINT replacements_actor_check
  CHECK (performed_by IS NOT NULL OR requested_by IS NOT NULL);
ALTER TABLE replacements ADD CONSTRAINT replacements_reason_check
  CHECK (reason IN ('LOST', 'REQUESTED'));

-- Códigos para pedir tarjeta nueva y para cambiar el correo -------------------
ALTER TABLE verification_codes DROP CONSTRAINT verification_codes_purpose_check;
ALTER TABLE verification_codes ADD CONSTRAINT verification_codes_purpose_check
  CHECK (purpose IN ('VERIFY_EMAIL', 'REPORT_LOSS', 'REQUEST_CARD', 'CHANGE_EMAIL'));
-- Correo nuevo que se confirmará con el código (solo para CHANGE_EMAIL).
ALTER TABLE verification_codes ADD COLUMN new_email CITEXT;

-- Módulos nuevos (encendidos por defecto) -------------------------------------
INSERT INTO app_modules (key) VALUES ('transaction_reversal'), ('card_transfer');

GRANT SELECT, INSERT ON reversals TO monedero_app;
