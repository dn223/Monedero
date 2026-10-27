# Guion de demostración (10 minutos)

> Estado: **Fase 6**. Los 8 pasos se hacen desde la app (web o celular) contra la API real. Para que el ingeniero la pruebe desde su propio equipo, ver [exposicion.md](exposicion.md). `dart run tool/demo.dart` sigue disponible como respaldo por consola.

## Preparación (5 minutos antes)

1. Abrir Docker Desktop y esperar "Engine running".
2. Desde la raíz del repositorio, una de dos:
   - Solo en la laptop: `dart run tool/up.dart` y compilar la web una vez con `cd apps/app && flutter build web` (luego se abre <http://localhost:8080>).
   - Con link público: `dart run tool/share.dart` (compila la web e imprime el link; ver [exposicion.md](exposicion.md)).
3. Para empezar con datos limpios: **Administración → Resumen → Reiniciar demo** (o `dart run tool/reset_demo.dart`).
4. Abrir tres pestañas del mismo navegador: `…/#/titular`, `…/#/caja` y `…/#/admin`. Cada rol guarda su propia sesión, así que las tres conviven.

## Usuarios de prueba

En modo demo la app los muestra en cada pantalla de inicio de sesión ("Entrar como…").

| Rol | Usuario | Contraseña | PIN |
|---|---|---|---|
| Administración | `admin@monedero.local` | `Admin1234` | — |
| Caja | `cajero@monedero.local` | `Cajero1234` | — |
| Titular (Ana, $50.00) | `ana@demo.local` | `Titular1234` | `1234` |
| Titular (Bruno, $15.00) | `bruno@demo.local` | `Titular1234` | `1234` |

## Guion

| Min | Paso | Dónde, en la app | Resultado esperado |
|---|---|---|---|
| 0:00 | Contexto | Pantalla inicial: tres roles y servidor conectado | — |
| 1:00 | 1. Registrar un titular | Titular → "¿Aún no tienes cuenta? Créala". El código del correo aparece en pantalla (modo demo) | Cuenta verificada y sesión abierta; "Aún no tienes tarjeta" |
| 2:00 | 2. Emitir la tarjeta | Administración → Titulares → **Emitir tarjeta** → **Entregar ahora** | Tarjeta `ACTIVE`; en la pestaña del titular aparece sola |
| 3:00 | 3. Recargar $20 | Caja → Crear caja de demostración → Lista demo (o escanear el QR del titular) → Recargar → $20.00 | Ticket "Recarga aprobada", saldo $20.00; el titular ve el movimiento y el correo |
| 3:30 | 4. Cobrar $7.35 | Caja → Cobrar $7.35 (o el titular paga con **Pagar en caja** y el código de la caja) | Ticket "Cobro aprobado", saldo $12.65 |
| 4:00 | 5. Sobregiro de $15.00 | Caja → Cobrar $15.00 | "Saldo insuficiente: la tarjeta tiene $12.65"; saldo intacto |
| 4:30 | Extra: PIN | Ana: cobrar $30.00 → la caja pide el PIN (1234) | Aprobado solo con el PIN correcto |
| 5:30 | 6. Reportar la pérdida | Titular → Reportar pérdida → Enviar código → Bloquear tarjeta | Tarjeta "Bloqueada"; la caja recibe "La tarjeta está bloqueada" |
| 6:30 | 7. Reponer la tarjeta | Administración → Tarjetas → **Reponer** | Tarjeta nueva activa con el mismo saldo; la anterior "Repuesta" |
| 7:00 | 8. Conciliación | Administración → Resumen | "Todo cuadra" y el gráfico de recargas y cobros |
| 7:15 | Módulos | Titular → **Asistente** → "¿Cuál es mi saldo?". Luego Administración → **Módulos** → apagar "Asistente virtual" | El asistente responde con el saldo real; al apagarlo, el botón desaparece del titular en 5 s y la API responde `MODULE_DISABLED` |
| 7:30 | Calidad | `dart run tool/check.dart` o `cd api && dart test` (≈30 s): 1,000 cobros concurrentes, idempotencia, reposición con falla forzada, movimientos inalterables, firma | Todo en verde |
| 9:00 | Cierre | `docs/ROADMAP.md`: NFC (Fase 7) y producción (Fase 8) | — |

## Si algo falla en vivo

| Problema | Acción rápida |
|---|---|
| "Sin conexión con el servidor" | `dart run tool/up.dart`; ver `docker compose logs api` |
| `http://localhost:8080` muestra un error JSON | Falta el build web: `cd apps/app && flutter build web` |
| No aparecen las cuentas demo | La API no está en modo demo: revisar `DEMO_MODE=true` en `.env` |
| Datos raros de un ensayo anterior | Administración → Reiniciar demo |
| La cámara no abre en la web | Solo funciona con `https` (link del túnel) o `localhost`; usar "Lista demo" o "Número" |
| Docker apagado | Abrir Docker Desktop y repetir `dart run tool/up.dart` |
