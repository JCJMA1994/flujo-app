# Arquitectura

## Principio rector

Las dependencias apuntan hacia adentro. `presentation` conoce `domain`, `data` conoce `domain`, y `domain` no conoce a nadie. Si abres cualquier archivo de `domain/` y encuentras un `import 'package:flutter/...'` o un `import 'package:drift/...'`, algo se rompió.

La razón práctica no es purismo: es que cambiar de Drift a Isar, o de REST a GraphQL, debería tocar una carpeta y no cuarenta archivos.

## Las tres capas

### domain

Dart puro. Contiene:

- **Entidades** — objetos de negocio con `Equatable`. `Transaction` sabe que una confianza menor a 0.7 necesita revisión, porque eso es una regla de negocio, no de UI.
- **Contratos de repositorio** — interfaces abstractas. El dominio declara qué necesita, no cómo se consigue.
- **Casos de uso** — una clase por intención del usuario, invocable con `call`. Aquí van las validaciones que no pertenecen a una sola entidad.

### data

Implementa los contratos del dominio.

- **Modelos** — conocen JSON y columnas de base de datos. Tienen `toEntity()` y `fromEntity()`. Están separados de las entidades a propósito: si el backend renombra un campo, cambia el modelo y el dominio ni se entera.
- **Datasources** — uno local (Drift) y uno remoto (Dio). Cada uno con su propia interfaz.
- **Repositorios** — combinan datasources, deciden la política de caché y traducen excepciones a `Failure`.

### presentation

- **Blocs y Cubits** — mantienen el estado de UI. No contienen lógica de negocio: llaman a casos de uso.
- **Páginas** — proveen los blocs con `BlocProvider`.
- **Widgets** — consumen con `BlocBuilder`, siempre con `buildWhen`.

## Flujo de datos

```
Notificación del banco
         │
         ▼
NotificationListenerDataSource  (filtro de lista blanca)
         │
         ▼
ExpenseParsingPipeline
   ├── 1. BankParser (regex)          gratis, instantáneo, ~80%
   ├── 2. AiCategorizerDataSource     solo si el parser falla
   └── 3. UserRule                    siempre gana
         │
         ▼
   CaptureCubit → AddTransaction (caso de uso)
         │
         ▼
TransactionRepositoryImpl
   └── escribe en Drift (local primero)
         │
         ▼
   Drift .watch() reemite
         │
         ▼
TransactionBloc / DashboardCubit
         │
         ▼
         UI
```

El punto clave: **la UI nunca escucha la escritura, escucha la base de datos**. Se guarda un gasto, Drift reemite su stream, y el bloc recibe la lista nueva sin que nadie le avise explícitamente. Eso elimina toda una clase de bugs de estado desincronizado.

## Offline-first

La base local es la fuente de verdad. El servidor la alimenta, no al revés.

- Toda escritura va primero a Drift con `syncedAt = null`.
- La UI responde de inmediato porque no espera la red.
- `syncPending()` sube lo pendiente en segundo plano.
- El borrado es lógico (`deleted = true`), porque si borráramos la fila no habría forma de comunicarle el borrado al servidor.

Esto es obligatorio en una app móvil peruana: la señal se cae, el metro no tiene cobertura, y una app de gastos que no funciona sin internet se desinstala.

## Por qué RxDart y no solo Streams

Tres usos concretos, no decorativos:

**`debounceTime`** — la búsqueda dispara una query SQL por pulsación sin él.

**`BehaviorSubject` + `switchMap`** — el filtro es un stream. Cuando cambia, `switchMap` cancela la suscripción anterior al repositorio y abre una nueva. Con `map` normal las suscripciones se acumularían y la UI recibiría datos de filtros viejos.

**`Rx.combineLatest2`** — el resumen mensual depende del mes actual y del anterior al mismo tiempo. Con `Stream` puro habría que anidar suscripciones a mano.

**`asyncMap`** en el pipeline de captura — procesa notificaciones de a una. Si llegan cinco seguidas, no se disparan cinco llamadas simultáneas al backend.

## Bloc o Cubit: cómo decidir

Usa **Cubit** cuando el componente responde a una o dos acciones simples. `DashboardCubit` solo hace "muéstrame este mes".

Usa **Bloc** cuando hay un vocabulario real de eventos y necesitas transformers distintos por evento. `TransactionBloc` aplica `debounce` a la búsqueda, `restartable` a los filtros y `sequential` al borrado. Eso con Cubit no se expresa.

Regla práctica: si no puedes nombrar tres eventos distintos y con semántica propia, usa Cubit.

## Manejo de errores

No usamos excepciones para control de flujo entre capas. `data` captura las excepciones de Dio y Drift y las convierte en `Failure`. Los casos de uso devuelven `Result<T>`, que es un tipo sellado con `Success` y `FailureResult`.

Esto obliga a manejar el error en el sitio de la llamada. Un `Future<Transaction>` que puede lanzar es una bomba silenciosa; un `Future<Result<Transaction>>` no compila si ignoras el caso de fallo dentro de un `switch` exhaustivo.

Se eligió un tipo propio en lugar de `dartz` o `fpdart` para no arrastrar una dependencia entera por una sola clase.

## Inyección de dependencias

`get_it`, registrado en `core/di/injection.dart`.

- **Repositorios y datasources**: `registerLazySingleton`. El stream local debe ser compartido.
- **Casos de uso**: `registerLazySingleton`. No tienen estado.
- **Blocs y Cubits**: `registerFactory`, siempre. Un bloc singleton sobrevive al widget que lo creó, se queda con streams abiertos y termina emitiendo sobre un `BuildContext` muerto. Es el error más común con `get_it` y Bloc.

## Restricción de plataforma

`NotificationListenerService` existe solo en Android. En iOS, el contrato `NotificationListenerDataSource` se satisface con `NoopNotificationListener`, que devuelve un stream vacío y `isSupported == false`.

Esto mantiene el resto del código libre de `if (Platform.isAndroid)`. La UI consulta `state.permission == CapturePermission.unsupported` y muestra el flujo alternativo de correo.

## Qué falta

- Feature de autenticación (`features/auth/`)
- Datasource remoto con Retrofit
- Sincronización con resolución de conflictos (hoy es last-write-wins)
- Feature de chat conversacional
- Detección de suscripciones recurrentes
- Tests de integración con `integration_test`
