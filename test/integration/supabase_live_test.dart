@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pruebas reales contra el proyecto Supabase de desarrollo.
///
/// Activación:
///   DIAUNO_LIVE_TESTS=1 flutter test test/integration/supabase_live_test.dart
///
/// Nota: NO se llama a `TestWidgetsFlutterBinding.ensureInitialized()` porque,
/// en el runner de `flutter test`, ese bindingintercepta las peticiones HTTP y
/// devuelve 400 vacío. Se construye un `SupabaseClient` directamente con un
/// almacenamiento PKCE en memoria, de modo que no se necesita el plugin nativo
/// de SharedPreferences. Las credenciales se leen de `.env.local` (ignorado
/// por Git) y nunca se imprimen.
Map<String, String>? _readLocalEnv() {
  final file = File('.env.local');
  if (!file.existsSync()) return null;
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    values[trimmed.substring(0, index).trim()] = trimmed
        .substring(index + 1)
        .trim()
        .replaceAll('"', '');
  }
  return values;
}

/// Almacenamiento en memoria para el verificador PKCE (sin plugin nativo).
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _data = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _data[key];

  @override
  Future<void> removeItem({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _data[key] = value;
  }
}

void main() {
  final env = _readLocalEnv();
  final live = Platform.environment['DIAUNO_LIVE_TESTS'] == '1' && env != null;
  final url = env?['SUPABASE_URL'] ?? '';
  final publishable = env?['SUPABASE_PUBLISHABLE_KEY'];
  final anon = env?['SUPABASE_ANON_KEY'];
  final key = (publishable != null && publishable.isNotEmpty)
      ? publishable
      : (anon ?? '');

  late SupabaseClient client;
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final ownerEmail = 'diauno_owner_$suffix@gmail.com';
  final otherEmail = 'diauno_other_$suffix@gmail.com';
  const password = 'DiaunoTest1234!';

  setUpAll(() async {
    if (!live) return;
    client = SupabaseClient(
      url,
      key,
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );
  });

  test(
    'flujo real contra Supabase con cuentas normales',
    () async {
      if (!live) {
        return; // Requiere .env.local y DIAUNO_LIVE_TESTS=1.
      }

      // 1) Registro, sesión inmediata y perfil propio por RPC.
      final ownerSignUp = await client.auth.signUp(
        email: ownerEmail,
        password: password,
        data: {'display_name': 'Owner Prueba'},
        emailRedirectTo: 'diauno://auth/recovery',
      );
      final ownerId = ownerSignUp.user!.id;
      expect(client.auth.currentSession, isNotNull);
      final myProfile = await client.rpc('get_my_profile');
      expect(
        (myProfile as List).first as Map,
        containsPair('email', ownerEmail),
      );

      // 2) Proyectos y tareas (personales y de proyecto) + jardín automático.
      final project = await client
          .from('projects')
          .insert({
            'owner_id': ownerId,
            'name': 'Proyecto live $suffix',
            'created_by': ownerId,
            'updated_by': ownerId,
          })
          .select()
          .single();
      final projectId = project['id'] as String;

      final createdTasks = await client
          .from('tasks')
          .insert([
            {
              'project_id': projectId,
              'created_by': ownerId,
              'title': 'Tarea de proyecto',
            },
            {
              'project_id': null,
              'created_by': ownerId,
              'title': 'Tarea personal',
            },
          ])
          .select('id');
      final taskIds = (createdTasks as List)
          .map((r) => (r as Map)['id'] as String)
          .toList();
      final occurrences = await client
          .from('task_occurrences')
          .select('id, task_id')
          .inFilter('task_id', taskIds);
      final mine = (occurrences as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      expect(mine.length >= 2, isTrue);
      for (final occurrence in mine) {
        await client
            .from('task_occurrences')
            .update({'status': 'completed', 'completed_by': ownerId})
            .eq('id', occurrence['id'] as String);
      }
      final garden = await client
          .from('garden_progress_events')
          .select('id, project_id, event_type, flower_type')
          .eq('user_id', ownerId);
      expect(garden.length >= 2, isTrue);
      expect(
        (garden as List).any((r) => (r as Map)['project_id'] == null),
        isTrue,
        reason: 'La tarea personal debe generar evento de jardín',
      );

      // 3) Finanzas: distribución equal + borrado completo (regresión SQL).
      final transaction = await client
          .from('transactions')
          .insert({
            'owner_id': ownerId,
            'type': 'expense',
            'amount': 10,
            'description': 'Gasto live',
            'created_by': ownerId,
          })
          .select()
          .single();
      final transactionId = transaction['id'] as String;
      await client.from('cost_distributions').insert([
        {
          'source_type': 'expense',
          'source_id': transactionId,
          'project_id': projectId,
          'mode': 'equal',
          'share_value': 1,
        },
        {
          'source_type': 'expense',
          'source_id': transactionId,
          'project_id': projectId,
          'mode': 'equal',
          'share_value': 1,
        },
      ]);
      await client
          .from('cost_distributions')
          .delete()
          .eq('source_id', transactionId);
      expect(
        await client
            .from('cost_distributions')
            .select('id')
            .eq('source_id', transactionId),
        isEmpty,
      );

      // 4) Storage: evidencia de tarea con política específica por bucket.
      final occurrenceId = mine.first['id'] as String;
      final path = '$ownerId/tasks/$occurrenceId/live_test.txt';
      await client.storage
          .from('task-evidence')
          .uploadBinary(
            path,
            Uint8List.fromList('díauno'.codeUnits),
            fileOptions: FileOptions(contentType: 'text/plain'),
          );
      await client.from('files').insert({
        'owner_id': ownerId,
        'uploaded_by': ownerId,
        'project_id': projectId,
        'occurrence_id': occurrenceId,
        'bucket': 'task-evidence',
        'storage_path': path,
        'file_name': 'live_test.txt',
        'mime_type': 'text/plain',
        'size_bytes': 7,
      });
      final signed = await client.storage
          .from('task-evidence')
          .createSignedUrl(path, 60);
      expect(signed, contains('token='));

      // 5) Segundo usuario: RLS, roles y acceso cruzado.
      await client.auth.signUp(
        email: otherEmail,
        password: password,
        data: {'display_name': 'Other Prueba'},
      );
      final otherId = client.auth.currentUser!.id;
      expect(otherId, isNot(ownerId));
      final foreignProjects = await client
          .from('projects')
          .select('id')
          .eq('id', projectId);
      expect(
        foreignProjects,
        isEmpty,
        reason: 'RLS debe ocultar proyecto ajeno',
      );

      var rejectedGarden = false;
      try {
        await client.from('garden_progress_events').insert({
          'project_id': projectId,
          'user_id': otherId,
          'event_type': 'milestone',
          'points': 999,
        });
      } catch (_) {
        rejectedGarden = true;
      }
      expect(
        rejectedGarden,
        isTrue,
        reason: 'No se permiten eventos arbitrarios',
      );

      var rejectedOwner = false;
      try {
        await client.from('project_members').insert({
          'project_id': projectId,
          'user_id': otherId,
          'role': 'owner',
        });
      } catch (_) {
        rejectedOwner = true;
      }
      expect(rejectedOwner, isTrue, reason: 'Nadie debe autoasignarse owner');

      // 6) Logout y persistencia de sesión: cerrar sesión borra el token local.
      await client.auth.signOut();
      expect(client.auth.currentSession, isNull);
      await client.auth.signInWithPassword(
        email: ownerEmail,
        password: password,
      );
      expect(client.auth.currentUser!.id, ownerId);

      // 7) Limpieza de datos de prueba propiedad del owner.
      await client.from('transactions').delete().eq('id', transactionId);
      await client.from('projects').delete().eq('id', projectId);
      await client
          .from('garden_progress_events')
          .delete()
          .eq('user_id', ownerId);
      await client.from('tasks').delete().eq('id', taskIds.last);
      await client.storage.from('task-evidence').remove([path]);
      await client.auth.signOut();
    },
    skip: live ? false : 'Requiere .env.local y DIAUNO_LIVE_TESTS=1',
  );
}
