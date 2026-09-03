# ADR 0004 — Offline-first con Drift como fuente de verdad

**Estado:** aceptado
**Fecha:** 2026-09-01

## Contexto

La app se usa en movimiento, en un mercado donde la cobertura móvil es irregular. Una app de gastos que muestra un spinner en el metro se desinstala.

## Decisión

La base local es la fuente de verdad para la UI. Toda escritura va primero a Drift con `syncedAt = null` y se sube después en segundo plano. Los borrados son lógicos (`deleted = true`) para poder propagarlos al servidor.

La UI se suscribe a `watch()` de Drift, no al resultado de la escritura.

## Consecuencias

**A favor:** la UI responde de inmediato. Funciona sin red. El estado nunca se desincroniza porque hay un solo punto de verdad.

**En contra:** hay que gestionar conflictos de sincronización. Por ahora es last-write-wins, lo cual es aceptable con un usuario y un dispositivo, pero se romperá cuando haya multi-dispositivo. Requiere una decisión futura sobre vector clocks o timestamps del servidor.

Las filas borradas se acumulan; hará falta una purga periódica de registros con `deleted = true` ya sincronizados.
