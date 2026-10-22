# API de Monedero

Especificación formal: [openapi.yaml](openapi.yaml) (OpenAPI 3.1). Este documento explica las convenciones y lista los endpoints.

- URL local: `http://localhost:8080` (emulador Android: `http://10.0.2.2:8080`).
- Producción: `https://<dominio>` detrás de Caddy (ver `deploy-contabo.md`).

## 1. Convenciones

| Tema | Regla |
|---|---|
| Rutas | Negocio bajo `/v1/...`; `GET /health` fuera de versión. Plural y `kebab-case` |
| Formato | JSON UTF-8, claves en `camelCase` |
| Dinero | Enteros en centavos con sufijo `Cents` (`"amountCents": 735` = $7.35). Nunca decimales |
| Fechas | ISO-8601 en UTC (`2026-10-21T22:15:00Z`) |
| Autenticación | `Authorization: Bearer <JWT>` de corta duración (`JWT_TTL_MINUTES`, 15 por defecto) |
| Terminal | Operaciones de caja: además `X-Terminal-Token: <credencial del terminal>` |
| Idempotencia | Toda operación que cambia saldo: `Idempotency-Key: <UUID v4>` **obligatorio** |
| CORS | Solo los orígenes de `CORS_ALLOWED_ORIGINS` (la app web en `http://localhost:5000`) |

### Idempotencia
- El cliente genera un UUID v4 **por intención de operación** y lo reutiliza en cada reintento de esa misma operación.
- Si la clave ya existe con el **mismo** contenido, la API responde el resultado original (mismo cuerpo) sin aplicar nada.
- Si la clave existe con **otro** contenido (otro monto o tarjeta), responde `422 IDEMPOTENCY_KEY_REUSED`.
- Sin el encabezado, responde `400 IDEMPOTENCY_KEY_REQUIRED`.

### Formato de error
Siempre el mismo cuerpo:
```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Saldo insuficiente.",
    "details": {"balanceCents": 1265, "amountCents": 5000}
  }
}
```
La app decide qué mostrar por `code`, nunca por `message`. `details` es opcional y nunca contiene secretos.

## 2. Códigos de error

| Código | HTTP | Cuándo | Estado |
|---|---|---|---|
| `VALIDATION_FAILED` | 400 | Cuerpo o parámetros inválidos | Implementado |
| `UNAUTHORIZED` | 401 | Sin token o token vencido | Implementado (código) |
| `FORBIDDEN` | 403 | El rol no permite la operación | Implementado (código) |
| `NOT_FOUND` | 404 | Ruta o recurso inexistente | Implementado |
| `CONFLICT` | 409 | Conflicto con el estado del recurso | Implementado (código) |
| `TOO_MANY_ATTEMPTS` | 429 | Límite de intentos de PIN o código | Implementado (código) |
| `INTERNAL_ERROR` | 500 | Error inesperado (sin detalles internos) | Implementado |
| `IDEMPOTENCY_KEY_REQUIRED` | 400 | Falta `Idempotency-Key` | Fase 2 |
| `IDEMPOTENCY_KEY_REUSED` | 422 | Clave reutilizada con otro contenido | Fase 2 |
| `INVALID_AMOUNT` | 422 | Monto ≤ 0 o recarga no múltiplo de $5 | Fase 2 |
| `INSUFFICIENT_FUNDS` | 422 | Débito mayor que el saldo | Fase 2 |
| `CARD_NOT_ACTIVE` | 409 | Tarjeta `PENDING`, `BLOCKED` o `REPLACED` | Fase 2 |
| `INVALID_CARD_SIGNATURE` | 422 | Número, UID o firma no coinciden | Fase 2 |
| `PIN_REQUIRED` | 422 | Débito mayor al límite sin PIN | Fase 2 |
| `INVALID_PIN` | 422 | PIN incorrecto | Fase 2 |
| `INVALID_VERIFICATION_CODE` | 422 | Código de correo incorrecto o vencido | Fase 2 |
| `TERMINAL_NOT_AUTHORIZED` | 403 | Terminal desconocido o revocado | Fase 2 |
| `DEMO_MODE_DISABLED` | 403 | Endpoint de demo con `DEMO_MODE=false` | Fase 2 |

## 3. Endpoints

### Implementados

| Método | Ruta | Rol | Descripción |
|---|---|---|---|
| `GET` | `/health` | público | Estado de la API, versión y si el modo demo está activo |

Ejemplo:
```bash
curl http://localhost:8080/health
```
```json
{"status":"ok","version":"0.1.0","demoMode":true}
```

### Planificados (Fase 2)

Pueden ajustarse al implementarse; `openapi.yaml` es la referencia final.

| Método | Ruta | Rol | Descripción |
|---|---|---|---|
| `POST` | `/v1/auth/cardholders/register` | público | Registro del titular; envía código por correo |
| `POST` | `/v1/auth/cardholders/verify-email` | público | Confirma el correo con el código |
| `POST` | `/v1/auth/cardholders/login` | público | Inicio de sesión del titular → JWT |
| `POST` | `/v1/auth/staff/login` | público | Inicio de sesión de cajero/administrador → JWT |
| `GET` | `/v1/me/cards` | titular | Tarjetas del titular con saldo |
| `GET` | `/v1/me/cards/{cardId}/transactions` | titular | Historial de movimientos |
| `PUT` | `/v1/me/pin` | titular | Cambiar PIN (pide el PIN actual) |
| `POST` | `/v1/me/cards/{cardId}/loss-reports` | titular | Inicia el reporte de pérdida (envía código) |
| `POST` | `/v1/me/cards/{cardId}/loss-reports/confirm` | titular | Confirma con el código → `BLOCKED` |
| `POST` | `/v1/me/cards/{cardId}/replacement-requests` | titular | Solicita reposición |
| `POST` | `/v1/terminals/register` | cajero | Registra el terminal con un código de alta → credencial |
| `POST` | `/v1/cards/read` | cajero + terminal | Valida número, UID y firma; devuelve titular y estado |
| `POST` | `/v1/cards/{cardNumber}/top-ups` | cajero + terminal | Recarga (idempotente) |
| `POST` | `/v1/cards/{cardNumber}/debits` | cajero + terminal | Cobro (idempotente, PIN si > $25) |
| `POST` | `/v1/admin/cards` | administrador | Emitir tarjeta para un titular (`PENDING`) |
| `POST` | `/v1/admin/cards/{cardId}/deliver` | administrador | Entregar → `ACTIVE` |
| `POST` | `/v1/admin/cards/{cardId}/replace` | administrador | Ejecutar la reposición (transacción única) |
| `GET` | `/v1/admin/cardholders?q=` | administrador | Buscar titulares |
| `GET` | `/v1/admin/cards?q=` | administrador | Buscar tarjetas |
| `GET` | `/v1/admin/transactions` | administrador | Movimientos con filtros |
| `GET` | `/v1/admin/reconciliation` | administrador | Saldo frente a suma de movimientos por tarjeta |
| `GET` / `POST` / `DELETE` | `/v1/admin/terminals` | administrador | Gestionar terminales |
| `GET` | `/v1/demo/cards` | cajero (solo modo demo) | Lista de tarjetas de demostración |
| `POST` | `/v1/demo/reset` | administrador (solo modo demo) | Reiniciar la demo |
