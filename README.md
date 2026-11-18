# DíaUno

Aplicación personal multiplataforma para organizar proyectos, tareas, agenda, finanzas compartidas, tiempo y un jardín ligero de progreso.

> Nombre centralizado en `lib/core/brand.dart`. El repositorio se creó como `PLAN` y GitHub lo renombró a `DiaUno`; esa cadena no se usa como marca.

## Requisitos verificados

| Herramienta | Versión |
| --- | --- |
| Flutter | 3.41.1 |
| Dart | 3.11.0 |
| Supabase CLI | 2.113.0 |
| Git | 2.56.0.windows.4 |

Plataformas generadas: Android, iOS, Web, Windows, macOS y Linux. Las comprobaciones automáticas se ejecutaron en Web, Windows y Android (emulador x86_64).

> Nota Windows: si la ruta del proyecto contiene caracteres no ASCII (por ejemplo `DíaUno`), el toolchain de Flutter/Windows puede perder la codificación al invocar MSBuild. Como workaround verificado, compila desde una unión (junction) con ruta ASCII, por ejemplo `C:\tmp\diauno`. No afecta al código fuente ni al ejecutable resultante.

> Nota Android: AGP rechaza por defecto las rutas con caracteres no ASCII en Windows. Como la ruta destino es obligatoria, `android/gradle.properties` incluye `android.overridePathCheck=true`; con ello `flutter build apk --debug` y `flutter run` funcionan desde la carpeta original. No desactiva ninguna comprobación de código ni de permisos.

## Configuración

1. Copia `.env.example` a `.env.local`.
2. Rellena `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (o `SUPABASE_ANON_KEY` si el proyecto aún no publica la clave publicable). El archivo está ignorado por Git; no contiene secretos de servicio.
3. `Env.isConfigured` acepta cualquiera de esas dos parejas. Si falta algo, la app muestra un mensaje concreto con la variable ausente en lugar de una pantalla en blanco.
4. Ejecuta:

```powershell
flutter pub get
flutter run --dart-define-from-file=.env.local
```

Para producción, inyecta las variables en el pipeline de CI; no las versiones.

## Base de datos

El proyecto Supabase es nuevo e independiente. Las migraciones están en `supabase/migrations/`.

```powershell
supabase link --project-ref TU_REF
supabase db push
```

Incluyen:

- Perfiles y actividades con `trigger on_auth_user_created`.
- Proyectos con roles `owner`, `admin`, `collaborator`, `viewer`.
- Helpers `security definer` para evitar recursión en RLS.
- RLS real en todas las tablas; el cliente nunca usa `service_role`.
- Tareas con ocurrencias independientes e historial por ocurrencia.
- Eventos separados de tareas.
- Finanzas: importes históricos inmutables por trigger, suscripciones únicas y distribuciones que no duplican el gasto.
- Registros de tiempo, notificaciones, actividad, evidencia en Storage privado y progreso materializado del jardín.

### Storage

Buckets privados creados por la migración inicial: `task-evidence` y `finance-receipts`. Las políticas están separadas por bucket: la evidencia de tareas se autoriza por acceso a la ocurrencia (`{uid}/tasks/{occurrenceId}/...`) y los comprobantes financieros sólo por el propietario de la transacción (`{uid}/finance/{transactionId}/...`). No se amplía el acceso financiero a miembros del proyecto.

## Arquitectura

```
lib/
  core/        brand, configuración, tema, errores, Utils, local store, sync, router
  shared/      widgets reutilizables (shell responsive, estados, banner de sync)
  features/
    auth/ projects/ tasks/ agenda/ finance/ time/ garden/
    notifications/ search/ settings/ home/ shared/ sync/
      data/          repositorios Supabase/Storage
      domain/        modelos inmutables y reglas puras
      application/   providers Riverpod y acciones
      presentation/  pantallas
