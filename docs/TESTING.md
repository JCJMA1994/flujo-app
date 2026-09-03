# Estrategia de pruebas

## Pirámide

| Nivel | Qué cubre | Herramienta |
|---|---|---|
| Unitario | Parsers, entidades, casos de uso | `flutter_test` |
| Bloc | Transiciones de estado | `bloc_test` + `mocktail` |
| Datasource | Queries de Drift | `NativeDatabase.memory()` |
| Widget | Páginas con bloc mockeado | `flutter_test` |
| Integración | Flujos completos | `integration_test` |

## Dónde poner el esfuerzo

Los **parsers de banco** son lo más valioso de testear. Son lógica pura, sin dependencias, y un fallo ahí significa gastos mal registrados o perdidos. Cada banco soportado necesita casos con notificaciones reales, incluyendo las variantes raras: montos con coma de miles, comercios con caracteres extraños, notificaciones de reversión.

Lo segundo son los **casos de uso**, porque ahí vive la validación de negocio.

Los **widgets** se testean poco y con criterio: verifica que el estado de carga muestra un spinner y que el estado vacío muestra la invitación a activar la captura. No testees píxeles.

## Convenciones

- Un archivo de test por archivo de producción, mismo path bajo `test/`.
- `mocktail` sobre `mockito`: no requiere generación de código.
- `registerFallbackValue` en `setUpAll` para cualquier tipo custom usado con `any()`.
- Para probar tiempo en RxDart, usa el parámetro `wait` de `blocTest`.

## Drift en memoria

```dart
late AppDatabase db;

setUp(() => db = AppDatabase(NativeDatabase.memory()));
tearDown(() => db.close());
```

Cada test arranca con una base limpia. No compartas instancia entre tests.

## Cobertura

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

No perseguimos un porcentaje. Perseguimos que parsers y casos de uso estén cubiertos.
