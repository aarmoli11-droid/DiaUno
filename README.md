# DíaUno

Aplicación personal multiplataforma para organizar proyectos, tareas, agenda, finanzas compartidas, tiempo y un jardín ligero de progreso.

> Nombre centralizado en `lib/core/brand.dart`. El repositorio se creó como `PLAN` y GitHub lo renombró a `DiaUno`; esa cadena no se usa como marca.

## Requisitos verificados

| Herramienta | Versión |
| --- | --- |
| Flutter | 3.41.1 |
| Dart | 3.11.0 |
| Supabase CLI | 2.113.0 |
| Firebase CLI | 15.37.0 |
| Git | 2.56.0.windows.4 |
| PowerShell | Windows PowerShell 5.1 o PowerShell 7.x |

Plataformas generadas: Android, iOS, Web, Windows, macOS y Linux. Las comprobaciones automáticas se ejecutaron en Web, Windows y Android (emulador x86_64).

> Nota Windows: si la ruta del proyecto contiene caracteres no ASCII (por ejemplo `DíaUno`), el toolchain de Flutter/Windows puede perder la codificación al invocar MSBuild. Como workaround verificado, compila desde una unión (junction) con ruta ASCII, por ejemplo `C:\tmp\diauno`. No afecta al código fuente ni al ejecutable resultante.

> Nota Android: AGP rechaza por defecto las rutas con caracteres no ASCII en Windows. Como la ruta destino es obligatoria, `android/gradle.properties` incluye `android.overridePathCheck=true`; con ello `flutter build apk --debug` y `flutter run` funcionan desde la carpeta original. No desactiva ninguna comprobación de código ni de permisos.

## Configuración

1. Copia `.env.example` a `.env.local`.
2. Rellena `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` (o `SUPABASE_ANON_KEY` si el proyecto aún no publica la clave publicable). El archivo está ignorado por Git; no contiene secretos de servicio.
3. `Env.isConfigured` acepta cualquiera de esas dos parejas. Si falta algo, la app muestra un mensaje concreto con la variable ausente en lugar de una pantalla en blanco.
4. Ejecuta `.\diauno.ps1 doctor` para validar la instalación antes de trabajar.

`.env.local` usa formato **dotenv** (`CLAVE=VALOR`). Flutter necesita un objeto JSON para `--dart-define-from-file`; el script convierte automáticamente el archivo a un JSON temporal fuera del repositorio y lo elimina al terminar. Si en el futuro el archivo estuviera en JSON, el script también lo detecta. Para producción, inyecta las variables en el pipeline de CI; no las versiones.

Variables que lee la aplicación (`lib/core/config/env.dart`):

| Variable | Uso |
| --- | --- |
| `SUPABASE_URL` | Obligatoria, debe comenzar con `https://`. |
| `SUPABASE_PUBLISHABLE_KEY` | Clave pública recomendada (`sb_publishable_...`). |
| `SUPABASE_ANON_KEY` | Clave anon legacy; sigue siendo válida. Se usa si no hay publishable. |
| `SUPABASE_PROJECT_REF` | Referencia del proyecto; se inyecta cuando está definida. |
| `ENABLE_GOOGLE_OAUTH` | Opcional; por defecto es `false`. |

Debe existir `SUPABASE_URL` y al menos una de las dos claves públicas. `SUPABASE_DB_PASSWORD` y `SUPABASE_ORG_ID` son exclusivas del CLI de Supabase: **se detectan pero nunca se inyectan en Flutter Web**.

## Script de ejecución y despliegue (`diauno.ps1`)

Punto único de entrada para Windows. Todas las rutas se resuelven desde `$PSScriptRoot`, por lo que puede invocarse desde cualquier directorio. Nunca imprime credenciales, no modifica `.env.local` y limpia el JSON temporal incluso si un comando falla.

### Requisitos

- Flutter y Dart instalados y en el `PATH`.
- Firebase CLI instalado y autenticado (`firebase login`) para `doctor` y `deploy`.
- Git disponible para comprobar que `.env.local` está ignorado.
- PowerShell 5.1 o 7.x. Si la política de ejecución bloquea el script:

```powershell
powershell -ExecutionPolicy Bypass -File .\diauno.ps1 doctor
```

### Comandos

| Comando | Qué hace |
| --- | --- |
| `.\diauno.ps1 doctor` | Verifica herramientas, estructura del proyecto, `.env.local`, variables, `firebase.json`, proyecto Firebase y exclusión Git. No muestra secretos. |
| `.\diauno.ps1 run` | Valida la configuración, genera el JSON temporal y ejecuta `flutter run -d chrome`. El temporal se borra al cerrar la app. |
| `.\diauno.ps1 build` | Genera el JSON temporal y ejecuta `flutter build web --release`, comprobando `build/web/index.html`. |
| `.\diauno.ps1 deploy` | Valida todo, confirma la sesión de Firebase, compila y ejecuta `firebase deploy --only hosting --project flutter1-b1fc8`. |
| `.\diauno.ps1 help` | Muestra la ayuda integrada. |

### Ejecución local

```powershell
.\diauno.ps1 run
```

Se aceptan argumentos adicionales para Flutter, por ejemplo `.\diauno.ps1 run --web-port 5000`.

### Compilación

```powershell
.\diauno.ps1 build
```

