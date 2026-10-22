# Roadmap

Prioridad: **P0** = necesario para la demostración · **P1** = después de la demo · **P2** = deseable.

## Prototipo de demostración

| Fase | Entregable | Estado |
|---|---|---|
| 1 | Esqueleto del monorepo, Docker Compose, scripts `tool/`, documentación base, `AGENTS.md`, CI | ✅ Terminada |
| 2 | Migraciones, roles y permisos, `core` (Luhn, montos, firma), API completa, 5 pruebas obligatorias, `migrate`/`seed`/`reset_demo`, `tool/demo.dart` | ✅ Terminada (pendiente de aprobación) |
| 3 | **Vistas de diseño** de titular, caja y administración (mismo estilo, datos de ejemplo, sin conectar) | ✅ Terminada (pendiente de aprobación) |
| 4 | Conectar titular y caja a la API: inicio de sesión, saldo con caché "no actualizado", QR real, `CardReader` (QR, lista demo, número), cobro con PIN, recarga, comprobante, pérdida y PIN | ⏳ Siguiente |
| 5 | Conectar administración a la API: emitir y entregar, búsquedas, movimientos, conciliación, terminales, reposición y "Reiniciar demo" | Pendiente |
| 6 | App en Android (emulador y teléfono), pulido, guion final con capturas y `deploy/` preparado | Pendiente |

## Pendientes priorizados

| Prioridad | Pendiente | Notas |
|---|---|---|
| P0 | Fases 4 a 6 | Ver tabla anterior |
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
