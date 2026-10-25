# App Android: compilar, firmar e instalar

La misma app Flutter corre en Android. La Fase 6 la deja **instalable** con ícono propio, nombre visible "Monedero" (provisional, ver [NAMING.md](../NAMING.md)) y APK release firmado.

## Compilar el APK

Desde `apps/app`:

```bash
flutter build apk --release
```

Resultado: `apps/app/build/app/outputs/flutter-apk/app-release.apk` (≈70 MB, sirve en cualquier celular Android). Para un archivo más liviano por arquitectura (≈25 MB el de `arm64-v8a`, que usan casi todos los celulares actuales):

```bash
flutter build apk --release --split-per-abi
```

## Firma

Ver [ADR 0013](adr/0013-firma-del-apk-fuera-del-repositorio.md).

- El keystore está **fuera del repositorio**, en la carpeta personal de quien firma:
  - `~/.monedero/monedero-release.jks` (en Windows, `C:\Users\<usuario>\.monedero\`)
  - `~/.monedero/key.properties` con `storeFile`, `storePassword`, `keyAlias` y `keyPassword`
- `android/app/build.gradle.kts` lo busca ahí (o en `android/key.properties`, que git ignora). Si no lo encuentra, firma con la llave de depuración: ese APK sirve para probar, pero no actualiza uno firmado con la llave oficial.
- **Respaldar `~/.monedero/`** en un lugar seguro del equipo. Si se pierde, no se puede actualizar la app instalada; hay que desinstalarla e instalar de nuevo.
- Para crear un keystore nuevo (solo si no existe uno oficial):
  ```bash
  keytool -genkeypair -keystore ~/.monedero/monedero-release.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias monedero
  ```
- Verificar la firma de un APK:
  ```bash
  apksigner verify --print-certs apps/app/build/app/outputs/flutter-apk/app-release.apk
  ```
  (`apksigner` está en `Android/Sdk/build-tools/36.0.0`.) Debe decir `CN=Monedero UFG`.

## Instalar en un celular

1. Copiar el APK al celular (cable, Drive o WhatsApp como documento) o, con depuración USB: `flutter install --release` desde `apps/app`.
2. Abrirlo y permitir "Instalar apps de origen desconocido" si el celular lo pide.
3. En la app: pantalla inicial → ícono de servidor (arriba a la derecha) → escribir o escanear la dirección del servidor → **Probar y guardar**.

| Dónde está la API | Dirección |
|---|---|
| Link de la exposición | El `https://….trycloudflare.com` que imprime `dart run tool/share.dart` |
| Laptop en la misma Wi-Fi | `http://<IP-de-la-laptop>:8080` |
| Emulador | `http://10.0.2.2:8080` (predeterminada) |

No hace falta recompilar para cambiar de servidor. La app permite `http` (laptop y emulador); el link del túnel ya es `https`.

## Ícono

Se genera desde el logotipo de `lib/brand/brand.dart`, para Android (`mipmap-*`) y la web (`web/icons`, `favicon.png`):

```bash
cd apps/app
flutter test tool/icons/generate_icons_test.dart --update-goldens
```

Al cambiar el color o el logotipo de la marca, se vuelve a correr y se suben los PNG nuevos.

## Permisos

- `INTERNET`: hablar con la API (no hay operación sin conexión).
- `CAMERA`: escanear el QR de la tarjeta, de la caja y del link (lo declara `mobile_scanner`).
