# Seguridad y privacidad

La app maneja datos financieros. Esto no es opcional.

## Lista blanca de paquetes

`kBankPackages` en `notification_listener_datasource.dart` es la garantía técnica detrás de la promesa "no leemos tus mensajes personales". Toda notificación de un paquete fuera de esa lista se descarta **antes** de leer su texto.

No se agregan paquetes de mensajería, correo ni redes sociales. Nunca. Aunque parezca útil.

## Almacenamiento

| Dato | Dónde | Por qué |
|---|---|---|
| Access token | `flutter_secure_storage` | Keychain / EncryptedSharedPreferences |
| Transacciones | Drift | Datos de negocio, cifrado del sistema de archivos |
| Texto crudo | Drift, local | Necesario para reprocesar; no se sube sin consentimiento |
| Preferencias | Drift | Nada sensible |

Nunca en `SharedPreferences` plano. Nunca en un archivo de texto.

## Datos que salen del dispositivo

Solo cuando el parser local falla y el usuario autorizó el fallback de IA. Ese consentimiento debe ser explícito y revocable, no enterrado en los términos.

En logs, el `LogInterceptor` redacta el header `Authorization`. Nunca se loguea el contenido de una notificación en producción.

## Permisos de Android

`BIND_NOTIFICATION_LISTENER_SERVICE` es un permiso especial que asusta al usuario si se pide en frío. El onboarding explica qué se lee y qué no **antes** de mandar a Ajustes. Ver `capture_onboarding_page.dart`.

Google Play revisa con lupa las apps que usan este permiso. Hay que declarar el uso en el formulario de Data Safety y estar preparado para justificarlo.

## Checklist antes de publicar

- [ ] Sin claves de API en el código ni en `--dart-define` visible
- [ ] Certificate pinning en Dio si el modelo de amenaza lo justifica
- [ ] Ofuscación activada: `flutter build apk --obfuscate --split-debug-info=`
- [ ] Política de privacidad publicada y enlazada desde la app
- [ ] Formulario de Data Safety de Play Store completo y veraz
- [ ] Borrado de cuenta implementado (requisito de Play y App Store)
- [ ] Backups de Android excluyen la base de datos (`android:allowBackup="false"`)
