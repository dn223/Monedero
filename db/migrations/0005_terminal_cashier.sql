-- 0005: cada caja entra solo con su código (ver docs/adr/0015).
-- Al crear la caja se crea también su usuario de personal con rol CASHIER
-- (sin contraseña utilizable); la sesión que obtiene la caja con su código
-- es la de ese usuario, así los cobros y recargas quedan registrados con la
-- caja y con su usuario, igual que antes. Revocar la caja desactiva ambos.
ALTER TABLE terminals
  ADD COLUMN cashier_id UUID REFERENCES staff_users (id);
CREATE UNIQUE INDEX terminals_cashier_idx ON terminals (cashier_id);
