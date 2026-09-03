# CLAUDE.md

Contexto para asistentes de IA que trabajen en este repositorio.

## Qué es esto

App Flutter de finanzas personales para Perú. Registra gastos automáticamente leyendo notificaciones bancarias. Clean Architecture con BLoC + Cubit, RxDart y Equatable.

## Comandos

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # tras tocar Drift
flutter analyze
flutter test
dart format lib test
```

Después de cambiar cualquier tabla en `core/database/app_database.dart` hay que correr `build_runner`, o el proyecto no compila.

## Reglas que no se rompen

**La capa `domain` es Dart puro.** Sin `flutter`, sin `drift`, sin `dio`. Si necesitas un tipo de un paquete externo en el dominio, va envuelto en una entidad propia.

**Blocs y Cubits se registran con `registerFactory`, nunca singleton.** Un bloc singleton sobrevive al widget, mantiene streams abiertos y emite sobre contextos muertos.

**Todo `BlocBuilder` lleva `buildWhen`.** Sin él se repinta el árbol entero con cada emisión.

**Los estados y entidades extienden `Equatable`** y declaran todos sus campos en `props`. Si falta un campo, `emit` no detecta el cambio y la UI se queda congelada.

**Cerrar lo que se abre.** Todo `BehaviorSubject`, `PublishSubject` y `StreamSubscription` se cierra en `close()`.

**Los casos de uso devuelven `Result<T>`, no lanzan.** Las excepciones se capturan en la capa `data` y se traducen a `Failure`.

**El texto crudo de las notificaciones se conserva siempre** en `Transaction.rawText`. Cuando mejoren los parsers se reprocesa el histórico.

## Privacidad: no negociable

La lista blanca `kBankPackages` en `notification_listener_datasource.dart` es la garantía técnica de la promesa al usuario. **No agregues paquetes que no sean de apps bancarias.** No agregues mensajería, correo ni redes sociales, por más que "podría ser útil".

El texto de las notificaciones no sale del dispositivo salvo cuando el parser local falla y existe consentimiento explícito. Si escribes código que envía `rawText` al backend, verifica que pasa por ese consentimiento.

Nunca escribas tokens ni credenciales fuera de `flutter_secure_storage`. Nunca loguees el header `Authorization`.

## Convenciones de código

- Nombres de clases y archivos en inglés; strings de UI y comentarios de dominio en español.
- Un archivo por clase pública, salvo `part of` para estados y eventos de bloc.
- `sealed class` para estados y eventos, para que `switch` sea exhaustivo.
- Comentarios que explican **por qué**, no **qué**. `// incrementa i` sobra; `// asyncMap y no map: el pipeline llama al backend` sirve.
- Sin `print`. Usa `dart:developer` `log` o el `AppBlocObserver`.

## Al agregar un feature nuevo

Replica las tres capas:

```
features/<nombre>/
├── domain/{entities,repositories,usecases}/
├── data/{models,datasources,repositories}/
└── presentation/{bloc|cubit,pages,widgets}/
```

Registra las dependencias en `core/di/injection.dart` respetando factory vs singleton.

## Al agregar soporte para un banco

1. Crea la clase en `features/capture/data/parsers/bank_parsers.dart` implementando `BankParser`.
2. Agrega el nombre de paquete a `kBankPackages`.
3. Registra el parser en la lista del `ExpenseParsingPipeline` en `injection.dart`, **antes** de `GenericAmountParser`.
4. Escribe un test con notificaciones reales de ese banco en `test/features/capture/`.

El orden importa: los parsers se evalúan en secuencia y el genérico es el último recurso.

## Trampas conocidas

- `distinct()` de RxDart usa `==`. Si el objeto no implementa `Equatable`, nunca filtra nada.
- Drift `watch()` reemite ante cualquier cambio en las tablas del join, incluso si el resultado es idéntico. Por eso el repositorio aplica `.distinct()` encima.
- `emit` después de `close()` lanza. Con operaciones asíncronas dentro de un cubit, verifica `isClosed` antes de emitir si hay riesgo de que el widget se desmonte.
- `NotificationListenerService` en Android puede ser matado por el sistema. Hay que rebindar en el arranque, no asumir que sigue vivo.

## Qué no hacer

- No metas lógica de negocio en widgets ni en blocs. Va en casos de uso.
- No llames a un datasource desde presentación saltándote el repositorio.
- No agregues una dependencia sin justificarla en el PR.
- No pongas claves de API de proveedores de IA en la app. La llamada al modelo vive en el backend.
