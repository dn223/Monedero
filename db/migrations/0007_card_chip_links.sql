-- Fase 7: tarjetas físicas NFC (NTAG215), ADR 0017.
--
-- Al grabar un chip, la tarjeta adopta el UID real del chip (7 bytes, igual
-- que la regla 10) y su firma se recalcula. Cada vinculación queda registrada
-- aquí; la tabla es de solo inserción para la API.

CREATE TABLE card_chip_links (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id        UUID        NOT NULL REFERENCES cards (id),
  previous_uid   CHAR(14)    NOT NULL CHECK (previous_uid ~ '^[0-9A-F]{14}$'),
  chip_uid       CHAR(14)    NOT NULL CHECK (chip_uid ~ '^[0-9A-F]{14}$'),
  performed_by   UUID        NOT NULL REFERENCES staff_users (id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX card_chip_links_card_idx ON card_chip_links (card_id, created_at DESC);

GRANT SELECT, INSERT ON card_chip_links TO monedero_app;
