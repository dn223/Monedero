# Base de datos

PostgreSQL **17** (`postgres:17.11` en Docker). Es la **única fuente de verdad del saldo**.

> Estado: **diseño**. Las migraciones se implementan en la Fase 2; este documento se actualizará con el esquema real.

## 1. Modelo entidad-relación (diseño)

```mermaid
erDiagram
  cardholders ||--o{ cards : "posee"
  cards ||--o{ transactions : "registra"
  terminals ||--o{ transactions : "origina"
  staff_users ||--o{ transactions : "opera"
  cards ||--o| replacements : "repuesta (anterior)"
  cards ||--o| replacements : "nueva"
  staff_users ||--o{ replacements : "ejecuta"
  staff_users ||--o{ terminals : "registra"

  cardholders {
    uuid id PK
    text full_name
    citext email UK
    timestamptz email_verified_at
    text password_hash "Argon2id o bcrypt"
    text pin_hash "Argon2id o bcrypt"
    int failed_pin_attempts
    timestamptz pin_locked_until
    timestamptz created_at
  }
  cards {
    uuid id PK
    char16 number UK "16 dígitos, Luhn"
    char14 uid UK "7 bytes hex"
    char32 signature "HMAC truncado, hex"
    uuid cardholder_id FK
    text status "PENDING|ACTIVE|BLOCKED|REPLACED"
    bigint balance_cents "CHECK >= 0"
    bigint version
    timestamptz created_at
    timestamptz updated_at
  }
  transactions {
    uuid id PK
    uuid card_id FK
    text type "TOP_UP|DEBIT|REPLACEMENT_OUT|REPLACEMENT_IN"
    bigint amount_cents "CHECK > 0"
    bigint balance_after_cents "CHECK >= 0"
    uuid idempotency_key UK
    uuid terminal_id FK "nulo en reposiciones"
    uuid staff_user_id FK
    timestamptz created_at
  }
  replacements {
    uuid id PK
    uuid old_card_id FK
    uuid new_card_id FK
    bigint transferred_cents
    uuid performed_by FK
    text reason
    timestamptz created_at
  }
  terminals {
    uuid id PK
    text name
    text credential_hash
    boolean active
    uuid registered_by FK
    timestamptz last_seen_at
    timestamptz created_at
  }
  staff_users {
    uuid id PK
    text full_name
    citext email UK
    text password_hash
    text role "CASHIER|ADMIN"
    boolean active
    timestamptz created_at
  }
```

Tablas auxiliares previstas: `verification_codes` (códigos por correo con vencimiento e intentos) e `idempotency_records` si la respuesta original necesita guardarse aparte de `transactions`.

## 2. Barreras en la base

| Barrera | Implementación prevista |
|---|---|
| Saldo nunca negativo | `CHECK (balance_cents >= 0)` en `cards` |
| Montos positivos | `CHECK (amount_cents > 0)` en `transactions` |
| Idempotencia | `UNIQUE (idempotency_key)` en `transactions` |
| Movimientos inalterables | Sin `UPDATE`/`DELETE` para `monedero_app` **y** trigger `BEFORE UPDATE OR DELETE` que lanza excepción |
| Estados válidos | `CHECK (status IN ('PENDING','ACTIVE','BLOCKED','REPLACED'))` |
| Conciliación | Vista `card_reconciliation`: `balance_cents` frente a `SUM(±amount_cents)` por tarjeta y su diferencia |

## 3. Roles y permisos

| Rol de PostgreSQL | Uso | Permisos |
|---|---|---|
| `monedero_owner` | Dueño del esquema; solo migraciones | Todo sobre el esquema `monedero` |
| `monedero_app` | Conexión de la API | `SELECT, INSERT` en `transactions`; `SELECT, INSERT, UPDATE` en el resto; **nunca** `UPDATE`/`DELETE` en `transactions`, ni DDL |

La API **nunca** se conecta con `monedero_owner`. Ambas contraseñas están en `.env` (`POSTGRES_OWNER_PASSWORD`, `POSTGRES_APP_PASSWORD`).

## 4. Migraciones

- Ubicación: `db/migrations/NNNN_descripcion.sql` (4 dígitos, por ejemplo `0001_initial_schema.sql`).
- Se aplican en orden con `dart run tool/migrate.dart` (Fase 2), que registra cada una en `schema_migrations` con su **checksum**.
- **Una migración aplicada nunca se edita.** Si el checksum cambia, el migrador se detiene. Para corregir, se crea una migración nueva.
- Cada migración que crea una tabla también otorga los permisos mínimos a `monedero_app`.
- Sin tipos decimales ni flotantes para dinero: `tool/check.dart` rechaza `NUMERIC`, `REAL`, `FLOAT`, `DOUBLE PRECISION`, `MONEY` y `DECIMAL` en las migraciones.

## 5. Datos de demostración

`db/seed/` contendrá titulares, personal, terminales y tarjetas de demostración (Fase 2). `dart run tool/reset_demo.dart` vacía y vuelve a sembrar la base, y solo funciona con `DEMO_MODE=true`.
