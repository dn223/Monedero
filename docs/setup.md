# Instalación del entorno de desarrollo

Guía paso a paso para **Windows 11** (incluido **LTSC**, sin Microsoft Store ni `winget`) y **macOS**. Al terminar podrás levantar la base, la API y Mailpit con un solo comando y abrir la app en el navegador o en Android.

> Costo: **$0**. Todo es software gratuito para uso educativo.

---

## 1. Versiones verificadas

Verificadas el **2026-10-21** en pub.dev, Docker Hub y GitHub. Si instalas versiones más nuevas, actualiza esta tabla en tu pull request.

### Herramientas

| Herramienta | Versión verificada | Notas |
|---|---|---|
| Flutter (canal stable) | **3.47.7** | Incluye Dart **3.13.5** |
| Git | 2.55.0 | |
| Docker Desktop | **4.96.2** | Docker Engine 29.9.2, Docker Compose v5.6.1 |
| WSL (solo Windows) | 3.0.3 | Motor de Docker en Windows; no se instala ninguna distribución Linux |
| JDK | 17 (Microsoft OpenJDK 17.0.20) | El que trae Android Studio también sirve |
| Android SDK | Platform 36, build-tools 36.0.0 | |
| Google Chrome | cualquiera reciente | Para Flutter Web |

### Imágenes de Docker

| Imagen | Etiqueta | Uso |
|---|---|---|
| `postgres` | `17.11` | Base de datos |
| `axllent/mailpit` | `v1.31.6` | Bandeja de correo local |
| `dart` | `3.13.6` | Compilar la API (etapa de construcción) |
| `caddy` | `2.11.7` | Solo producción (`deploy/`) |

### Paquetes de Dart / Flutter (`pubspec.lock`)

| Paquete | Versión | Dónde |
|---|---|---|
| `shelf` | 1.4.3 | api |
| `shelf_router` | 1.1.5 | api |
| `flutter_riverpod` | 3.4.3 | app |
| `go_router` | 18.1.1 | app |
| `http` | 1.6.0 | app |
| `cupertino_icons` | 2.0.0 | app (lo exige la compilación web) |
| `meta` | 1.19.0 | core |
| `crypto` | 3.0.7 | core, api (HMAC-SHA256, SHA-256) |
| `postgres` | 3.5.20 | api |
| `bcrypt` | 1.2.0 | api (contraseñas y PIN) |
| `dart_jsonwebtoken` | 3.4.1 | api (JWT HS256) |
| `mailer` | 7.2.0 | api (SMTP hacia Mailpit) |
| `uuid` | 4.6.0 | api (solo pruebas) |
| `lints` | 6.1.0 | raíz, api, core |
| `flutter_lints` | 6.0.0 | app |
| `test` | 1.31.1 | api, core — **no 1.33.0**: Flutter 3.47.7 fija `test_api` 0.7.12 y en un workspace todos comparten esa versión |

### GitHub Actions

| Acción | Versión |
|---|---|
| `actions/checkout` | v7.0.1 |
| `subosito/flutter-action` | v2.23.0 |

---

## 2. Windows 11 (Home, Pro o LTSC)

> No se usa `winget` ni Microsoft Store: algunos integrantes usan **Windows 11 LTSC**. Todos los pasos usan instaladores oficiales o archivos zip.
> Usa rutas **cortas y fuera de OneDrive** (por ejemplo `C:\src`). OneDrive bloquea archivos de Git y de Gradle mientras sincroniza.

### 2.1 Git
1. Descarga el instalador de 64 bits desde <https://git-scm.com/download/win>.
2. Instala con las opciones por defecto.
3. Configura tu identidad (una sola vez):
   ```powershell
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu.correo@ejemplo.com"
   ```

### 2.2 Flutter (zip)
1. Descarga el zip de Flutter estable para Windows desde <https://docs.flutter.dev/get-started/install/windows>.
2. Extrae la carpeta `flutter` en `C:\src\flutter` (no en `Program Files`: necesita permisos de escritura).
3. Agrega `C:\src\flutter\bin` al **PATH de usuario**:
   - `Win + R` → `sysdm.cpl` → *Opciones avanzadas* → *Variables de entorno*.
   - En *Variables de usuario*, edita `Path` → *Nuevo* → `C:\src\flutter\bin`.
4. Abre una **consola nueva** y verifica:
   ```powershell
   flutter --version
   ```

