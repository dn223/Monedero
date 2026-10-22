# API de Monedero

Especificación formal: [openapi.yaml](openapi.yaml) (OpenAPI 3.1). Este documento explica las convenciones y lista los endpoints.

- URL local: `http://localhost:8080` (emulador Android: `http://10.0.2.2:8080`).
- Producción: `https://<dominio>` detrás de Caddy (ver `deploy-contabo.md`).
- La forma más rápida de verla funcionar: `dart run tool/demo.dart` (recorre los 8 pasos de la demo).

## 1. Convenciones

| Tema | Regla |
|---|---|
| Rutas | Negocio bajo `/v1/...`; `GET /health` fuera de versión |
| Formato | JSON UTF-8, claves en `camelCase` |
| Dinero | Enteros en centavos con sufijo `Cents` (`"amountCents": 735` = $7.35). Un decimal (`7.35`) se rechaza con `VALIDATION_FAILED` |
| Fechas | ISO-8601 en UTC |
| Autenticación | `Authorization: Bearer <JWT>` HS256 de 15 minutos (`JWT_TTL_MINUTES`) |
| Terminal | Operaciones de caja: además `X-Terminal-Token: <credencial del terminal>` |
| Idempotencia | Recargas, cobros y reposiciones: `Idempotency-Key: <UUID>` **obligatorio** |
| Tarjeta | La caja envía `card: {number, uid, signature}` en el **cuerpo** (no en la URL, para que el número no quede en logs) |
| CORS | Solo los orígenes de `CORS_ALLOWED_ORIGINS` |

### Idempotencia (regla 5)
- El cliente genera un UUID por intención de operación y lo reutiliza en cada reintento.
- Clave repetida con el **mismo** contenido (tarjeta, tipo y monto): responde el comprobante original, sin aplicar nada.
- Clave repetida con **otro** contenido: `422 IDEMPOTENCY_KEY_REUSED`.
- Una operación **rechazada** (saldo insuficiente, PIN incorrecto…) **no consume** la clave.
- La unicidad la garantiza la base (`UNIQUE (idempotency_key)`); dos envíos simultáneos con la misma clave se resuelven en una sola operación.

### Formato de error
```json
{"error": {"code": "INSUFFICIENT_FUNDS", "message": "Saldo insuficiente.", "details": {"balanceCents": 1265, "amountCents": 1500}}}
```
La app decide por `code`, nunca por `message`.

## 2. Códigos de error

| Código | HTTP | Cuándo |
|---|---|---|
| `VALIDATION_FAILED` | 400 | Cuerpo o parámetros inválidos |
| `UNAUTHORIZED` | 401 | Sin token o token vencido |
| `INVALID_CREDENTIALS` | 401 | Correo/contraseña incorrectos o correo sin verificar |
| `FORBIDDEN` | 403 | El rol no permite la operación |
| `TERMINAL_NOT_AUTHORIZED` | 403 | Terminal ausente, desconocido o revocado |
| `DEMO_MODE_DISABLED` | 403 | Endpoint de demo con `DEMO_MODE=false` |
| `NOT_FOUND` | 404 | Ruta o recurso inexistente |
| `CONFLICT` | 409 | Conflicto de estado (correo ya registrado, tarjeta no entregable…) |
| `CARD_NOT_ACTIVE` | 409 | Tarjeta `PENDING`, `BLOCKED` o `REPLACED` |
| `IDEMPOTENCY_KEY_REQUIRED` | 400 | Falta `Idempotency-Key` o no es UUID |
| `IDEMPOTENCY_KEY_REUSED` | 422 | Clave reutilizada con otro contenido |
| `INVALID_AMOUNT` | 422 | Monto ≤ 0 o recarga que no es múltiplo de $5 |
| `INSUFFICIENT_FUNDS` | 422 | Cobro mayor que el saldo |
| `INVALID_CARD_SIGNATURE` | 422 | Número, UID o firma no coinciden |
| `PIN_REQUIRED` | 422 | Cobro mayor de $25 sin PIN |
| `INVALID_PIN` | 422 | PIN incorrecto (`details.attemptsLeft`) |
| `INVALID_VERIFICATION_CODE` | 422 | Código de correo incorrecto o vencido |
| `TOO_MANY_ATTEMPTS` | 429 | PIN bloqueado 15 min (3 fallos) o código con 5 intentos |
| `INTERNAL_ERROR` | 500 | Error inesperado (sin detalles internos) |

