#!/usr/bin/env bash
# Instala Flutter en el entorno en la nube de Claude Code (Ubuntu 24.04, root).
#
# Se pega en el campo "Setup script" del entorno (claude.ai/code): corre antes
# de abrir la sesión y no necesita el repositorio. Guía: docs/nube.md.
set -euo pipefail

# La misma versión que .github/workflows/ci.yml. El SHA-256 es el oficial de
# releases_linux.json; si cambias la versión, cambia los dos.
FLUTTER_VERSION=3.47.7
FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
FLUTTER_HOME=/opt/flutter
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# Lo que Flutter necesita para descomprimirse y correr sus herramientas.
faltan=()
for comando in curl git unzip xz; do
  command -v "$comando" >/dev/null || faltan+=("$comando")
done
if ((${#faltan[@]})); then
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates git unzip xz-utils >/dev/null
fi

if [[ "$(cat "$FLUTTER_HOME/.version-nube" 2>/dev/null)" != "$FLUTTER_VERSION" ]]; then
  archivo="$(mktemp)"
  curl -fsSL --retry 3 -o "$archivo" "$URL"
  echo "$FLUTTER_SHA256  $archivo" | sha256sum -c --quiet -
  rm -rf "$FLUTTER_HOME"
  # Sin --no-same-owner, git rechaza la carpeta por tener otro dueño.
  tar -xJf "$archivo" -C "$(dirname "$FLUTTER_HOME")" --no-same-owner
  rm -f "$archivo"
  echo "$FLUTTER_VERSION" >"$FLUTTER_HOME/.version-nube"
fi

# Enlaces en una carpeta que ya está en el PATH de toda sesión.
ln -sf "$FLUTTER_HOME/bin/flutter" /usr/local/bin/flutter
ln -sf "$FLUTTER_HOME/bin/dart" /usr/local/bin/dart
git config --global --get-all safe.directory | grep -qx "$FLUTTER_HOME" ||
  git config --global --add safe.directory "$FLUTTER_HOME"

flutter config --no-analytics >/dev/null
flutter --version
