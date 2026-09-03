# Contrato con el backend

La app es un cliente. Estas son las superficies que necesita del servidor.

## Por qué la IA vive en el servidor

Poner la clave de un proveedor de IA dentro del binario equivale a publicarla: cualquiera la extrae de un APK con herramientas de escritorio. Además, centralizar permite cachear interpretaciones repetidas, limitar consumo por usuario y cambiar de modelo sin publicar una versión nueva de la app.

## Endpoints

### `POST /v1/capture/interpret`

Fallback cuando ningún parser local reconoce la notificación.

```json
// request
{ "raw_text": "Consumo de S/24.50 en STARBUCKS *4821 el 01/09" }

// response
{
  "amount": 24.50,
  "currency": "PEN",
  "merchant": "Starbucks",
  "occurred_at": "2026-09-01T09:41:00-05:00",
  "category_id": "food",
  "bank_id": "bcp",
  "confidence": 0.86
}
```

Si no hay gasto reconocible, responde `200` con `amount: null`. Un `4xx` aquí haría que la app reintente sin sentido.

El servidor debe cachear por hash del texto normalizado: las notificaciones se repiten mucho entre usuarios.

### `POST /v1/transactions/sync`

Recibe las transacciones creadas o editadas offline y devuelve los ids confirmados.

```json
// request
{ "transactions": [ /* array de TransactionModel.toJson() */ ] }

// response
{ "acknowledged": ["uuid-1", "uuid-2"], "conflicts": [] }
```

Hoy la resolución es last-write-wins. Cuando haya multi-dispositivo habrá que decidir entre timestamps del servidor o vector clocks. Ver `docs/adr/0004`.

### `GET /v1/transactions?since=<iso8601>`

Pull incremental para dispositivos nuevos o reinstalaciones.

## Captura en iOS

En iOS la app no puede leer notificaciones. El servidor necesita:

- **Gmail API** con `users.watch` sobre Pub/Sub, filtrando por remitentes bancarios. El usuario autoriza con OAuth el scope de solo lectura.
- **WhatsApp Cloud API** con webhook, si el banco notifica por ese canal.

En ambos casos el servidor corre el mismo pipeline de parsers que la app, y empuja las transacciones resultantes. Mantener los parsers duplicados es deuda: lo ideal a mediano plazo es extraerlos a un paquete Dart compartido y correr el servidor en Dart, o portarlos y testearlos contra el mismo corpus de notificaciones.

## Autenticación

Bearer token en el header `Authorization`. La app lo guarda en `flutter_secure_storage` y el `_AuthInterceptor` lo inyecta. El refresh no está implementado todavía.

## Lo que el servidor nunca debe hacer

- Guardar el texto crudo de notificaciones más allá de lo necesario para la interpretación, salvo consentimiento explícito para mejorar los parsers.
- Devolver el `raw_text` en respuestas de listado.
- Loguear el contenido de las notificaciones en claro.
