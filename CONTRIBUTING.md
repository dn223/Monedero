# Cómo contribuir

Antes de empezar, lee [AGENTS.md](AGENTS.md). Aplica a personas y a IA.

## 1. Ramas

- **`main`** está protegida: solo recibe cambios por pull request aprobado y con la CI en verde. Nadie hace push directo.
- Crea una rama desde `main` actualizada:

| Prefijo | Uso | Ejemplo |
|---|---|---|
| `feat/` | Funcionalidad nueva | `feat/recarga-en-caja` |
| `fix/` | Corrección de error | `fix/saldo-cache-no-actualizado` |
| `docs/` | Solo documentación | `docs/guia-contabo` |
| `test/` | Solo pruebas | `test/debitos-concurrentes` |
| `chore/` | Mantenimiento, dependencias, CI | `chore/actualizar-flutter` |
| `refactor/` | Cambio interno sin cambiar el comportamiento | `refactor/modulo-cards` |

Nombres en minúsculas, con guiones y cortos.

```bash
git switch main
git pull
git switch -c feat/mi-cambio
```

## 2. Commits: Conventional Commits

Formato: `tipo(alcance): descripción en español, en imperativo y minúsculas`

| Tipo | Cuándo |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección |
| `docs` | Documentación |
| `test` | Pruebas |
| `refactor` | Reestructuración sin cambio funcional |
| `chore` | Mantenimiento, configuración, dependencias |
| `ci` | GitHub Actions |
| `build` | Docker, compilación |

Alcances sugeridos: `api`, `app`, `core`, `db`, `tool`, `deploy`, `docs`.

Ejemplos:
```text
feat(api): agrega débito idempotente con SELECT FOR UPDATE
fix(app): marca el saldo en caché como no actualizado
docs(adr): registra la decisión de usar shelf
test(api): prueba 1000 débitos concurrentes
```

- Un commit = un cambio coherente. No mezcles formato masivo con lógica.
- Si un cambio rompe compatibilidad (API o esquema), agrega `!` (`feat(api)!: …`) y explica en el cuerpo.
- Si una IA ayudó, puedes indicarlo con `Co-Authored-By:` al final del mensaje.

## 3. Antes de abrir un pull request

```bash
dart run tool/check.dart
```

Debe terminar en **"Todo en verde."** Además, cumple la definición de terminado de `AGENTS.md` (sección 7): documentación, `docs/openapi.yaml`, `CHANGELOG.md` y `docs/BITACORA.md` al día.

La plantilla del pull request ([.github/pull_request_template.md](.github/pull_request_template.md)) se llena automáticamente al abrirlo en GitHub.

## 4. Cómo revisar un pull request

Quien revisa no es quien escribió el código (ni la IA que lo generó).

1. **Lee la descripción y la bitácora**: ¿qué problema resuelve? ¿hay ADR si hubo decisión?
2. **Invariantes de dinero** (`AGENTS.md`, sección 4), lo más importante:
   - ¿Algún `double`, `num` o `NUMERIC` para dinero?
   - ¿Toda operación que cambia saldo usa transacción, `FOR UPDATE` e `Idempotency-Key`?
   - ¿Alguna migración vieja editada? ¿Algún permiso o trigger debilitado?
   - ¿Las reglas se validan en la API y no solo en la app?
3. **Pruebas:** ¿hay pruebas nuevas para lo nuevo? ¿alguna desactivada o con `skip`?
4. **Seguridad:** ¿secretos en el código? ¿datos sensibles en logs o respuestas de error? ¿modo demo activado por defecto?
5. **Prueba manual:** baja la rama, `dart run tool/up.dart` y prueba el flujo.
6. **Documentación:** ¿`api.md`, `openapi.yaml`, `database.md` y `CHANGELOG.md` reflejan el cambio?
7. Aprueba solo si entiendes el cambio. Comenta con propuestas concretas; distingue lo obligatorio ("bloqueante:") de lo opcional ("sugerencia:").

## 5. Configurar la protección de `main` en GitHub

*Settings → Branches → Add branch ruleset* para `main`:
- Requerir pull request antes de fusionar, con **1 aprobación**.
- Requerir que pase el check **CI / check**.
- Bloquear force push y borrado de la rama.