El resultado queda en `build/web`. La compilación se detiene si falta alguna variable obligatoria, si aparece una credencial secreta destinada al cliente o si no se genera `index.html`.

### Despliegue

```powershell
firebase login
.\diauno.ps1 deploy
```

Si cualquier paso falla, el script se detiene y **no despliega**. Al terminar informa de la URL publicada: `https://flutter1-b1fc8.web.app`.

### Recomendaciones de seguridad

- Usa solo claves públicas de Supabase en el cliente web: nunca `service_role`, contraseñas de base de datos ni secretos de servicio.
- Mantén `.env.local` fuera de Git; `diauno.ps1 doctor` lo comprueba.
- No copies las credenciales en Dart ni en el README; la app las lee con `String.fromEnvironment`.
- El JSON temporal se crea fuera del repositorio y se elimina en `finally`, incluso ante errores.
- Revisa `git status --ignored` antes de subir cambios.

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
- Navegación: barra inferior en móvil, Drawer lateral en móvil y sidebar en escritorio (≥900 px).
- Tema claro/oscuro/sistema persistido localmente, controlado sólo desde Configuración.

### Navegación

- **Móvil (<900 px):** barra inferior con cinco destinos: Inicio, Proyectos, Compartidos, Jardín y Menú. Menú es una acción del shell, no una ruta; aparece activo mientras Agenda está abierta.
- **Drawer móvil:** se abre desde la izquierda pulsando Menú y se cierra con la X, pulsando fuera o con el botón Atrás. Incluye Agenda, Buscar, Tiempo, Notificaciones y Configuración, usando rutas y ramas ya existentes.
- **Escritorio (≥900 px):** sidebar fijo de 240 px con los cinco destinos principales y Buscar, Tiempo, Notificaciones y Configuración. No hay barra inferior, botón Menú ni Drawer.
- Agenda sigue siendo una rama propia del router: se abre desde el Drawer sin crear rutas nuevas y conserva el estado del resto de ramas.

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
.\diauno.ps1 doctor
.\diauno.ps1 build
flutter build windows
flutter build apk --debug --dart-define-from-file=.env.local
```

Las pruebas unitarias cubren recurrencias, distribuciones, reglas del jardín y sincronización offline/conflictos, incluida la serialización de eventos de tareas personales (`project_id` nulo) y el nombre de proyecto embebido por PostgREST. `test/unit/auth_navigation_test.dart` verifica que «Crear cuenta» e «Iniciar sesión» abren sus formularios, que se muestran los errores de validación, que una sesión no puede entrar en rutas privadas y que el redirect del contenedor `/auth` no captura sus rutas hijas. `test/unit/date_locale_test.dart` protege el formateo en español y la inicialización del locale en `main`. `test/unit/mobile_navigation_test.dart` cubre la barra inferior, el Drawer y el sidebar de escritorio. `diauno.ps1 build` es la forma recomendada de compilar para Hosting porque inyecta las variables sin exponerlas.

`test/integration/supabase_live_test.dart` está desactivada por defecto y **no usa `service_role`**:

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
- `diauno.ps1` excluye explícitamente `SUPABASE_DB_PASSWORD` y cualquier variable con nombre `SERVICE`, `SECRET`, `PASSWORD`, `PRIVATE`, `DATABASE`, `DB_` o `CREDENTIAL` del JSON entregado a Flutter.
- Antes de hacer push, revisa `git status --ignored` y confirma que no aparece ningún archivo sensible.

## Cambios recientes

- Añadido `diauno.ps1` con los comandos `doctor`, `run`, `build`, `deploy` y `help`.
- Conversión automática de `.env.local` (dotenv o JSON) a un JSON temporal con solo las variables públicas, con limpieza en `finally`.
- Añadido `web/flutter_bootstrap.js`: se desactiva el service worker obsoleto de Flutter para evitar recargas que dejaban la app en blanco durante el arranque. CanvasKit sigue cargándose desde la CDN optimizada de Flutter porque forzar los archivos locales hizo el arranque más lento en las pruebas.
- Corregido el flujo de autenticación: el redirect del `GoRoute` padre `/auth` redirigía también a `/auth/login`, `/auth/register` y `/auth/reset` a la bienvenida. Ahora solo afecta a `/auth` exacto.
- Inicializados los datos de locale `es` de `intl` en el arranque: sin esto, Home y Agenda fallaban al formatear fechas y la pantalla quedaba en blanco con `LocaleDataException`.
- Corregido el Jardín: los eventos de tareas personales tienen `project_id` nulo y `GardenEvent.fromMap` hacía `as String`, lanzando `type 'Null' is not a subtype of type 'String' in type cast`. Ahora el identificador de proyecto es nullable, esos eventos siguen sumando al total y el nombre embebido se lee tanto como objeto (PostgREST actual) como lista (formato anterior). El repositorio conserva la excepción original en el mensaje. `supabase/migrations/20261124000100_garden_personal_tasks.sql` deja reproducible el estado ya presente en producción: columna nullable, RLS por dueño/proyecto y trigger sin duplicados.
- `diauno.ps1 deploy` muestra la salida redactada de Firebase cuando falla, para diagnosticar el motivo.
- Documentación de requisitos, formato de configuración, comandos y precauciones de seguridad en este README.
