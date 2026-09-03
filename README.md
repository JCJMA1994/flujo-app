# Flujo

App de finanzas personales que registra gastos automáticamente a partir de las notificaciones del banco. Flutter, Clean Architecture, BLoC + Cubit, RxDart, Equatable.

## Qué hace

El usuario no anota nada. Llega la notificación del banco ("Consumo de S/24.50 en Starbucks"), la app la interpreta, la categoriza y la guarda. El usuario solo corrige cuando la app se equivoca, y esa corrección se convierte en una regla que la app recuerda.

## Requisitos

- Flutter 3.24+ (Dart 3.5+)
- Android SDK 24+ / iOS 13+
- Java 17+ y Maven (para el backend en `apps/server`)
- Docker y Docker Compose (para PostgreSQL local)

## Arranque Rápido

El repositorio incluye un `Makefile` con atajos para las operaciones principales:

```bash
# 1. Levantar base de datos local (PostgreSQL)
make db-up

# 2. Configurar dependencias y generar código de Flutter (Drift)
make setup

# 3. Correr aplicación móvil
cd apps/mobile && flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Para regenerar código de Drift mientras desarrollas:

```bash
make watch
```

## Comandos Útiles

| Comando | Qué hace |
|---|---|
| `make setup` | Instala dependencias y genera código con `build_runner` en mobile |
| `make gen` | Ejecuta `build_runner` una sola vez |
| `make watch` | Observa cambios y regenera modelos con `build_runner` |
| `make analyze` | Ejecuta análisis estático con `flutter analyze` |
| `make test` | Corre la suite de tests de Flutter |
| `make coverage` | Genera reporte de cobertura en `apps/mobile/coverage/lcov.info` |
| `make format` | Formatea código Dart (`dart format lib test`) |
| `make check` | Pipeline local: format + analyze + test |
| `make db-up` | Inicia el contenedor de PostgreSQL |
| `make db-down` | Detiene el contenedor de PostgreSQL |

## Estructura del Repositorio

Monorepo organizado por aplicaciones y documentación:

```
.
├── apps/
│   ├── mobile/              # Cliente Flutter (Clean Architecture + BLoC)
│   │   ├── android/         # Host Android con NotificationListenerService y WorkManager
│   │   ├── lib/
│   │   │   ├── core/        # Drift DB, DI (get_it), Network (Dio), Router, Theme
│   │   │   └── features/
│   │   │       ├── capture/      # Captura nativa, parsers bancarios, fallback Gemini AI
│   │   │       ├── transactions/ # Registro, sincronización, dashboard, métricas
│   │   │       └── onboarding/   # Flujo inicial y permisos
│   │   └── test/            # Tests unitarios, de BLoC y repositorios
│   └── server/              # Backend Spring Boot 3 (Arquitectura Hexagonal, Java 17)
│       └── src/
│           ├── main/        # Ports & Adapters, integración con Gemini AI, API REST
│           └── test/        # Tests de controladores e integración
├── docs/                    # Especificaciones, ADRs, contratos y guías
│   └── adr/                 # Architecture Decision Records
├── scripts/                 # Utilidades de desarrollo y mantenimiento
├── docker-compose.yml       # Infraestructura local (Postgres)
└── Makefile                 # Tareas automatizadas
```

Cada feature en `apps/mobile` replica estrictamente las tres capas de Clean Architecture:
- `domain`: Dart puro (Entidades, Repositorios abstractos, Casos de uso). Sin imports de Flutter ni librerías de terceros.
- `data`: Modelos, Datasources (Drift local, Dio remoto), Repositorios concretos.
- `presentation`: BLoC/Cubit, Páginas, Widgets atómicos.

## Diferencia entre plataformas

La captura automática **no funciona igual en Android y iOS**:

- **Android** usa `NotificationListenerService` y lee las notificaciones en el dispositivo. Requiere un permiso especial que el usuario concede desde Ajustes.
- **iOS** no tiene equivalente: Apple no permite que una app lea notificaciones de otra. Ahí la captura se resuelve del lado del servidor, conectando Gmail o WhatsApp Business API.

Esto no es un detalle de implementación, es una restricción que define la arquitectura. Lee `docs/ARCHITECTURE.md`.

## Privacidad

Solo se leen notificaciones de una lista blanca de apps bancarias, definida en `notification_listener_datasource.dart`. Todo lo demás se descarta antes de tocar el texto. El texto crudo se guarda localmente para poder reprocesar el histórico cuando mejoren los parsers, y solo sale del dispositivo cuando el parser local falla y el usuario ha autorizado el fallback de IA.

Los tokens viven en `flutter_secure_storage`. Nunca en `SharedPreferences` ni en la base de datos.

## Documentación

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — capas, flujo de datos, decisiones
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — convenciones y flujo de trabajo
- [`docs/TESTING.md`](docs/TESTING.md) — estrategia de pruebas
- [`docs/adr/`](docs/adr/) — registros de decisiones arquitectónicas
- [`CLAUDE.md`](CLAUDE.md) — contexto para asistentes de IA

## Licencia

Privado.
