-- 0003: renovación de sesión con tokens de renovación (refresh) rotativos.
-- El token en claro viaja una sola vez al cliente; aquí solo queda su SHA-256.
-- Cada uso revoca el token y emite uno nuevo (rotación); cerrar sesión lo revoca.
CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Id del titular o del personal (no es llave foránea: puede ser de dos tablas).
  subject_id  UUID        NOT NULL,
  role        TEXT        NOT NULL CHECK (role IN ('CARDHOLDER', 'CASHIER', 'ADMIN')),
  token_hash  TEXT        NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_subject_idx ON refresh_tokens (subject_id);

GRANT SELECT, INSERT, UPDATE ON refresh_tokens TO monedero_app;
