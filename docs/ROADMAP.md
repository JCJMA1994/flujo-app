# Roadmap

Orden pensado para tener algo usable lo antes posible y validar la parte difícil temprano.

## 1. Base local (hecho en este scaffolding)

CRUD de transacciones con Drift, dashboard con agregaciones, offline puro. Sin backend, sin IA. Ya es una app de gastos manual funcional.

## 2. Captura en Android

Permiso de notificaciones, parsers de BCP, Interbank, BBVA y Yape. Aquí ya hay producto: es el momento de ponerlo en manos de diez personas reales y medir cuántas notificaciones se reconocen.

La métrica que importa es `unrecognizedCount`. Dice exactamente qué banco falta soportar.

## 3. Autenticación y sincronización

Feature `auth`, endpoint de sync, resolución last-write-wins. Habilita cambiar de teléfono sin perder el historial.

## 4. Fallback de IA

`/v1/capture/interpret` en el backend. Solo después de tener los parsers deterministas cubriendo lo común, porque si no se paga IA por cosas que una regex resuelve gratis.

## 5. Reglas del usuario

UI para crear reglas y, mejor todavía, inferirlas: si el usuario recategoriza el mismo comercio tres veces, proponer la regla en vez de esperar a que la escriba.

## 6. Captura en iOS

Gmail API con OAuth y Pub/Sub. Es el trabajo más pesado de backend y la peor experiencia de onboarding, por eso va después de validar en Android.

## 7. Insights y detección de recurrentes

Suscripciones fijas, proyección de gasto a fin de mes, alertas por categoría. Todo esto es SQL sobre datos que ya se tienen: no necesita IA.

## 8. Chat conversacional

"¿En qué gasté más este mes?" con contexto de las transacciones del usuario. Va último porque es lo más vistoso y lo menos necesario.

## Deuda conocida

- Parsers duplicados entre app y servidor
- Sin resolución real de conflictos de sincronización
- Sin purga de filas con `deleted = true`
- Sin refresh de token
- Sin tests de integración
