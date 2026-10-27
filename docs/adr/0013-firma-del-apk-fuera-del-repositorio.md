# ADR 0013: Firma del APK release con un keystore fuera del repositorio

- **Estado:** Aceptado
- **Fecha:** 2026-10-25
- **Autores:** David Alexis Navarrete Gálvez (dn223), Claude Code (Claude Opus 5.5)

## Contexto

La Fase 6 entrega un APK instalable. Android exige que cada APK esté firmado y que las actualizaciones lleven la misma firma; si la llave se pierde, la app instalada no se puede actualizar (hay que desinstalarla). La llave es un secreto: no puede subirse al repositorio (AGENTS.md § 11). Al mismo tiempo, cualquier integrante debe poder compilar un release para probar.

## Decisión

- El keystore (`monedero-release.jks`, PKCS12, RSA 2048, alias `monedero`, 10,000 días) y sus contraseñas viven en `~/.monedero/` de quien firma, fuera del repositorio. `android/app/build.gradle.kts` lee `~/.monedero/key.properties` (o `android/key.properties`, que git ignora).
- Si no encuentra ese archivo, el release se firma con la llave de depuración, así nadie queda bloqueado para compilar; ese APK sirve para probar, no para distribuir.
- Los íconos se generan desde `brand.dart` con `apps/app/tool/icons/generate_icons_test.dart`, sin programas de imágenes externos.

## Consecuencias

- Ningún secreto entra al repositorio; la firma oficial la hace quien tenga el keystore.
- **Hay que respaldar `~/.monedero/`** (por ejemplo, en un gestor de contraseñas del equipo). Sin ese respaldo, perder la laptop obliga a desinstalar la app en todos los celulares.
- Para publicar en Google Play (fuera de alcance) se usaría la firma de apps de Play con esta llave como llave de carga.