## 3. Endpoints

| Método | Ruta | Rol | Descripción |
|---|---|---|---|
| `GET` | `/health` | público | Estado, versión y modo demo |
| `POST` | `/v1/auth/cardholders/register` | público | Registro `{fullName, email, password, pin}`; envía código |
| `POST` | `/v1/auth/cardholders/verify-email` | público | `{email, code}` |
| `POST` | `/v1/auth/cardholders/login` | público | `{email, password}` → JWT |
| `POST` | `/v1/auth/staff/login` | público | Cajero/administrador → JWT |
| `GET` | `/v1/me/cards` | titular | Tarjetas con saldo y `credentials` (contenido del QR) |
| `GET` | `/v1/me/cards/{id}/transactions` | titular | Historial |
| `POST` | `/v1/me/cards/{id}/loss-reports` | titular | Envía código de confirmación |
| `POST` | `/v1/me/cards/{id}/loss-reports/confirm` | titular | `{code}` → `BLOCKED` |
| `PUT` | `/v1/me/pin` | titular | `{currentPin, newPin}` |
| `POST` | `/v1/cards/read` | cajero + terminal | `{card}` → titular, estado y saldo |
| `POST` | `/v1/cards/top-ups` | cajero + terminal | `{card, amountCents}` + `Idempotency-Key` |
| `POST` | `/v1/cards/debits` | cajero + terminal | `{card, amountCents, pin?}` + `Idempotency-Key` |
| `GET` | `/v1/admin/cardholders?q=` | admin | Buscar titulares |
| `GET` | `/v1/admin/cards?q=` | admin | Buscar tarjetas |
| `POST` | `/v1/admin/cards` | admin | `{cardholderId}` → tarjeta `PENDING` |
| `POST` | `/v1/admin/cards/{id}/deliver` | admin | `PENDING` → `ACTIVE` |
| `POST` | `/v1/admin/cards/{id}/replace` | admin | Reposición (transacción única) + `Idempotency-Key` |
| `GET` | `/v1/admin/cards/{id}/transactions` | admin | Movimientos de una tarjeta |
| `GET` | `/v1/admin/reconciliation` | admin | Saldo vs. suma de movimientos |
| `GET` / `POST` | `/v1/admin/terminals` | admin | Listar / registrar (la credencial se muestra una sola vez) |
| `DELETE` | `/v1/admin/terminals/{id}` | admin | Revocar |
| `GET` | `/v1/demo/cards` | cajero (modo demo) | Tarjetas activas para elegir en caja |

Reiniciar la demo: `dart run tool/reset_demo.dart` (requiere `DEMO_MODE=true`; el botón de la app llega en la Fase 5).

## 4. Ejemplo: cobro de $7.35

```http
POST /v1/cards/debits
Authorization: Bearer eyJ...
X-Terminal-Token: 3f9c...
Idempotency-Key: 3b241101-e2bb-4255-8caf-4136c566a962
Content-Type: application/json

{"card": {"number": "9990142405712970", "uid": "2C0C8C5A3E42A3", "signature": "B42149E136746651633E81491192A81D"}, "amountCents": 735}
```
```json
201 {"transactionId": "…", "type": "DEBIT", "amountCents": 735, "balanceAfterCents": 1265, "cardNumberMasked": "•••• 2970", "createdAt": "2026-10-22T16:50:00.000Z"}
```
