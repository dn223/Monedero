# ADR 0005: SQLite (u otra base local) no es fuente del saldo

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

Una opción tentadora es guardar el saldo en SQLite dentro del teléfono (o en la tarjeta) para operar sin conexión y sincronizar después. En un monedero prepago eso permite **doble gasto**: dos cajas sin conexión pueden cobrar el mismo saldo, y un teléfono manipulado puede alterar su copia local. Resolver los conflictos después requiere reglas de compensación, deuda del cliente y auditoría que exceden el proyecto y que el comercio no quiere asumir.

## Decisión

- **PostgreSQL en el servidor es la única fuente de verdad del saldo** (ADR 0001).
- Ninguna base local (SQLite, `shared_preferences`, archivos ni la memoria del chip) guarda un saldo que se use para decidir una operación.
- La app del titular puede **cachear** el último saldo solo para mostrarlo, marcado como "no actualizado" con la hora de la consulta.
- Toda operación que cambia saldo exige conexión con la API (regla 12). Sin conexión, la caja muestra un error claro y no cobra.

## Consecuencias

- ✅ Imposible gastar dos veces el mismo saldo; la conciliación siempre cuadra.
- ✅ Perder o manipular un teléfono no altera saldos.
- ⚠️ Sin Internet en el comercio no se puede cobrar con la tarjeta. Se acepta: el comercio usa otros medios de pago en ese caso.
- ⚠️ La disponibilidad de la API pasa a ser crítica, lo que justifica el monitoreo y los respaldos de `deploy-contabo.md`.
