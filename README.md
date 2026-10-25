# Monedero

**Monedero electrónico prepago recargable de circuito cerrado**: como la tarjeta prepago de un supermercado. Cada tarjeta tiene un número único y un saldo que se recarga en caja y se gasta en compras dentro del comercio.

Prototipo de demostración del proyecto de **Gestión de la Calidad del Software**, Facultad de Ingeniería y Sistemas, **Universidad Francisco Gavidia (UFG)**. Aunque es académico, se diseña y documenta como un sistema real que maneja dinero de clientes.

> "Monedero" es un nombre provisional. Ver [NAMING.md](NAMING.md).

<p align="center">
  <img src="docs/img/fase6-titular.jpg" alt="Titular: tarjeta virtual con saldo, pagar en caja y movimientos" width="420">
  <img src="docs/img/fase6-caja.jpg" alt="Caja: comprobante tipo ticket de una recarga" width="420">
</p>
<p align="center">
  <img src="docs/img/fase6-admin.jpg" alt="Administración: saldo en circulación, conciliación y gráfico de 14 días" width="420">
  <img src="docs/img/fase6-inicio-celular.jpg" alt="Pantalla inicial en un celular, tema claro" width="200">
</p>
<p align="center"><em>Fase 6: titular, caja y administración conectados a la API real (web y celular, tema claro y oscuro).</em></p>

| Componente | Tecnología |
|---|---|
| App (Android + Web) | Flutter, Riverpod, go_router, Material 3 |
| API | Dart, `shelf` + `shelf_router` |
| Base de datos | PostgreSQL 17 |
| Código compartido | `packages/core` (pub workspaces) |
| Entorno local | Docker Compose: PostgreSQL, API (sirve también la app web) y Mailpit |
| Exposición por link | Quick tunnel de Cloudflare en Docker (gratis, sin cuenta) |
| Producción (solo preparada) | VPS Contabo, Caddy, pgBackRest → Backblaze B2 |

## Inicio rápido

Requisitos: Git, Flutter, Docker Desktop y Chrome ([guía de instalación](docs/setup.md)).

```bash
git clone <url-del-repositorio> monedero && cd monedero
flutter pub get
dart run tool/up.dart
cd apps/app && flutter build web
```

- App web y API: <http://localhost:8080> (para desarrollar con recarga en caliente: `cd apps/app && flutter run -d chrome --web-port 5000`)
- Correos de verificación (Mailpit): <http://localhost:8025>
- Detener todo: `dart run tool/down.dart`
- Verificar antes de un commit: `dart run tool/check.dart`

**Link público para el ingeniero** (web y celular, sin estar en la laptop):

```bash
dart run tool/share.dart
```

Compila la web, levanta todo con un túnel de Cloudflare e imprime `https://….trycloudflare.com` con un QR. Guía paso a paso: [docs/exposicion.md](docs/exposicion.md).

En Android: APK con `cd apps/app && flutter build apk --release` ([docs/android.md](docs/android.md)); la app permite pegar o escanear la dirección del servidor sin recompilar. Emulador y teléfono por cable: [setup.md § 5](docs/setup.md#5-conectar-android-a-la-api-local).

**Demostración de los 8 pasos** (registrar, emitir, recargar $20, cobrar $7.35, sobregiro, pérdida, reposición y conciliación): desde la app, con el guion de [docs/demo.md](docs/demo.md), o por consola contra la API real:

```bash
dart run tool/demo.dart --pausa
```

## Credenciales de demostración

Las crea `dart run tool/up.dart` (o `dart run tool/seed.dart`). En modo demo la app las ofrece en cada pantalla de inicio de sesión ("Entrar como…").

| Rol | Usuario | Contraseña | PIN |
|---|---|---|---|
| Administrador | `admin@monedero.local` | `Admin1234` | — |
| Cajero | `cajero@monedero.local` | `Cajero1234` | — |
| Titular | `ana@demo.local` / `bruno@demo.local` | `Titular1234` | `1234` |

Solo para la demo local; nunca se usan en producción.

## Estado

**Fases 1 a 6 terminadas** (entrega de esta semana, pendiente de revisión del equipo): la app conectada a la API en los tres roles, administración, renovación de sesión, límites de solicitudes, APK firmado y exposición por link. Siguen la Fase 7 (tarjetas NFC físicas) y la Fase 8 (producción). Ver [docs/ROADMAP.md](docs/ROADMAP.md).

## Documentación

| Documento | Contenido |
|---|---|
| [AGENTS.md](AGENTS.md) | Instrucciones para cualquier IA y persona: comandos, invariantes, convenciones |
| [docs/setup.md](docs/setup.md) | Instalación en Windows (incluido LTSC) y macOS |
| [docs/architecture.md](docs/architecture.md) | Componentes y flujo de una operación |
| [docs/domain.md](docs/domain.md) | Reglas de negocio, estados y glosario |
| [docs/api.md](docs/api.md) · [openapi.yaml](docs/openapi.yaml) | Endpoints, errores y ejemplos |
| [docs/database.md](docs/database.md) | Modelo de datos, migraciones y permisos |
| [docs/testing.md](docs/testing.md) | Pruebas y qué demuestran |
| [docs/demo.md](docs/demo.md) | Guion de demostración de 10 minutos |
| [docs/exposicion.md](docs/exposicion.md) | Día de la exposición: link público para el ingeniero |
| [docs/android.md](docs/android.md) | APK: compilar, firmar e instalar |
| [docs/nfc.md](docs/nfc.md) | Plan para tarjetas físicas MIFARE Classic |
| [docs/deploy-contabo.md](docs/deploy-contabo.md) | Producción (solo preparada) |
| [docs/adr/](docs/adr/) | Decisiones técnicas |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Ramas, commits y revisión |

## Equipo

- Kevin Alexander González Calderón
- Cesar Rodrigo Cerón Cruz
- David Alexis Navarrete Gálvez
- Leonardo *(apellidos por completar)*
- Bayron *(apellidos por completar)*
- Steven *(apellidos por completar)*
