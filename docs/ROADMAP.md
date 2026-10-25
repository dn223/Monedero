# Roadmap

Prioridad: **P0** = necesario para la demostración · **P1** = después de la demo · **P2** = deseable.

## Plan de entregas

| Entrega | Contenido | Estado |
|---|---|---|
| **1. Esta entrega** (2026-10-25) | Fases 1 a 6: app conectada a la API en los tres roles, administración, renovación de sesión y límites, APK instalable y exposición por link público para el ingeniero | ✅ Lista en la rama `feat/fase-4-6-demo`, pendiente de revisión del equipo |
| **2. Siguiente entrega** | La última fase de construcción: **Fase 7** (tarjetas físicas NFC). La Fase 8 (producción en Contabo) solo si el equipo aprueba el gasto | Pendiente |
| **3. Entrega final** | Las observaciones que vaya dejando el ingeniero en las entregas anteriores, más el informe académico | Pendiente |

## Prototipo de demostración

| Fase | Entregable | Estado |
|---|---|---|
| 1 | Esqueleto del monorepo, Docker Compose, scripts `tool/`, documentación base, `AGENTS.md`, CI | ✅ Terminada |
| 2 | Migraciones, roles y permisos, `core` (Luhn, montos, firma), API completa, 5 pruebas obligatorias, `migrate`/`seed`/`reset_demo`, `tool/demo.dart` | ✅ Terminada (pendiente de aprobación) |
| 3 | **Vistas de diseño** de titular, caja y administración (mismo estilo, datos de ejemplo, sin conectar) | ✅ Terminada (reemplazada por las pantallas reales de la Fase 4) |
| 4 | App conectada a la API: inicio de sesión real de los 3 roles, titular (registro, saldo, historial, QR real, pérdida, PIN, pago con código de caja), caja (QR con cámara, lista demo, número, cobro con PIN, recarga y comprobante) | ✅ Terminada (pendiente de revisión) |
| 5 | Administración conectada (tablero, emitir, entregar, reponer, buscar, conciliación, cajas, reiniciar demo) y endurecimiento: renovación de sesión con tokens rotativos y límite de solicitudes | ✅ Terminada (pendiente de revisión) |
| 6 | App Android instalable (ícono propio, nombre provisional "Monedero", APK release firmado), web instalable (PWA) y exposición por link público (`tool/share.dart`) | ✅ Terminada (pendiente de revisión; falta probar el APK en varios celulares) |
| 7 | Tarjetas físicas NFC: prueba de celulares, `NfcMifareCardReader`, emisión escribiendo el chip (alternativa NTAG215) | Pendiente (siguiente entrega) |
| 8 | Producción: VPS Contabo, dominio, HTTPS con Caddy, PostgreSQL con respaldos pgBackRest → Backblaze B2, correo real, `DEMO_MODE=false`, monitoreo; el APK apunta a `https://<dominio>` | Pendiente (requiere aprobación del equipo: cuesta dinero) |

## Pendientes priorizados

| Prioridad | Pendiente | Notas |
|---|---|---|
| P0 | Revisar y fusionar `feat/fase-4-6-demo` en `main` | Lo decide el equipo; la sesión de IA no fusionó ni subió la rama |
| P0 | Ensayar la exposición con `dart run tool/share.dart` | [exposicion.md](exposicion.md) |
| P0 | Probar el APK en celulares del equipo y respaldar el keystore (`~/.monedero/`) | [android.md](android.md) |
| P0 | Proteger `main` en GitHub e invitar al equipo | Repositorio: `dn223/Monedero` |
| P0 | Llenar la tabla de responsables en `AGENTS.md` | Equipo |
| P1 | **Nombre definitivo** de la app | Proceso en `NAMING.md`; el ícono se regenera desde `brand.dart` |
| P1 | Probar compatibilidad MIFARE Classic de los teléfonos del equipo | `docs/nfc.md`, sección 5 |
| P1 | **NFC real**: implementar `NfcMifareCardReader` y la emisión física | Depende de la prueba anterior; alternativa NTAG215 |
| P1 | Token de renovación en cookie `HttpOnly` para la web | Hoy vive en `localStorage` (ADR 0010) |
| P1 | **Despliegue en Contabo** | Solo con aprobación del equipo; genera costo mensual |
| P1 | **Respaldos** pgBackRest → Backblaze B2 y prueba de restauración | Junto con el despliegue |
| P1 | Proveedor SMTP real para producción | Reemplaza a Mailpit |
| P2 | Límite de solicitudes compartido (PostgreSQL o Redis) si hay varias réplicas | Hoy en memoria (ADR 0010) |
| P2 | Réplica de la base en un segundo servidor | Fuera de alcance de esta fase |
| P2 | Migrar a tarjetas con criptografía moderna (NTAG 424 DNA / DESFire) | Si el riesgo lo justifica |

## Teléfonos probados para NFC

| Modelo | Android | NFC TagInfo | MIFARE Classic | Probado por |
|---|---|---|---|---|
| _por probar_ | | | | |
