# Registros de decisiones de arquitectura (ADR)

Un ADR por decisión técnica, con el formato de [0000-plantilla.md](0000-plantilla.md): **contexto, decisión y consecuencias**. Numeración consecutiva de 4 dígitos. Un ADR aceptado no se reescribe: si la decisión cambia, se crea uno nuevo que lo reemplaza.

| # | Decisión | Estado |
|---|---|---|
| [0001](0001-postgresql-frente-a-firestore.md) | PostgreSQL en lugar de Firestore | Aceptado |
| [0002](0002-api-en-dart-con-shelf.md) | API en Dart con `shelf` + `shelf_router` (no Dart Frog) | Aceptado |
| [0003](0003-tarjetas-simuladas.md) | Tarjetas simuladas en la demo, preparadas para NFC | Aceptado |
| [0004](0004-montos-en-centavos.md) | Montos como enteros en centavos | Aceptado |
| [0005](0005-sqlite-no-es-fuente-del-saldo.md) | SQLite (u otra base local) no es fuente del saldo | Aceptado |
| [0006](0006-riverpod-y-go-router-sin-codegen.md) | Riverpod y go_router sin generación de código | Aceptado |
| [0007](0007-monorepo-con-pub-workspaces.md) | Monorepo con pub workspaces | Aceptado |
| [0008](0008-idempotencia-y-migraciones.md) | Semántica de idempotencia, migrador con checksum y sembrado en Dart | Aceptado |
| 0009 | Nombre definitivo de la app (ver `NAMING.md`) | Pendiente |
| [0010](0010-renovacion-de-sesion-y-limite-de-solicitudes.md) | Renovación de sesión con tokens rotativos y límite de solicitudes en memoria | Aceptado |
| [0011](0011-exposicion-por-link-con-tunel-y-web-en-la-api.md) | Exposición por link: web servida por la API y quick tunnel de Cloudflare | Aceptado |
| [0012](0012-reinicio-de-la-demo-por-api.md) | Reinicio de la demo por API con el dueño del esquema, solo en modo demo | Aceptado |
| [0013](0013-firma-del-apk-fuera-del-repositorio.md) | Firma del APK release con un keystore fuera del repositorio | Aceptado |
| [0014](0014-modulos-activables-y-asistente.md) | Módulos activables desde administración y asistente virtual por reglas | Aceptado |
| [0015](0015-caja-con-codigo-y-sin-datos-de-ejemplo.md) | La caja entra con su código y la base empieza solo con administración | Aceptado |
