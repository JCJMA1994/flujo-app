# Contribuir

## Flujo

1. Rama desde `main`: `feat/captura-scotiabank`, `fix/debounce-busqueda`, `docs/adr-sync`.
2. Commits en formato [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
3. Antes de abrir PR: `flutter analyze && flutter test && dart format lib test`.
4. El PR describe **qué problema resuelve**, no qué archivos toca. El diff ya dice lo segundo.

## Checklist de revisión

- [ ] `domain/` no importa Flutter, Drift ni Dio
- [ ] Blocs y cubits registrados con `registerFactory`
- [ ] Todo `BlocBuilder` tiene `buildWhen`
- [ ] Estados y entidades declaran todos sus campos en `props`
- [ ] Subjects y subscriptions se cierran en `close()`
- [ ] Los errores se traducen a `Failure` en la capa `data`
- [ ] Hay test para la lógica nueva
- [ ] Ningún secreto ni token en el código
- [ ] Si toca captura: no se agregaron paquetes no bancarios a `kBankPackages`

## Estilo

- `very_good_analysis` como base de lint. No se desactivan reglas sin justificación en el PR.
- Nombres en inglés, textos de UI en español.
- Comentarios que expliquen por qué, no qué.
- Widgets privados con guion bajo (`_TransactionTile`) cuando no se reusan fuera del archivo.

## Dependencias

Agregar una dependencia requiere justificarla en la descripción del PR: qué problema resuelve y por qué no basta con lo que ya está. Cada paquete es superficie de mantenimiento y peso en el binario.
