# ADR 0017: Tarjetas físicas NTAG215 que adoptan el UID del chip

- **Estado:** Propuesto (pendiente de aprobación del equipo)
- **Fecha:** 2026-11-23
- **Autores:** Claude Code (Claude Opus 5.5), con las pruebas de hardware del equipo

## Contexto

La Fase 7 conecta tarjetas físicas. El plan original ([docs/nfc.md](../nfc.md)) elegía MIFARE Classic 1K, con NTAG215 como alternativa si los teléfonos no eran compatibles.

Prueba del equipo (2026-11-23) con un **Redmi Note 15 Pro 5G** y un kit de duplicador:
- Los llaveros redondos del kit son **NTAG215** (NFC TagInfo los reconoce; "Non-genuine": no son de NXP, pero funcionan) y el teléfono los lee.
- Las tarjetas rectangulares del kit no responden al teléfono: son de **125 kHz** y ningún teléfono las lee.

Además, hasta ahora el servidor **inventaba** el UID de cada tarjeta (regla 10). Con un chip, el UID lo pone el fabricante y no se puede elegir.

Opciones evaluadas:
1. Guardar en el chip el número, el UID inventado y la firma, como un QR en silicio. Es simple, pero copiar la memoria a cualquier chip produce una copia válida.
2. **Que la tarjeta adopte el UID real del chip** y que la caja lea el UID del hardware, no de la memoria. Copiar la memoria a otro chip cambia el UID y la firma deja de coincidir.

## Decisión

Se usa **NTAG215** y la opción 2:
- Administración acerca el chip; la app lee su UID (7 bytes, igual que la regla 10) y llama a `POST /v1/admin/cards/{id}/chip`. La API recalcula `HMAC-SHA256(llave maestra, número + UID)` y guarda el UID y la firma nuevos. La app escribe el número y la firma en las páginas 4–12 del chip (`ChipCardLayout` en `core`) y los verifica leyéndolos.
- La caja lee el UID del chip y el número y la firma de su memoria; la API los valida igual que con el QR.
- Solo tarjetas `PENDING` o `ACTIVE`. Un UID no puede estar en dos tarjetas (`CHIP_ALREADY_LINKED`). Repetir con el mismo chip no cambia nada. Cada vinculación queda en `card_chip_links` (solo inserción).
- Se lee y escribe en páginas crudas (`MifareUltralight` de Android, paquete `nfc_manager` 4.3.0), no en NDEF, para controlar el formato y que Android no abra otras apps al acercar la tarjeta.

## Consecuencias

- La regla 10 se conserva (UID de 7 bytes y firma HMAC validada por la API). Lo que cambia es **de dónde sale el UID**: al grabar un chip, el QR anterior deja de servir y el titular ve el nuevo en su app.
- El saldo sigue solo en PostgreSQL; el chip solo identifica.
- **Riesgo conocido:** los NTAG215 genéricos suelen permitir **cambiar el UID**; con un duplicador se puede fabricar una copia exacta (UID y memoria) que la caja aceptaría. Mitigaciones: reportar la pérdida bloquea todas las copias, el PIN protege los cobros de más de $25 y el saldo no está en el chip. Para producción conviene **NTAG 424 DNA** (mensajes autenticados con AES), que no se puede clonar así.
- Pendiente: proteger la escritura del chip con contraseña (PWD/PACK derivada del UID) para evitar que alguien lo borre; no afecta la seguridad del dinero, solo evita vandalismo.
- La lectura NFC solo existe en la app Android; en la web la caja sigue con QR, lista o número.