### 2.3 Android (SDK y JDK)
Opción recomendada: **Android Studio** (instalador oficial `.exe` de <https://developer.android.com/studio>). Trae el SDK, el emulador y un JDK.

1. Instala Android Studio y ábrelo una vez para que descargue el SDK.
2. En *SDK Manager* → *SDK Tools*, marca **Android SDK Command-line Tools**.
3. Acepta las licencias:
   ```powershell
   flutter doctor --android-licenses
   ```
4. (Opcional) Crea un emulador en *Device Manager* (por ejemplo, Pixel con API 36).

### 2.4 WSL 2 (motor de Docker)
Docker en Windows necesita WSL 2. **No es necesario instalar Ubuntu** ni usar Linux.

1. Verifica que la virtualización esté activa: *Administrador de tareas* → *Rendimiento* → *CPU* → "Virtualización: Habilitado". Si no, actívala en la BIOS/UEFI (Intel VT-x / AMD-V).
2. Abre **PowerShell como administrador** y ejecuta:
   ```powershell
   wsl --install --no-distribution --web-download
   ```
   `--web-download` descarga WSL desde GitHub en lugar de la Store.
3. **Reinicia** el equipo.

**Si estás en LTSC y el paso 2 falla**, hazlo a mano (PowerShell como administrador):
```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```
Luego descarga el `.msi` x64 más reciente de <https://github.com/microsoft/WSL/releases>, instálalo y **reinicia**. Verifica con `wsl --version`.

### 2.5 Docker Desktop
1. Descarga el instalador desde <https://docs.docker.com/desktop/setup/install/windows-install/> (`Docker Desktop Installer.exe`).
2. Ejecútalo y deja marcada la opción **Use WSL 2 instead of Hyper-V**.
3. Ábrelo desde el menú Inicio, **acepta la licencia** (gratuita para uso educativo y personal) y espera "Engine running". Puedes omitir el inicio de sesión.
4. Abre una **consola nueva** y verifica:
   ```powershell
   docker --version
   docker compose version
   ```

### 2.6 Editor
Cursor o VS Code con las extensiones **Dart** y **Flutter** (Dart-Code). No hace falta Visual Studio: no compilamos apps de escritorio Windows.

---

## 3. macOS (Apple Silicon o Intel)

1. **Herramientas de línea de comandos** (trae Git):
   ```bash
   xcode-select --install
   ```
   Xcode completo **no** es necesario (no compilamos para iOS).
2. **Flutter**: descarga el zip para tu arquitectura (Apple Silicon `arm64` o Intel `x64`) desde <https://docs.flutter.dev/get-started/install/macos>, extrae en `~/development/flutter` y agrega al PATH en `~/.zshrc`:
   ```bash
   export PATH="$HOME/development/flutter/bin:$PATH"
   ```
   Abre una terminal nueva y corre `flutter --version`. (Si usas Homebrew, `brew install --cask flutter` también sirve.)
3. **Android Studio**: instalador `.dmg` de <https://developer.android.com/studio>; luego `flutter doctor --android-licenses`.
4. **Docker Desktop para Mac**: elige el `.dmg` de tu chip en <https://docs.docker.com/desktop/setup/install/mac-install/>, ábrelo, acepta la licencia y espera "Engine running".
5. **Chrome** para Flutter Web.

---

## 4. Primer arranque (Windows y macOS)

```bash
git clone <url-del-repositorio> monedero
cd monedero
flutter pub get
dart run tool/doctor.dart
dart run tool/up.dart
```

`tool/up.dart` crea `.env` desde `.env.example` con secretos aleatorios, construye la API y levanta PostgreSQL, Mailpit y la API. Al final muestra:

- API: <http://localhost:8080/health>
- Correos (Mailpit): <http://localhost:8025>

Abre la app web:
```bash
cd apps/app
flutter run -d chrome --web-port 5000
```
El puerto **5000** importa: es el origen autorizado por CORS (`CORS_ALLOWED_ORIGINS` en `.env`).

---

## 5. Conectar Android a la API local

La API escucha en el puerto 8080 de la laptop. Cómo llega la app depende del dispositivo:

| Dispositivo | URL de la API | Cómo correr la app |
|---|---|---|
| Emulador Android | `http://10.0.2.2:8080` (automática) | `flutter run` |
| Teléfono por USB (**recomendado**) | `http://localhost:8080` vía `adb reverse` | ver abajo |
| Teléfono por Wi-Fi | `http://<IP-de-la-laptop>:8080` | ver abajo |

### Teléfono por USB con `adb reverse` (recomendado)
No depende de la red ni del firewall.
1. En el teléfono: *Ajustes* → *Acerca del teléfono* → toca 7 veces *Número de compilación* → en *Opciones de desarrollador* activa **Depuración USB**.
2. Conéctalo por USB y acepta la huella de la laptop. Verifica con `adb devices`.
3. Redirige el puerto y corre la app:
   ```bash
   adb reverse tcp:8080 tcp:8080
   cd apps/app
   flutter run --dart-define=API_BASE_URL=http://localhost:8080
   ```
   `adb reverse` se pierde al desconectar el cable: repítelo.

### Teléfono por Wi-Fi
1. Laptop y teléfono en la **misma red Wi-Fi** (las redes de invitados o de la universidad suelen aislar dispositivos; un hotspot del teléfono funciona).
2. Averigua la IP de la laptop:
   - Windows: `ipconfig` → "Dirección IPv4" del adaptador Wi-Fi (por ejemplo `192.168.1.50`).
   - macOS: `ipconfig getifaddr en0`.
3. Corre la app:
   ```bash
   cd apps/app
   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
   ```
4. Si el teléfono no llega, en Windows marca la red como **Privada** y permite el puerto 8080 en el firewall. Esto cambia la configuración de seguridad del equipo, así que hazlo tú, en PowerShell como administrador:
   ```powershell
   New-NetFirewallRule -DisplayName "Monedero API (desarrollo)" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Private
   ```
   En macOS, acepta el aviso del firewall o revisa *Ajustes del Sistema → Red → Firewall*.

> Las compilaciones *debug* permiten HTTP sin TLS (`usesCleartextTraffic` solo en los manifiestos `debug` y `profile`). En producción la API va por HTTPS con Caddy.

---

## 6. Solución de problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `docker : El término 'docker' no se reconoce` | La consola se abrió antes de instalar Docker | Abre una consola nueva |
| `failed to connect to the docker API … docker_engine` | Docker Desktop no está abierto | Ábrelo y espera "Engine running" |
| `docker-credential-desktop: executable file not found` | Igual que el anterior (PATH viejo) | Consola nueva |
| Docker pide WSL o falla al iniciar | WSL 2 no instalado o sin reiniciar | Paso 2.4 y reiniciar |
| "Virtualization support not detected" | Virtualización apagada en BIOS | Activar VT-x / AMD-V |
| El instalador de Docker falla con "no se encuentra la ruta" al lanzarse como administrador | Ruta del instalador demasiado larga | Copia el `.exe` a `C:\Temp` y ejecútalo de ahí |
| `port is already allocated` en 5432/8080/8025 | Otro programa usa el puerto (por ejemplo, un PostgreSQL instalado) | Cambia `POSTGRES_PORT`/`API_PORT`/`MAILPIT_UI_PORT` en `.env` |
| `flutter run -d chrome` falla con "Failed to establish connection with the application instance in Chrome" | El depurador no logra conectarse con Chrome (firewall o Chrome abierto desde otra herramienta) | Sirve la app sin depurador: `flutter run -d web-server --release --web-port 5000 --web-hostname localhost` y abre <http://localhost:5000> en tu navegador |
| La app web dice "Sin conexión con la API" | La app no corre en el puerto 5000 o la API está apagada | `flutter run -d chrome --web-port 5000`; `dart run tool/up.dart` |
| El teléfono no llega a la API | Red aislada o firewall | Usa `adb reverse` (sección 5) |
| `version solving failed … test_api` | Se subió `test` por encima de lo que fija Flutter | Mantén `test: ^1.31.1` hasta actualizar Flutter |
| Acentos raros (`ConfiguraciÃ³n`) en la consola | Página de códigos antigua en PowerShell 5.1 | Usa Windows Terminal o ejecuta `chcp 65001` |
| Primera compilación Android muy lenta | Gradle descarga dependencias | Es normal la primera vez (unos 3–4 minutos) |
| `Warning: SDK processing. This version only understands SDK XML versions up to 3…` | Android Studio y las herramientas de línea de comandos son de fechas distintas | Inofensivo; se quita actualizando *Android SDK Command-line Tools* en el SDK Manager |
| Errores raros de archivos bloqueados | Repositorio dentro de OneDrive | Mueve el repositorio a `C:\src` |
| Quiero empezar la base de cero | Datos viejos en el volumen | `dart run tool/down.dart --borrar-datos` y `dart run tool/up.dart` |
