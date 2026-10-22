# Guion de demostración (10 minutos)

> Estado: **borrador**. Las pantallas se construyen en las fases 3 a 5; el guion definitivo, con capturas y tiempos ensayados, se completa en la **Fase 6**.

## Preparación (antes de presentar)

1. `dart run tool/up.dart` y confirmar que la API responde.
2. `dart run tool/reset_demo.dart` para dejar los datos de demostración limpios *(Fase 2)*.
3. Abrir en pestañas:
   - App web, administración: `flutter run -d chrome --web-port 5000`
   - Mailpit: <http://localhost:8025>
4. Teléfono Android con la app (caja o titular) conectado por `adb reverse` (ver `setup.md`).

## Usuarios de prueba

Se definen en `db/seed/` en la Fase 2.

| Rol | Usuario | Contraseña |
|---|---|---|
| Administrador | _Fase 2_ | _Fase 2_ |
| Cajero | _Fase 2_ | _Fase 2_ |
| Titular de ejemplo | _Fase 2_ | _Fase 2_ |

## Guion

| Min | Paso | Quién / dónde | Qué mostrar | Resultado esperado |
|---|---|---|---|---|
| 0:00 | Contexto | — | Qué es un monedero de circuito cerrado; arquitectura en una diapositiva | — |
| 1:00 | 1. Registrar un titular | Titular · teléfono | Registro, código en Mailpit, verificación | Titular con correo verificado |
| 2:30 | 2. Emitir una tarjeta virtual | Administración · web | Emitir y entregar; tarjeta con QR en la app del titular | Tarjeta `ACTIVE`, saldo $0.00 |
| 3:30 | 3. Recargar $20 | Caja · teléfono o web | Escanear QR, botón $20, comprobante | Saldo $20.00 |
| 4:30 | 4. Cobrar $7.35 | Caja | Monto libre, comprobante | Saldo $12.65 |
| 5:15 | 5. Intentar un sobregiro | Caja | Cobrar $50.00 | Rechazo "Saldo insuficiente"; saldo intacto |
| 6:00 | 6. Reportar la pérdida | Titular | Reporte, código en Mailpit | Tarjeta `BLOCKED`; la caja ya no puede cobrarle |
| 7:30 | 7. Reponer la tarjeta | Administración | Ejecutar la reposición | Tarjeta nueva `ACTIVE` con $12.65; anterior `REPLACED` |
| 8:30 | 8. Conciliación | Administración | Pantalla de conciliación | **Cero diferencias** |
| 9:00 | Calidad | — | Pruebas de 1,000 débitos concurrentes e idempotencia en verde | — |
| 10:00 | Cierre | — | Próximos pasos: NFC y Contabo | — |

## Si algo falla en vivo

| Problema | Acción rápida |
|---|---|
| El teléfono no llega a la API | `adb reverse tcp:8080 tcp:8080` o usar la app web |
| Datos inconsistentes de un ensayo anterior | `dart run tool/reset_demo.dart` |
| Docker apagado | Abrir Docker Desktop y `dart run tool/up.dart` |
