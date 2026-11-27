# Tarjetas físicas NFC (Fase 7)

> **Estado (2026-11-23):** implementado con **NTAG215** ([ADR 0017](adr/0017-tarjetas-fisicas-ntag215.md)), en la rama `feat/fase-7-nfc`. La prueba con el Redmi Note 15 Pro 5G mostró que el teléfono lee los llaveros NTAG215 del kit del duplicador, y que las tarjetas rectangulares del kit son de 125 kHz (no sirven). Las secciones 1 a 3 (MIFARE Classic) quedan como referencia; lo que se usa está en la sección 7.

## 1. Tarjeta elegida: MIFARE Classic 1K

| Característica | Valor |
|---|---|
| Nombre comercial | MIFARE Classic 1K, también vendida como **S50** |
| Frecuencia | **13.56 MHz** (ISO/IEC 14443-A) |
| Memoria | 1 KB: 16 sectores × 4 bloques × 16 bytes |
| UID | 4 o 7 bytes, grabado de fábrica en el bloque 0 |
| Seguridad | Dos llaves de 6 bytes por sector (A y B) y bits de acceso |

> ⚠️ **No sirven las tarjetas de 125 kHz** (EM4100, TK4100 y "proximity" en general): usan otra frecuencia, solo guardan un ID de lectura y **los teléfonos no las leen**. Al comprar, verifica que diga *13.56 MHz*, *MIFARE Classic 1K* o *S50*.

## 2. Organización de la memoria

| Sector / bloque | Contenido | Notas |
|---|---|---|
| Sector 0, **bloque 0** | UID y datos del fabricante | **No tocarlo nunca.** En tarjetas originales es de solo lectura; en tarjetas "mágicas" escribirlo mal las inutiliza |
| Sector 0, bloques 1–2 | Sin usar (o directorio MAD) | Se dejan con valores de fábrica |
| **Sector 1, bloque 4** | Número de tarjeta: 16 dígitos en ASCII (16 bytes) | |
| **Sector 1, bloque 5** | Firma: `HMAC-SHA256(llave_maestra, número + UID)` truncada a 16 bytes | La misma firma de la demo |
| Sector 1, bloque 6 | Versión del formato (1 byte) + reservado | Permite cambiar el formato después |
| Sector 1, bloque 7 | *Sector trailer*: llave A (6) + bits de acceso (4) + llave B (6) | Ver sección 3 |
| Sectores 2–15 | Sin usar | Llaves de fábrica, no se escriben |

**El saldo NO se guarda en la tarjeta.** Vive solo en PostgreSQL. La tarjeta solo identifica; así una tarjeta clonada o manipulada no puede crear dinero.

## 3. Llaves y bits de acceso

### Llaves derivadas del UID
Cada tarjeta tiene llaves distintas, así que si se compromete una no se comprometen todas:

```
llave_A = primeros 6 bytes de HMAC-SHA256(K_lectura,   "A" || UID || número_de_sector)
llave_B = primeros 6 bytes de HMAC-SHA256(K_escritura, "B" || UID || número_de_sector)
```

- **Llave A: solo lectura** de los bloques de datos. La usa la caja para leer.
- **Llave B: lectura y escritura.** Solo la usa administración al emitir.
- `K_lectura` y `K_escritura` viven **solo en el servidor**, como la llave maestra de la firma. El teléfono lee el UID (no requiere llave), pide a la API la llave del sector para ese UID con su JWT y su credencial de terminal, y entonces lee o escribe. Un teléfono robado no contiene llaves.

### Bits de acceso del sector 1

| Bloques | Condición (C1 C2 C3) | Efecto |
|---|---|---|
| Datos (4, 5, 6) | `1 0 0` | Leer con A o B; escribir **solo con B** |
| Trailer (7) | `0 1 1` | Llaves y bits de acceso modificables **solo con B** |

Bytes de acceso resultantes: **`78 77 88`**, más el byte de usuario `69`.

> ⚠️ **Riesgo de bloquear el sector para siempre.** Los bits de acceso se guardan junto con su complemento. Si se escriben mal (por ejemplo, sin invertir los bits o con una llave B equivocada), el sector queda **ilegible y no se puede recuperar**. Reglas:
> 1. Calcular los bytes con una función probada y con pruebas unitarias.
> 2. Antes de escribir el trailer, verificar los complementos.
> 3. Probar primero con tarjetas de repuesto.
> 4. Escribir el trailer al final, después de verificar los datos.

### Limitación de seguridad conocida
El cifrado de MIFARE Classic (Crypto-1) está roto: con equipo especializado se pueden obtener las llaves y existen tarjetas con UID modificable. Por eso: (a) la firma HMAC impide fabricar números válidos; (b) el saldo vive en el servidor; (c) el reporte de pérdida bloquea de inmediato; (d) el PIN protege los débitos grandes. Para un sistema real con más riesgo, conviene migrar a NTAG 424 DNA o MIFARE DESFire (sección 6).

## 4. Compatibilidad de teléfonos

- **Solo algunos Android soportan MIFARE Classic.** Requiere un controlador NFC de NXP. Muchos equipos con controladores de otros fabricantes (incluidos varios Samsung) detectan la tarjeta pero **no pueden autenticarse en sus sectores**.
- **iPhone (iOS) no soporta MIFARE Classic.** Core NFC no expone ese protocolo.
- En Android se puede comprobar con `PackageManager.hasSystemFeature("com.nxp.mifare")` y con la clase `android.nfc.tech.MifareClassic`.
- Cada teléfono de caja debe probarse **antes** de comprar tarjetas en cantidad.

