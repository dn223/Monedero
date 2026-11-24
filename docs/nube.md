# Trabajar en la nube (desde el celular)

Claude Code puede trabajar en una máquina en la nube que clona este repositorio de GitHub. No necesita que tu PC esté encendida.

## Configurarlo una vez

1. En <https://claude.ai/code> conecta tu cuenta de GitHub.
2. Crea un entorno:
   - **Acceso a la red:** *Limited* con **Allow package managers** (el valor por defecto).
   - **Setup script:** pega el contenido de [`tool/nube/instalar.sh`](../tool/nube/instalar.sh).
   - **Variables de entorno:** ninguna. No pegues tu `.env`.
3. Abre una sesión con el repositorio `dn223/Monedero` y elige la rama de trabajo. `main` va atrasada.

Desde el celular: pestaña **Code** de la app de Claude, mismo entorno y misma rama.

## Al empezar cada sesión

```bash
flutter pub get
dart run tool/up.dart
dart run tool/check.dart
```

`tool/up.dart` crea un `.env` nuevo con secretos de esa máquina. Si Docker no responde, pídele a Claude que inicie `dockerd`.

## Qué no hay en la nube

- Tu base de datos local, tu `.env` y el keystore del APK.
- Android SDK: el APK se compila en la PC.
- Un link para el ingeniero: `tool/share.dart` se usa desde la PC ([exposición](exposicion.md)).
- Lo que no esté en GitHub: haz push antes de cambiar de máquina.

## Tiempo de instalación

Flutter pesa 1.5 GB. Si el setup script pasa de unos 5 minutos, la nube no lo guarda en caché y lo repite en cada sesión. En la PC tardó 23 minutos, casi todo en la descarga; en la nube falta medirlo.

`tool/nube/instalar.sh` se probó en un contenedor Ubuntu 24.04; el entorno de Claude en la nube todavía no.
