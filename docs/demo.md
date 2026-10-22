# Guion de demostración (10 minutos)

> Estado: **Fase 2**. Los 8 pasos ya se pueden demostrar contra la API real con `dart run tool/demo.dart`. Las pantallas de la app (titular, caja y administración) llegan en las fases 3 a 5; el guion final con capturas se completa en la Fase 6.

## Preparación (5 minutos antes)

1. Abrir Docker Desktop y esperar "Engine running".
2. Desde la raíz del repositorio:
   ```bash
   dart run tool/up.dart
   ```
   Levanta PostgreSQL, Mailpit y la API, aplica migraciones y siembra los usuarios de prueba.
3. Opcional, para empezar con datos limpios:
   ```bash
   dart run tool/reset_demo.dart
   ```
4. Abrir en el navegador <http://localhost:8025> (Mailpit) y dejar una consola grande lista.

## Usuarios de prueba

| Rol | Usuario | Contraseña | PIN |
|---|---|---|---|
| Administrador | `admin@monedero.local` | `Admin1234` | — |
| Cajero | `cajero@monedero.local` | `Cajero1234` | — |
| Titular (Ana, $50.00) | `ana@demo.local` | `Titular1234` | `1234` |
| Titular (Bruno, $15.00) | `bruno@demo.local` | `Titular1234` | `1234` |

El script de demo crea además un titular nuevo en cada corrida.

## Guion

```bash
dart run tool/demo.dart --pausa
```
Con `--pausa` espera Enter entre pasos, para explicar cada uno.

| Min | Paso | Qué mostrar | Resultado esperado |
|---|---|---|---|
| 0:00 | Contexto | Diagrama de `docs/architecture.md`: app → API → PostgreSQL; tres capas de defensa | — |
| 1:00 | 1. Registrar un titular | El código llega a **Mailpit** (mostrar la pestaña) | Correo verificado |
| 2:00 | 2. Emitir una tarjeta virtual | Número Luhn, UID simulado y firma HMAC; `PENDING` → `ACTIVE` | Tarjeta activa |
| 3:00 | 3. Recargar $20 | Comprobante | Saldo $20.00 |
| 3:30 | 4. Cobrar $7.35 | Comprobante | Saldo $12.65 |
| 4:00 | 5. Sobregiro de $15.00 | Rechazo | `INSUFFICIENT_FUNDS`; saldo intacto |
| 4:30 | Extra: idempotencia | 5 envíos con la misma clave | Solo suma $5 una vez |
| 5:00 | Extra: tarjeta falsificada | UID cambiado | `INVALID_CARD_SIGNATURE` |
| 5:30 | 6. Reportar la pérdida | Segundo código en Mailpit | `BLOCKED`; la caja ya no puede cobrar (`CARD_NOT_ACTIVE`) |
| 6:30 | 7. Reponer la tarjeta | Reposición en una sola transacción | Tarjeta nueva `ACTIVE` con el mismo saldo; anterior `REPLACED` |
| 7:00 | 8. Conciliación | Resumen | **Diferencia total $0.00** |
| 7:30 | Calidad | `cd api` y `dart test` (≈30 s): 1,000 cobros concurrentes, idempotencia, reposición con falla forzada, movimientos inalterables y firma | Todo en verde |
| 9:00 | Cierre | `docs/ROADMAP.md`: app (fases 3–5), NFC y Contabo | — |

## Si algo falla en vivo

| Problema | Acción rápida |
|---|---|
| `No se pudo iniciar sesión` | Falta sembrar: `dart run tool/seed.dart` |
| La API no responde | `dart run tool/up.dart`; ver `docker compose logs api` |
| Datos raros de un ensayo anterior | `dart run tool/reset_demo.dart` |
| Docker apagado | Abrir Docker Desktop y repetir `dart run tool/up.dart` |
