# Bitácora de sesiones

Registro de cada sesión de trabajo, **la más reciente primero**. Al terminar una sesión, agrega una entrada con la plantilla (ver `AGENTS.md`, sección 8).

```markdown
## AAAA-MM-DD — <integrante> — <IA usada>
**Qué se hizo:**
- …
**Pendiente:**
- …
**Problemas conocidos:**
- …
```

---

## 2026-11-25 — Steven (sm224m) — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/fase-7-nfc`):
- `tool/check.dart` en verde y commit de la Fase 7 (`90a458f`).
- Se descartó NFC en la web (Web NFC): el diseño original deja la lectura de tarjetas en la app Android y la web para administración y demo (ADR 0017 sin cambios).
- **Prueba con el Redmi Note 15 Pro 5G y un llavero NTAG215** (APK release por USB con `adb reverse tcp:8080 tcp:8080`): Administración grabó el chip (`POST /v1/admin/cards/{id}/chip` → 200) y Caja hizo una recarga a esa tarjeta (201).
- Link público con `tool/share.dart` y APK de 64 bits compilado con `API_BASE_URL` igual al link; descarga verificada por `/descargas/monedero.apk` (mismo SHA-256). Instalado en el Redmi apuntando al link, sin cable.
- Prueba completa con el llavero desde la app instalada usando el link (sin cable): cobro, cobro con PIN (> $25), chip repetido rechazado (`CHIP_ALREADY_LINKED`), llavero sin grabar rechazado y conciliación en cero. Todo correcto según el integrante. En la web la caja no muestra NFC (es lo esperado).

**Pendiente:**
- Aprobación del ADR 0017 por el equipo; revisión y fusión de las tres ramas.

**Problemas conocidos:**
- El link y el APK descargable dependen de que la laptop siga encendida con Docker e Internet; si el túnel se recrea, el link cambia (la app se reconfigura escaneando el QR, sin reinstalar). Para que funcione sin la laptop hace falta la Fase 8.
- `adb reverse` se pierde al reconectar el cable; hay que volver a correrlo.
- El APK de este equipo sigue firmado con la llave de depuración.

---

## 2026-11-23 — Integrante por confirmar — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/fase-7-nfc`, que parte de `feat/observaciones-2`; sin push ni fusión):
- Equipo nuevo preparado: Flutter 3.47.7 en `C:\src\flutter`, Git 2.55.0 y Docker Desktop. `tool/check.dart` en verde en `main` y en `feat/observaciones-2`.
- Prueba de hardware: el **Redmi Note 15 Pro 5G** lee los llaveros **NTAG215** de un kit de duplicador (genéricos, "Non-genuine"); las tarjetas rectangulares del kit son de 125 kHz y ningún teléfono las lee.
- **Fase 7 con NTAG215** (ADR 0017, *Propuesto*): administración graba el chip y la tarjeta adopta su UID (`POST /v1/admin/cards/{id}/chip`, migración `0007`, `CHIP_ALREADY_LINKED`); la caja lee con `NfcCardReader`. `ChipCardLayout` en `core`; paquete `nfc_manager` 4.3.0; permiso NFC no obligatorio.
- Pruebas: 37 de `core`, 60 de la API y 18 de la app, en verde. API 0.9.0, app 0.8.0+8.

**Pendiente:**
- Probar el APK en el teléfono con los llaveros: grabar desde Administración y cobrar desde Caja. Hasta entonces la lectura y escritura real del chip no se ha probado (solo con un chip simulado en las pruebas).
- Aprobación del ADR 0017 por el equipo; contraseña de escritura del chip (PWD/PACK); comprar tarjetas NTAG215 de 13.56 MHz.
- Configurar la identidad de Git en este equipo antes de hacer commits.

**Problemas conocidos:**
- El APK de este equipo se firma con la llave de depuración (la llave oficial está en `~/.monedero/` de otro equipo): para instalarlo hay que desinstalar antes un APK firmado con la llave oficial.
- Los NTAG215 genéricos suelen permitir cambiar el UID, así que un duplicador puede hacer una copia exacta (ADR 0017).

---

