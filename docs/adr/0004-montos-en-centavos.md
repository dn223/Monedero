# ADR 0004: Montos como enteros en centavos

- **Estado:** Aceptado
- **Fecha:** 2026-10-21
- **Autores:** equipo · Claude Code

## Contexto

Los números de punto flotante (`double` en Dart, `REAL`/`DOUBLE PRECISION` en SQL, `number` en JSON interpretado como flotante) no representan exactamente valores como 0.10 o 7.35. Sumas repetidas generan diferencias de centavos que rompen la conciliación (regla 7). `NUMERIC` en PostgreSQL es exacto, pero obliga a convertir a un tipo decimal en Dart, donde no hay uno nativo, y es fácil que alguien termine usando `double`.

## Decisión

- Todo monto se representa como **entero en centavos**: `BIGINT` en PostgreSQL, `int` en Dart y entero en JSON con sufijo `Cents` (`"amountCents": 735` = $7.35).
- Se prohíbe `double`, `num`, `NUMERIC`, `DECIMAL`, `REAL`, `FLOAT` y `MONEY` para dinero en cualquier capa.
- La conversión a texto (`$7.35`) ocurre **solo al mostrar**, en la app, con formato USD de dos decimales.
- `tool/check.dart` incluye una guardia automática que falla si encuentra esos tipos junto a nombres de dinero o en las migraciones.

## Consecuencias

- ✅ Aritmética exacta; la conciliación puede exigir diferencia **cero**.
- ✅ `BIGINT` llega a ±9.2 × 10¹⁸ centavos, muy por encima de cualquier saldo.
- ✅ Validaciones simples: `amountCents % 500 == 0` para recargas.
- ⚠️ La entrada de montos en la app debe convertir texto a centavos sin pasar por `double` (se implementa en `core` con pruebas).
- ⚠️ La guardia automática es una red de seguridad, no reemplaza la revisión de código.
