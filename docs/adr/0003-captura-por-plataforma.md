# ADR 0003 — Captura de gastos dividida por plataforma

**Estado:** aceptado
**Fecha:** 2026-09-01

## Contexto

La propuesta de valor del producto es que el usuario no anote nada. Eso exige leer notificaciones bancarias. Android lo permite mediante `NotificationListenerService`. iOS no lo permite de ninguna forma: no existe API pública para que una app lea notificaciones de otra, y no la habrá.

## Decisión

Dos caminos de captura tras una misma interfaz:

- **Android:** lectura en dispositivo, con lista blanca de paquetes bancarios. El texto se procesa localmente.
- **iOS:** captura del lado del servidor, conectando Gmail API (con `watch` sobre Pub/Sub) o WhatsApp Cloud API por webhook.

El contrato `NotificationListenerDataSource` se satisface en iOS con `NoopNotificationListener`, que reporta `isSupported == false`. La UI ramifica una sola vez, en el onboarding.

## Consecuencias

**A favor:** el resto de la app ignora la diferencia. Agregar una tercera vía de captura no obliga a tocar presentación.

**En contra:** la experiencia en iOS es peor: requiere conectar una cuenta de correo, lo cual es más fricción y más sensible en términos de privacidad. Y obliga a mantener backend desde el día uno, cuando en Android la app podría funcionar sola.

También implica que las métricas de captura no son comparables entre plataformas.
