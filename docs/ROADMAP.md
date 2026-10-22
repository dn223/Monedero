# Roadmap

Prioridad: **P0** = necesario para la demostración · **P1** = después de la demo · **P2** = deseable.

## Prototipo de demostración

| Fase | Entregable | Estado |
|---|---|---|
| 1 | Esqueleto del monorepo, Docker Compose, scripts `tool/`, documentación base, `AGENTS.md`, CI | ✅ Terminada |
| 2 | Migraciones, roles y permisos, `core` (Luhn, montos, firma), API completa, 5 pruebas obligatorias, `migrate`/`seed`/`reset_demo`, `tool/demo.dart` | ✅ Terminada (pendiente de aprobación) |
| 3 | App del titular: registro con código, saldo, historial, tarjeta virtual con QR, pérdida, reposición, cambio de PIN | ⏳ Siguiente |
| 4 | Caja y simulación de tarjetas: `CardReader`, QR, lista demo, número manual, cobro con PIN, recarga, comprobante | Pendiente |
| 5 | Administración web: emitir, buscar, movimientos, conciliación, terminales, reiniciar demo | Pendiente |
| 6 | Pulido, guion de demo ensayado, capturas, `deploy/` preparado | Pendiente |

## Pendientes priorizados

| Prioridad | Pendiente | Notas |
|---|---|---|
| P0 | Fases 2 a 6 | Ver tabla anterior |
| P0 | Proteger `main` en GitHub e invitar al equipo | Repositorio: `dn223/Monedero` |
| P1 | Renovación de tokens (refresh) | Hoy el JWT dura 15 min |
| P0 | Llenar la tabla de responsables en `AGENTS.md` | Equipo |
| P1 | **Nombre definitivo** de la app | Proceso en `NAMING.md` |
| P1 | Logotipo e íconos propios | Después del nombre |
| P1 | Probar compatibilidad MIFARE Classic de los teléfonos del equipo | `docs/nfc.md`, sección 5 |
| P1 | **NFC real**: implementar `NfcMifareCardReader` y la emisión física | Depende de la prueba anterior; alternativa NTAG215 |
| P1 | **Despliegue en Contabo** | Solo con aprobación del equipo; genera costo mensual |
| P1 | **Respaldos** pgBackRest → Backblaze B2 y prueba de restauración | Junto con el despliegue |
| P1 | Proveedor SMTP real para producción | Reemplaza a Mailpit |
| P2 | Réplica de la base en un segundo servidor | Fuera de alcance de esta fase |
| P2 | Migrar a tarjetas con criptografía moderna (NTAG 424 DNA / DESFire) | Si el riesgo lo justifica |

## Teléfonos probados para NFC

| Modelo | Android | NFC TagInfo | MIFARE Classic | Probado por |
|---|---|---|---|---|
| _por probar_ | | | | |