## 5. Cómo probar un teléfono

1. Activa NFC en *Ajustes*.
2. Instala **NFC TagInfo by NXP** (Google Play). Acerca una tarjeta MIFARE Classic 1K:
   - Si muestra "MIFARE Classic 1K" y el contenido de los sectores, el teléfono es compatible.
   - Si solo muestra el UID o dice "tag not supported", **no** es compatible.
3. Instala **MIFARE Classic Tool (MCT)** para probar lectura y escritura con llaves:
   - *Read Tag* con las llaves de fábrica (`FFFFFFFFFFFF`) para ver los sectores.
   - Escribe y lee un bloque de datos del sector 1 **en una tarjeta de prueba**.
   - Usa *Access Conditions Decoder/Encoder* para verificar `78 77 88` antes de escribir un trailer.
4. Anota el modelo y el resultado en `docs/ROADMAP.md`.

## 6. Alternativa: NTAG215

Si los teléfonos del equipo no son compatibles con MIFARE Classic:

| | MIFARE Classic 1K | NTAG215 |
|---|---|---|
| Lectura en Android | Solo con controlador NXP | **Todos** los Android con NFC |
| Lectura en iPhone | No | **Sí** |
| Memoria de usuario | ~752 bytes (en sectores) | 504 bytes |
| Protección | Llaves A/B por sector | Contraseña de 32 bits para escritura (PWD/PACK) |
| Firma de originalidad | No | Sí (firma ECC de NXP) |

Con NTAG215, el número y la firma HMAC se guardan en la memoria de usuario, la escritura se protege con contraseña derivada del UID y se verifica la firma de originalidad. La firma HMAC del servidor sigue siendo la defensa principal. Para mayor seguridad existe **NTAG 424 DNA** (AES-128 y mensajes autenticados), que cuesta más.

## 7. Implementación (NTAG215)

### Memoria del chip
| Página | Contenido |
|---|---|
| 0–3 | Del fabricante: UID de 7 bytes, bloqueo y *capability container*. No se tocan |
| 4 | Encabezado `4D 4E` ("MN") + versión del formato (`01`) + `00` |
| 5–8 | Número de 16 dígitos en ASCII |
| 9–12 | Firma `HMAC-SHA256(llave maestra, número + UID)` truncada a 16 bytes |

El formato vive en `ChipCardLayout` (`packages/core`), con pruebas. **El saldo no se guarda en el chip.**

### Grabar un chip (administración, app Android)
1. Administración → Tarjetas → botón **Grabar chip NFC** (ícono sin contacto) en una tarjeta pendiente o activa.
2. Se acerca el chip. La app lee su UID y llama a `POST /v1/admin/cards/{id}/chip`; la tarjeta **adopta el UID del chip** y la API recalcula la firma.
3. La app escribe las páginas 4–12 y las vuelve a leer para verificar.
4. El QR anterior de esa tarjeta deja de servir; el titular ve el nuevo en su app.

Si la escritura falla a la mitad, se repite con el mismo chip: la API no cambia nada la segunda vez. Un chip ya vinculado a otra tarjeta se rechaza (`CHIP_ALREADY_LINKED`).

### Leer en la caja (app Android)
La caja muestra **NFC** como primera opción cuando el teléfono tiene NFC. `NfcCardReader` lee el UID del hardware y el número y la firma de la memoria, y entrega las mismas `CardCredentials` que el QR; la API las valida igual (regla 10). Copiar la memoria a otro chip no sirve, porque el UID leído cambia y la firma deja de coincidir.

### Código
- `apps/app/lib/card_reader/nfc_chip.dart`: `ChipTag` y `NfcChipIo` (frontera con el hardware), `readChipCredentials`, `writeChipCredentials` y la implementación con `nfc_manager` (páginas crudas con `MifareUltralight` de Android, sin NDEF).
- `apps/app/lib/card_reader/nfc_card_reader.dart`: lector de la caja y la hoja "Acerca la tarjeta".
- Permiso `android.permission.NFC` con `android.hardware.nfc` **no obligatorio**: sin NFC la app sigue funcionando con QR, lista o número.
- `TECH_DISCOVERED` (NfcA + MifareUltralight, `res/xml/nfc_tech_filter.xml`) en `MainActivity`: si el chip sigue cerca cuando la lectura ya terminó, Android se lo entrega a Monedero en vez de mostrar "no hay aplicación que admita esta etiqueta". Con la app cerrada, acercar un llavero abre Monedero.

### Probar el teléfono por USB (cuando la Wi-Fi aísla a los clientes)
Algunos routers no dejan que un teléfono en Wi-Fi llegue a una laptop por cable. Con **Depuración USB** activa: `adb reverse tcp:8080 tcp:8080` y compilar con `--dart-define=API_BASE_URL=http://localhost:8080` (o poner esa dirección en **Servidor**). Hay que repetir `adb reverse` cada vez que se conecta el cable.

### Probarlo
1. Compilar e instalar el APK (`docs/android.md`).
2. Administración (en el teléfono): emitir y entregar una tarjeta, **Grabar chip NFC** y acercar un llavero NTAG215.
3. Caja (en el mismo teléfono o en otro con NFC): opción **NFC** → **Acercar la tarjeta** → recargar y cobrar.
4. Prueba de clonación para el informe: copiar el llavero con el duplicador a otro NTAG215 de UID modificable; la copia exacta funciona (riesgo documentado en el ADR 0017) y reportar la pérdida bloquea ambas.

### Pendiente
- Proteger la escritura del chip con contraseña (PWD/PACK derivada del UID).
- Para producción, NTAG 424 DNA (sección 6).
