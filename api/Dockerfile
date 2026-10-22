# Imagen de la API de Monedero. Se construye desde la raíz del repositorio:
#   docker build -f api/Dockerfile .
# (docker compose ya lo hace con `dart run tool/up.dart`).

# --- Compilación ----------------------------------------------------------
FROM dart:3.13.6 AS build
WORKDIR /src

# Primero solo los pubspec, para aprovechar la caché de capas de Docker.
COPY pubspec.yaml pubspec.lock ./
COPY packages/core/pubspec.yaml packages/core/
COPY api/pubspec.yaml api/

# La imagen de Dart no trae Flutter, así que se quita la app del workspace y
# se resuelven solo `api` y `packages/core` (ver docs/adr/0007).
RUN sed -i '\#^  - apps/app$#d' pubspec.yaml && dart pub get

COPY packages/core packages/core
COPY api api
RUN dart pub get --offline \
 && mkdir -p /out \
 && dart compile exe api/bin/server.dart -o /out/server

# --- Ejecución ------------------------------------------------------------
# `scratch` + el runtime mínimo que provee la imagen oficial de Dart.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server

EXPOSE 8080
ENTRYPOINT ["/app/server"]
