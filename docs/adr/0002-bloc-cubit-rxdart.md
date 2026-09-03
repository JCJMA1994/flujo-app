# ADR 0002 — BLoC + Cubit con RxDart

**Estado:** aceptado
**Fecha:** 2026-09-01

## Contexto

La app tiene dos perfiles de estado muy distintos. Por un lado pantallas simples que solo cargan y muestran. Por otro, un listado con búsqueda, filtros múltiples y un stream reactivo de base de datos, más un pipeline de captura que consume un stream de notificaciones del sistema.

## Decisión

BLoC donde hay vocabulario de eventos y necesidad de transformers por evento. Cubit donde hay una o dos acciones simples. RxDart para composición de streams.

Los transformers usados: `debounce` en búsqueda, `restartable` en filtros, `sequential` en escrituras.

## Alternativas descartadas

**Riverpod** — excelente y más conciso, pero el equipo ya conoce Bloc y `bloc_test` da una ergonomía de testeo difícil de igualar para máquinas de estado complejas.

**setState / ChangeNotifier** — insuficiente para componer streams de Drift con filtros reactivos.

## Consecuencias

**A favor:** transiciones de estado explícitas y auditables vía `BlocObserver`. Testeo declarativo con `blocTest`.

**En contra:** más boilerplate que Riverpod. RxDart agrega una curva de aprendizaje: `switchMap` frente a `flatMap` es una distinción que hay que entender o se producen fugas de suscripciones.
