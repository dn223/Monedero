-- 0001: esquema inicial de Monedero.
-- Dinero siempre BIGINT en centavos. Fechas TIMESTAMPTZ (UTC).
-- El rol monedero_app lo crea tool/migrate.dart antes de aplicar migraciones.

CREATE EXTENSION IF NOT EXISTS citext;

-- Titulares --------------------------------------------------------------
CREATE TABLE cardholders (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name            TEXT        NOT NULL CHECK (length(trim(full_name)) > 0),
  email                CITEXT      NOT NULL UNIQUE,
  email_verified_at    TIMESTAMPTZ,
  password_hash        TEXT        NOT NULL,
  pin_hash             TEXT        NOT NULL,
  failed_pin_attempts  INT         NOT NULL DEFAULT 0,
  pin_locked_until     TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Personal (cajeros y administradores) -----------------------------------
CREATE TABLE staff_users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name      TEXT        NOT NULL,
  email          CITEXT      NOT NULL UNIQUE,
  password_hash  TEXT        NOT NULL,
  role           TEXT        NOT NULL CHECK (role IN ('CASHIER', 'ADMIN')),
  active         BOOLEAN     NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Terminales de caja autorizados ------------------------------------------
CREATE TABLE terminals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT        NOT NULL,
  credential_hash  TEXT        NOT NULL UNIQUE,
  active           BOOLEAN     NOT NULL DEFAULT true,
  registered_by    UUID        REFERENCES staff_users (id),
  last_seen_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tarjetas -----------------------------------------------------------------
CREATE TABLE cards (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  number         CHAR(16)    NOT NULL UNIQUE CHECK (number ~ '^[0-9]{16}$'),
  uid            CHAR(14)    NOT NULL UNIQUE CHECK (uid ~ '^[0-9A-F]{14}$'),
  signature      CHAR(32)    NOT NULL,
  cardholder_id  UUID        NOT NULL REFERENCES cardholders (id),
  status         TEXT        NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'ACTIVE', 'BLOCKED', 'REPLACED')),
  -- Regla 6: última barrera contra el sobregiro.
  balance_cents  BIGINT      NOT NULL DEFAULT 0 CHECK (balance_cents >= 0),
  version        BIGINT      NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX cards_cardholder_idx ON cards (cardholder_id);

-- Movimientos (solo inserción) -------------------------------------------
CREATE TABLE transactions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id              UUID        NOT NULL REFERENCES cards (id),
  type                 TEXT        NOT NULL
                       CHECK (type IN ('TOP_UP', 'DEBIT', 'REPLACEMENT_OUT', 'REPLACEMENT_IN')),
  amount_cents         BIGINT      NOT NULL CHECK (amount_cents > 0),
  balance_after_cents  BIGINT      NOT NULL CHECK (balance_after_cents >= 0),
  -- Regla 5: una operación por clave. Las reposiciones usan claves derivadas.
  idempotency_key      TEXT        NOT NULL UNIQUE,
  terminal_id          UUID        REFERENCES terminals (id),
  staff_user_id        UUID        REFERENCES staff_users (id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX transactions_card_idx ON transactions (card_id, created_at);

-- Regla 6: movimientos inalterables, aunque alguien tenga permisos.
CREATE FUNCTION forbid_transaction_changes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'transactions es de solo inserción: % no permitido', TG_OP
    USING ERRCODE = 'insufficient_privilege';
END;
$$;

CREATE TRIGGER transactions_append_only
  BEFORE UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION forbid_transaction_changes();

CREATE TRIGGER transactions_no_truncate
  BEFORE TRUNCATE ON transactions
  FOR EACH STATEMENT EXECUTE FUNCTION forbid_transaction_changes();

-- Auditoría de reposiciones -------------------------------------------------
CREATE TABLE replacements (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  old_card_id        UUID        NOT NULL UNIQUE REFERENCES cards (id),
  new_card_id        UUID        NOT NULL UNIQUE REFERENCES cards (id),
  transferred_cents  BIGINT      NOT NULL CHECK (transferred_cents >= 0),
  idempotency_key    TEXT        NOT NULL UNIQUE,
  performed_by       UUID        NOT NULL REFERENCES staff_users (id),
  reason             TEXT        NOT NULL DEFAULT 'LOST',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Códigos de verificación por correo ---------------------------------------
CREATE TABLE verification_codes (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cardholder_id  UUID        NOT NULL REFERENCES cardholders (id),
  purpose        TEXT        NOT NULL CHECK (purpose IN ('VERIFY_EMAIL', 'REPORT_LOSS')),
  card_id        UUID        REFERENCES cards (id),
  code_hash      TEXT        NOT NULL,
  attempts       INT         NOT NULL DEFAULT 0,
  expires_at     TIMESTAMPTZ NOT NULL,
  consumed_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX verification_codes_lookup_idx
  ON verification_codes (cardholder_id, purpose, created_at DESC);

-- Regla 7: conciliación saldo vs. suma de movimientos ----------------------
CREATE VIEW card_reconciliation AS
SELECT c.id                                   AS card_id,
       c.number,
       c.status,
       c.balance_cents,
       COALESCE(SUM(CASE WHEN t.type IN ('TOP_UP', 'REPLACEMENT_IN')
                         THEN t.amount_cents ELSE -t.amount_cents END), 0)::BIGINT
                                              AS ledger_cents,
       c.balance_cents
         - COALESCE(SUM(CASE WHEN t.type IN ('TOP_UP', 'REPLACEMENT_IN')
                             THEN t.amount_cents ELSE -t.amount_cents END), 0)::BIGINT
                                              AS difference_cents,
       COUNT(t.id)                            AS transaction_count
FROM cards c
LEFT JOIN transactions t ON t.card_id = c.id
GROUP BY c.id;

-- Permisos mínimos para la API ---------------------------------------------
GRANT USAGE ON SCHEMA public TO monedero_app;
GRANT SELECT, INSERT, UPDATE ON cardholders, staff_users, terminals, cards, verification_codes TO monedero_app;
GRANT SELECT, INSERT ON replacements TO monedero_app;
-- Regla 6: sin UPDATE ni DELETE sobre transactions.
GRANT SELECT, INSERT ON transactions TO monedero_app;
GRANT SELECT ON card_reconciliation TO monedero_app;
