-- 0004: módulos de la aplicación que administración activa o desactiva.
-- La API consulta esta tabla antes de cada operación de un módulo: si está
-- apagado responde MODULE_DISABLED aunque la app aún muestre el botón.
-- Nombres y descripciones viven en el código (AppModule en packages/core);
-- aquí solo queda el estado y quién lo cambió por última vez.
CREATE TABLE app_modules (
  key         TEXT PRIMARY KEY CHECK (key ~ '^[a-z][a-z_]*$'),
  enabled     BOOLEAN     NOT NULL DEFAULT true,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID REFERENCES staff_users (id) ON DELETE SET NULL
);

-- Bitácora de cambios: solo inserción, igual que los movimientos.
CREATE TABLE module_changes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_key  TEXT        NOT NULL REFERENCES app_modules (key),
  enabled     BOOLEAN     NOT NULL,
  changed_by  UUID        NOT NULL REFERENCES staff_users (id),
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX module_changes_module_idx ON module_changes (module_key, changed_at DESC);

INSERT INTO app_modules (key) VALUES
  ('assistant'),
  ('self_registration'),
  ('holder_payments'),
  ('card_qr'),
  ('pin_change');

GRANT SELECT, UPDATE ON app_modules TO monedero_app;
GRANT SELECT, INSERT ON module_changes TO monedero_app;
