# Nombre de la app

El equipo aún no decide el nombre. Mientras tanto se usa el nombre provisional **"Monedero"** y el identificador interno `monedero`.

## 1. Qué cambia y qué no

| Elemento | Valor actual | ¿Cambia con el nombre? |
|---|---|---|
| Nombre visible, colores y logotipo | `apps/app/lib/brand/brand.dart` | **Sí**: es el único archivo de código que se toca |
| Etiqueta de Android, título web, íconos | Ver la lista de la sección 5 | Sí (configuración, no código) |
| Identificador del paquete Android / `applicationId` | `sv.edu.ufg.monedero` | **No, nunca** |
| Nombre del paquete Dart de la app | `monedero` | No |
| Paquetes internos | `monedero_core`, `monedero_api` | No |
| Base de datos, roles y contenedores | `monedero`, `monedero_owner`, `monedero_app` | No |

### Por qué no se cambia el identificador del paquete

- **Android identifica la app por su `applicationId`.** Si cambia, el sistema la trata como **otra app**: no se actualiza encima de la anterior, se pierden los datos guardados y hay que desinstalar e instalar.
- En Google Play el identificador es **permanente**: una vez publicado no se puede cambiar.
- Las firmas de compilación, las configuraciones de NFC y las integraciones futuras quedan ligadas a ese identificador.
- Cambiarlo obliga a mover carpetas de Kotlin (`sv/edu/ufg/monedero`) y editar Gradle sin ningún beneficio para el usuario, que nunca lo ve.
- `sv.edu.ufg.monedero` es neutral: describe la institución y la función, no la marca.

## 2. Criterios

Un buen nombre:

- [ ] Es **corto**: idealmente 2 o 3 sílabas, máximo 12 letras.
- [ ] Es **fácil de pronunciar y escribir en español**, sin letras ambiguas al dictarlo.
- [ ] **No es una marca registrada** ni se parece a una.
- [ ] **No se confunde con billeteras o bancos existentes en El Salvador** (bancos, cooperativas, billeteras digitales, Chivo, tarjetas de supermercados).
- [ ] Tiene **dominio disponible** (`.com`, `.sv` o `.app`) y nombre de usuario libre en redes, por si el proyecto continúa.
- [ ] Funciona como ícono y en pantallas pequeñas.
- [ ] No tiene connotaciones negativas ni dobles sentidos.

Verificaciones sugeridas: búsqueda web, Google Play, registro de marcas del CNR de El Salvador y disponibilidad del dominio.

## 3. Candidatos

| Nombre | Propuesto por | Significado | Pros / contras |
|---|---|---|---|
| | | | |
| | | | |
| | | | |

## 4. Proceso de decisión

1. **Propuestas:** cada integrante propone **hasta 3 nombres**, abriendo un issue con la plantilla *"Propuesta de nombre"* o agregando filas a la tabla anterior.
2. **Revisión:** cada propuesta se revisa contra los criterios de la sección 2; las que no los cumplen se descartan con una breve explicación.
3. **Discusión:** en una reunión o en un issue de votación, se comentan las finalistas.
4. **Votación:** cada integrante ordena sus 3 favoritas (3 puntos la primera, 2 la segunda, 1 la tercera). Gana la de más puntos; si hay empate, se vota de nuevo solo entre las empatadas.
5. **Registro:** la decisión se documenta como **ADR 0009** en `docs/adr/` (contexto, nombre elegido, alternativas descartadas y por qué).

## 5. Lista de verificación para aplicar el nombre elegido

- [ ] `apps/app/lib/brand/brand.dart`: `appName`, `tagline`, `seedColor` y logotipo.
- [ ] Ícono de la app: `apps/app/android/app/src/main/res/mipmap-*/ic_launcher.png` y `apps/app/web/icons/*`, `apps/app/web/favicon.png`. Se regeneran desde `brand.dart` con `cd apps/app && flutter test tool/icons/generate_icons_test.dart --update-goldens` (ver `docs/android.md`).
- [ ] Etiqueta de Android: `android:label` en `apps/app/android/app/src/main/AndroidManifest.xml`.
- [ ] Título web: `<title>` y `apple-mobile-web-app-title` en `apps/app/web/index.html`; `name`, `short_name` y colores en `apps/app/web/manifest.json`.
- [ ] `README.md` (título y descripción).
- [ ] Documentación en `docs/` que mencione el nombre visible (no los identificadores).
- [ ] `AGENTS.md`, sección 1.
- [ ] `MAIL_FROM` en `.env.example` y en `deploy/.env.prod.example`.
- [ ] ADR 0009 creado y enlazado en `docs/adr/README.md`.
- [ ] Entrada en `CHANGELOG.md` y en `docs/BITACORA.md`.
- [ ] **No** se tocaron `applicationId`, `namespace`, nombres de paquetes Dart ni nombres de base de datos.
