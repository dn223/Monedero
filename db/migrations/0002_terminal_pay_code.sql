-- 0002: código corto de caja para que el titular pague desde su app.
-- El titular escribe este código (6 dígitos) para indicar en qué caja paga.
ALTER TABLE terminals
  ADD COLUMN pay_code CHAR(6) UNIQUE CHECK (pay_code ~ '^[0-9]{6}$');
