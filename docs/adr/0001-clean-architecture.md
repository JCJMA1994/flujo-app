# ADR 0001 — Clean Architecture por feature

**Estado:** aceptado
**Fecha:** 2026-09-01

## Contexto

La app va a crecer en features poco relacionados entre sí: transacciones, captura automática, chat con IA, presupuestos, reportes. Una estructura por tipo de archivo (`models/`, `screens/`, `services/`) escala mal: para tocar una feature terminas abriendo cinco carpetas distintas.

## Decisión

Estructura feature-first con tres capas dentro de cada feature. Las dependencias apuntan hacia adentro y `domain` queda en Dart puro.

## Consecuencias

**A favor:** cada feature es un módulo casi autónomo, extraíble a un paquete si hiciera falta. El dominio es testeable sin Flutter. Cambiar de motor de base de datos toca una carpeta.

**En contra:** más archivos y más ceremonia para un CRUD simple. Un desarrollador nuevo tarda más en ubicarse. Aceptamos el costo porque la app tiene lógica de negocio real (interpretación de notificaciones, reglas de usuario, sincronización), no es un cliente REST delgado.
