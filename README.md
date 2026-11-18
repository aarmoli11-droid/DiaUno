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

Plataformas generadas: Android, iOS, Web, Windows, macOS y Linux. Las comprobaciones automáticas se ejecutaron en Web y Windows. Android requiere aceptar licencias del SDK antes de compilar.

> Nota Windows: si la ruta del proyecto contiene caracteres no ASCII (por ejemplo `DíaUno`), el toolchain de Flutter/Windows puede perder la codificación al invocar MSBuild. Como workaround verificado, compila desde una unión (junction) con ruta ASCII, por ejemplo `C:\tmp\diauno`. No afecta al código fuente ni al ejecutable resultante.

## Configuración

1. Copia `.env.example` a `.env.local`.
2. Rellena `SUPABASE_URL` y la clave publicable (o la anon legacy). El archivo está ignorado por Git.
3. Ejecuta:

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

Buckets privados creados por la migración inicial: `task-evidence` y `finance-receipts`. Las políticas permiten al propietario y a los miembros del proyecto según su rol.

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
```

Las pruebas unitarias cubren recurrencias, distribuciones y reglas del jardín. Las pruebas de integración usan repositorios en memoria bajo `test/integration/`; no dependen de red.

## Seguridad

- `.env.local` y `.supabase/` están ignorados por Git.
- `.env.example` no contiene secretos.
- Ninguna clave de servicio se usa en el cliente.
- Antes de hacer push, revisa `git status --ignored` y confirma que no aparece ningún archivo sensible.