## 2026-11-19 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/observaciones-2`):
- Prueba manual en la web (http://localhost:8080) con el link del equipo activo, sin reiniciar la demo: caja con código (cobro de $3.50 y recarga de $5 a la tarjeta de prueba), botón **Anular** en Administración → Tarjetas → historial (devolución con motivo, compra marcada "anulado"), conciliación en cero y vista del titular con el movimiento y el correo de aviso.
- APK descargable desde el link: la API sirve el APK release de 64 bits en `/descargas/monedero.apk` y la pantalla inicial de la web muestra **Descargar app para Android**. El APK se compiló con `API_BASE_URL` igual al link del túnel, así que abre conectado al servidor.
- `main.dart.js` se sirve sin caché para que un build nuevo se vea sin borrar la caché del navegador.
- Se reinició solo el contenedor de la API (el túnel no se recreó; el link sigue igual). Descarga verificada por el link (mismo SHA-256 que el build).

**Pendiente:**
- Instalar el APK en un celular real y recorrer los tres roles.
- Si el link del túnel cambia, recompilar el APK (o cambiar el servidor en la app).

**Problemas conocidos:**
- El APK descargable apunta a un link temporal; cuando se apague el túnel, la app pide otra dirección de servidor.

---

## 2026-11-18 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/observaciones-2`, que parte de `feat/fase-4-6-demo`):
- Observaciones del ingeniero: anulación de transacciones, transferencia del saldo a una tarjeta nueva y apartado para editar los datos del usuario. Decisiones del equipo: solo administración anula; la transferencia es una tarjeta nueva pedida por el titular; el perfil incluye nombre, contraseña, correo y PIN; anulación y transferencia son módulos.
- Anulación por **contramovimiento** (`REVERSAL_IN`/`REVERSAL_OUT`, tabla `reversals`): el movimiento original no se edita, la conciliación sigue en cero y no hay sobregiro.
- Tarjeta nueva pedida por el titular con código por correo; reutiliza la reposición atómica.
- Mi perfil en la app (botón en la barra del titular) y botón **Anular** en el historial de administración.
- Migración `0006`, ADR 0016, API 0.8.0, documentación (API, OpenAPI, base de datos, dominio, pruebas).
- `tool/check.dart` en verde: 32 de `core`, 54 de la API y 10 de la app.
- APK release nativo por arquitectura (`flutter build apk --release --split-per-abi`, ≈25 MB el de `arm64-v8a`), firmado con la llave oficial; contiene `libapp.so` (Dart compilado AOT) y `libflutter.so`, sin webview.

**Pendiente:**
- Probado a mano en la web (2026-11-18): anulación de un cobro (por API como administración, y su vista en la app del titular), cambio de nombre y de correo, y tarjeta nueva con traslado de saldo. Falta ver a mano el botón **Anular** en Administración (cubierto por prueba de widgets) y probar el APK release en un celular.
- Fusionar `feat/fase-4-6-demo` y esta rama en `main` tras la revisión del equipo.
- Cambiar la contraseña no revoca las otras sesiones abiertas (pendiente para producción).

**Problemas conocidos:**
- No hay anulaciones parciales: se anula el monto completo.

---

## 2026-10-27 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/fase-4-6-demo`, sin push ni fusión):
- Observación del ingeniero (vía Fabio): el proyecto debe tener **módulos** que se activan y desactivan desde el sistema, por ejemplo un chatbot, y el backend debe hacerlo cumplir.
- Migración `0004` (`app_modules`, `module_changes`), `AppModule` y `MODULE_DISABLED` en `core`, `ModuleService` en la API y verificación en cada ruta de módulo.
- Asistente virtual por reglas para el titular (`POST /v1/assistant/messages`) con datos reales.
- Pantalla **Administración → Módulos** y chat del asistente en la app; el titular oculta lo apagado.
- Presentación de entrada (`docs/presentacion-intro.pdf`) con una diapositiva nueva de módulos y asistente; ahora son 6.
- Pruebas: 3 de `core`, 7 unitarias del asistente, 6 de integración de módulos y 2 de widgets. ADR 0014 y documentación.

- Sistema sin datos de prueba (ADR 0015): solo la cuenta de administración (contraseña en `.env`), caja que entra con el código que genera administración (migración `0005`), titulares que se registran, y sin la palabra "demo" en la app. Asistente apagado para la exposición.

**Pendiente:**
- El ingeniero quiere el proyecto **desplegado con una URL**: hoy es el link temporal de `tool/share.dart`; uno permanente necesita cuenta y aprobación del equipo.
- Confirmar con el ingeniero cuáles son los "requerimientos adicionales" que pidió.
- En la exposición, hablar de "módulos", no de "panel de administrador" (indicación de Fabio).

**Problemas conocidos:**
- El asistente solo entiende las preguntas previstas (saldo, movimientos, recargas, pagos, QR, PIN, pérdida, reposición).

---

## 2026-10-25 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo** (rama `feat/fase-4-6-demo`, sin push ni fusión):
- Fases 4 y 5: la app quedó conectada a la API en los tres roles (inicio de sesión real con sesión guardada por rol; titular con registro, saldo, QR, pago con código, PIN, pérdida y buzón demo; caja con vínculo de terminal, lectura simulada por QR/lista/número, cobro con PIN, recarga y comprobante tipo ticket; administración con tablero y gráfico, tarjetas, titulares, cajas y reinicio de la demo).
- API: renovación de sesión con tokens rotativos (migración `0003`), límite de solicitudes por minuto, códigos de correo visibles en modo demo, buzón demo, cajas demo por dispositivo, tablero de indicadores y reinicio de la demo por API.
- Fase 6: APK release firmado (keystore en `C:\Users\alexi\.monedero\`, fuera de git), ícono generado desde `brand.dart`, PWA, y exposición por link: la API sirve la web y `dart run tool/share.dart` abre un quick tunnel de Cloudflare en Docker.
- Interfaz pulida con los skills `frontend-design` y `dataviz` (paleta del gráfico validada para daltonismo). Probada en el navegador a ancho de escritorio y de celular, en claro y oscuro, y por el link público.
- Documento de la presentación del avance (`docs/monedero-doc.pdf`) actualizado a las fases 1 a 6, con capturas nuevas; la fuente HTML queda en `docs/presentacion/` para regenerarlo con Chrome.
- (2026-10-27) Presentación de entrada de 5 diapositivas en PDF con el estilo de la app (`docs/presentacion-intro.pdf`): portada, qué es, arquitectura y reglas del dinero, lo que ya funciona, y paso al sistema en vivo.
- Documentación: README con capturas, `docs/exposicion.md`, `docs/android.md`, demo desde la app, API/OpenAPI, base de datos, arquitectura, setup (versiones), pruebas, dominio, roadmap con plan de entregas, ADR 0010–0013. Se reparó la doble codificación de `CHANGELOG.md`.

**Pendiente:**
- Revisión del equipo y fusión a `main`; ensayo de la exposición.
- Probar el APK en celulares reales (solo se compiló y se verificó la firma) y respaldar el keystore.
- Fase 7 (NFC) en la siguiente entrega; Fase 8 (Contabo) solo con aprobación del equipo.

**Problemas conocidos:**
- El nombre del quick tunnel puede tardar uno o dos minutos en responder; `tool/share.dart` lo avisa.
- Los quick tunnels de Cloudflare no garantizan disponibilidad; plan B en `docs/exposicion.md` (red local).
- En la web los tokens viven en `localStorage` (aceptable para el prototipo; ver ADR 0010).
- El APK universal pesa ≈70 MB; `--split-per-abi` lo reduce a ≈25 MB.

---

## 2026-10-22 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

**Qué se hizo:**
- (Tarde) Fases reordenadas a pedido del equipo: la Fase 3 pasa a ser **vistas de diseño** de los 3 roles con datos de ejemplo, para mostrarlas en la exposición; la conexión real con la API queda para las fases 4 y 5, y Android para la 6. Guion de exposición en PDF.
- Repositorio publicado en GitHub: `dn223/Monedero` (`main` = Fase 1).
- Fase 2 completa en la rama `feat/fase-2-api`: `core` (dinero, Luhn, firma), migración inicial con barreras en la base, migrador con checksum, API completa y sembrado de demo.
- Las 5 pruebas obligatorias pasan contra PostgreSQL real (16 pruebas de API, 15 de `core`).
- `tool/demo.dart` recorre los 8 pasos de la demo con códigos leídos de Mailpit; conciliación en $0.00.

**Pendiente:**
- Fase 3: app del titular. Renovación de tokens (refresh). Botón "Reiniciar demo" vía API (Fase 5).
- Completar apellidos de Leonardo, Bayron y Steven; tabla de responsables.

**Problemas conocidos:**
- `tool/check.dart` ahora necesita Docker levantado (`dart run tool/up.dart`) por las pruebas de integración.
- Con 1,000 operaciones simultáneas sobre la misma tarjeta, las solicitudes esperan conexión del pool; el tiempo de espera es configurable (`openPool(acquireTimeout:)`).

---

## 2026-10-21 — David Alexis Navarrete Gálvez (dn223) — Claude Code (Claude Opus 5.5)

> Nota: en paralelo, Kevin (con Claude Code, en su equipo) propuso un plan casi idéntico e instaló WSL y Docker, pero no escribió código. Este repositorio es el que tiene la Fase 1 implementada.

**Qué se hizo:**
- Revisión del entorno en Windows 11 Home: instalación de WSL 2 (3.0.3, sin distribución) y Docker Desktop 4.96.2; Flutter actualizado a 3.47.7.
- Decisión de usar `shelf` + `shelf_router` en lugar de Dart Frog (ADR 0002).
- Fase 1: monorepo con pub workspaces (`packages/core`, `api`, `apps/app`), API mínima con `GET /health`, CORS y formato de errores; app con marca centralizada, Material 3 claro/oscuro y comprobación de la API.
- Docker Compose (PostgreSQL 17.11, Mailpit v1.31.6, API) y scripts `tool/` (`up`, `down`, `doctor`, `check` con guardia de dinero).
- Documentación base, ADR 0001–0007, `NAMING.md`, plantillas de GitHub y CI.

**Pendiente:**
- Aprobación de la Fase 1 por el equipo.
- Crear el repositorio en GitHub, subirlo y proteger `main`.
- Fase 2: base de datos, `core` y API con las 5 pruebas obligatorias.

**Problemas conocidos:**
- En PowerShell 5.1, al redirigir la salida de los scripts a un archivo, los acentos pueden verse mal; en la consola o en Windows Terminal se ven bien.
- `test` queda en 1.31.1 porque Flutter 3.47.7 fija `test_api` 0.7.12.
