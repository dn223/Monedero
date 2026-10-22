# ADR 0003: Tarjetas simuladas en la demo, preparadas para NFC

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

La arquitectura definitiva usa tarjetas MIFARE Classic 1K leídas por NFC desde teléfonos Android. Para la demostración: el costo debe ser $0, no todos los teléfonos del equipo soportan MIFARE Classic (y iPhone no lo soporta), y la demo debe poder hacerse desde una laptop. Aun así, el flujo de emisión, los estados y la validación de la firma deben ser los mismos que tendrá el sistema real.

## Decisión

- La app depende de una interfaz **`CardReader`** que devuelve `{número, UID, firma}`.
- Ahora se implementa **`SimulatedCardReader`**: escanear el QR de la tarjeta virtual, elegir de una lista de demostración (solo en modo demo) o escribir el número a mano.
- **`NfcMifareCardReader`** queda como esqueleto documentado, sin dependencias NFC activas (plan en `docs/nfc.md`).
- La emisión desde administración genera la tarjeta virtual (número, UID simulado de 7 bytes y firma HMAC) en lugar de escribir un chip.
- La API valida número, UID y firma de la misma forma, venga del QR o del chip.

## Consecuencias

- ✅ Demo gratuita, en web y en cualquier Android.
- ✅ Pasar al NFC real cambia solo la implementación del lector y la escritura del chip; la API, la base y las pantallas no cambian.
- ⚠️ El QR de la tarjeta virtual se puede fotografiar y reutilizar. Se acepta en la demo porque el saldo vive en el servidor, la firma impide fabricar tarjetas, el PIN protege los débitos grandes y el reporte de pérdida bloquea de inmediato.
- ⚠️ La lista de tarjetas de demostración solo existe con `DEMO_MODE=true`.
