# Día de la exposición: link para el ingeniero

Con un comando, la laptop del equipo levanta todo y entrega un **link público temporal** (`https://….trycloudflare.com`). Con ese link el ingeniero abre la app en su computadora o celular y hace la demo completa sin tocar la laptop. Es gratis y no requiere crear cuentas (ver [ADR 0011](adr/0011-exposicion-por-link-con-tunel-y-web-en-la-api.md)).

## Antes (el día anterior)

1. `git pull` y `flutter pub get` en la laptop que va a servir.
2. Probar el ensayo completo de abajo una vez.
3. Si van a usar la APK, instalarla en los celulares del equipo (ver [android.md](android.md)).

## El día de la exposición

1. Abrir **Docker Desktop** y esperar "Engine running". La laptop debe tener Internet y no suspenderse (enchufada, suspensión desactivada).
2. Desde la raíz del repositorio:
   ```bash
   dart run tool/share.dart
   ```
   Tarda de 2 a 4 minutos: compila la web, levanta PostgreSQL, Mailpit, la API y el túnel, migra, siembra e imprime algo así:
   ```text
   Link para el inge (web y celular):
       https://palabras-al-azar.trycloudflare.com
   (QR en la consola)
   ```
   Si ya compilaste la web y no cambió nada, `dart run tool/share.dart --sin-compilar` es más rápido.
3. Comparte el link (WhatsApp, correo o el QR de la consola). Si el script avisa que el link aún no responde, espera uno o dos minutos: el nombre tarda en propagarse.
4. Al terminar: `dart run tool/down.dart` (detiene también el túnel; el link deja de funcionar).

## Qué hace el ingeniero con el link

- **Computadora:** abre el link. En la pantalla inicial elige un rol; en modo demo cada pantalla de inicio de sesión ofrece "Entrar como…" con las cuentas de prueba.
- **Celular (web):** escanea el QR de la consola o el que muestra la pantalla inicial ("Ábrela en el celular"). En Android, el menú del navegador ofrece **Instalar app** (es una PWA); en iPhone, Compartir → Agregar a inicio.
- **Celular (APK):** abre la app → ícono de servidor (arriba a la derecha) → **Escanear QR del link** o pegar el link → Probar y guardar.
- Los códigos que en producción llegan por correo se muestran en pantalla, y el titular ve sus correos en "Correos recibidos". No hace falta Mailpit.
- La cámara para escanear QR funciona porque el link es `https`. Sin cámara, la caja tiene "Lista demo" y "Número".

Sugerencia para que pruebe solo: titular en su celular (Ana) y caja en su computadora. La caja muestra su **código de caja**; Ana toca **Pagar en caja**, escribe el código y el monto, y el pago aparece al instante en "Últimos movimientos" de la caja.

## Cuentas de demostración

| Rol | Usuario | Contraseña | PIN |
|---|---|---|---|
| Titular | `ana@demo.local` o `bruno@demo.local` | `Titular1234` | `1234` |
| Caja | `cajero@monedero.local` | `Cajero1234` | — |
| Administración | `admin@monedero.local` | `Admin1234` | — |

El guion de 10 minutos está en [demo.md](demo.md).

## Si algo falla

| Problema | Qué hacer |
|---|---|
| `docker compose` falla | Abrir Docker Desktop; `dart run tool/doctor.dart` |
| No aparece el link (sin Internet o Cloudflare caído) | `docker compose logs tunnel`. Plan B: misma Wi-Fi, abrir `http://<IP-de-la-laptop>:8080` (la cámara no funciona por `http`; usar "Lista demo") |
| El link abre pero dice "Sin conexión con el servidor" | Revisar que la API esté arriba: `docker compose ps` y `docker compose logs api` |
| Datos raros de ensayos | Administración → Resumen → **Reiniciar demo** |
| Muchas personas a la vez reciben "Demasiadas solicitudes" | Subir `RATE_LIMIT_PER_MINUTE` en `.env` y repetir `dart run tool/share.dart --sin-compilar` |

## Seguridad

- El link es público mientras el túnel esté arriba: quien lo tenga entra a la demo. Se levanta solo para la exposición y se detiene al terminar.
- Solo con datos de demostración y `DEMO_MODE=true`. Nunca con datos reales.
- Cada vez que se recrea el túnel el link cambia; compartan el nuevo.
- El despliegue real (dominio propio, HTTPS con Caddy, respaldos) es la Fase 8 y requiere aprobación del equipo porque cuesta dinero ([deploy-contabo.md](deploy-contabo.md)).