```

Decisiones:

- Riverpod con providers clásicos; sin codegen para estado.
- Modelos inmutables escritos a mano; sin freezed.
- HiveCE únicamente como cola de mutaciones pendientes y caché ligera; no como espejo ciego de la base de datos.
- Conflictos detectados con `updated_at` optimista y resueltos explícitamente desde Ajustes → Sincronización.
- Jardín con `CustomPainter` y gestos: sin Flame/Rive. Decisión reversible.
- Navegación: barra ovalada flotante en móvil y sidebar en escritorio (≥900 px).
- Tema claro/oscuro/sistema persistido localmente.

## Flujos implementados

- Registro, inicio de sesión y recuperación de contraseña con correo/contraseña.
  - Callback: `diauno://auth/recovery`.
  - Registrado en `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` y `additional_redirect_urls` de `supabase/config.toml`.
  - `AuthRepository.resetPassword` envía el correo con `redirectTo`; el SDK detecta el retorno y emite `passwordRecovery`.
  - El router fuerza `/auth/new-password` hasta que `updatePassword` guarda la clave y cierra la sesión temporal; luego vuelve al login.
  - Estado verificado en emulador Android: solicitud, enlace, retorno, sesión `recovery`, cambio de contraseña, cierre de sesión y login con la nueva clave.
- Proyectos: crear, editar, archivar, roles e invitaciones por nombre visible; herramientas y actividad.
- Tareas: crear, editar, completar/reabrir por ocurrencia, recurrencias materializadas, comentarios y evidencia.
- Agenda: calendario semanal/mensual, eventos propios y tareas del día.
- Finanzas: movimientos con importe inmutable, filtros de periodo, resumen, exportación CSV y comprobantes.
- Compartidos: suscripciones, distribuciones por importes/porcentajes/partes iguales y resolución de redondeo.
- Tiempo: temporizador en curso y registros manuales vinculados a proyecto/tarea.
- Jardín: visualización determinista alimentada por eventos reales de cumplimiento.
- Notificaciones, búsqueda con permisos RLS y ajustes de tema/sesión.

## Google OAuth

El botón aparece sólo con `ENABLE_GOOGLE_OAUTH=true`. Requiere configurar el proveedor en Supabase Auth, las URLs de retorno por plataforma y el esquema de callback nativo. La app abre el consentimiento real; no simula la autenticación. Este paso queda pendiente hasta disponer de credenciales OAuth.

## Pruebas

```powershell
dart format .
flutter analyze
flutter test
flutter build web
flutter build windows
flutter build apk --debug --dart-define-from-file=.env.local
```

Las pruebas unitarias cubren recurrencias, distribuciones, jardín y sincronización offline/conflictos. `test/integration/supabase_live_test.dart` está desactivada por defecto y **no usa `service_role`**:

```powershell
$env:DIAUNO_LIVE_TESTS='1'
flutter test test/integration/supabase_live_test.dart
```

Ejecuta operaciones reales contra el proyecto enlazado con dos cuentas normales: registro, perfil propio, proyectos, tareas personales y de proyecto, jardín derivado, finanzas, distribución `equal` y su borrado, Storage, RLS, roles, eventos arbitrarios rechazados, logout/login y limpieza de datos de la prueba. Las credenciales se leen de `.env.local` y nunca se imprimen.

La validación SQL con transacción `ROLLBACK` está en `supabase/tests/fixes_test.sql`:

```powershell
supabase db query --linked -f supabase/tests/fixes_test.sql
```

Cubre jardín con `project_id NULL`, no duplicados por ocurrencia, límites `amount`/`percent`/`equal` en INSERT/UPDATE/DELETE, RLS de proyecto ajeno, columnas visibles de `profiles`, eventos arbitrarios de jardín y autoasignación de `owner`.

### Limitaciones verificadas

- La prueba de correo completa necesita un buzón real o administrar el enlace de recuperación generado por Supabase; en Android se validó con un token de prueba inyectado y el retorno al deep link.
- Google OAuth sigue pendiente de credenciales y callbacks externos; la app no simula ese flujo.
- `supabase status` local requiere Docker; las operaciones `--linked` funcionan sin él.
- Windows debe compilarse desde una junction ASCII cuando la ruta original contiene `DíaUno`.

## Seguridad

- `.env.local` y `.supabase/` están ignorados por Git.
- `.env.example` no contiene secretos.
- Ninguna clave de servicio se usa en el cliente.
- Antes de hacer push, revisa `git status --ignored` y confirma que no aparece ningún archivo sensible.
