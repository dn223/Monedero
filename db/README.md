# Base de datos

- `migrations/`: SQL versionado `NNNN_descripcion.sql` (4 dígitos). Se aplica en orden con `dart run tool/migrate.dart` (Fase 2).
- `seed/`: datos de demostración (Fase 2).

Reglas (detalle en [docs/database.md](../docs/database.md)):

1. **Nunca edites una migración ya aplicada**: crea una nueva. El migrador compara checksums y se detiene si cambió.
2. Dinero siempre `BIGINT` en centavos (`*_cents`). Nada de `NUMERIC`, `REAL`, `FLOAT`, `DOUBLE PRECISION`, `MONEY` ni `DECIMAL`.
3. Cada tabla nueva otorga permisos mínimos a `monedero_app`; `transactions` nunca recibe `UPDATE` ni `DELETE`.
