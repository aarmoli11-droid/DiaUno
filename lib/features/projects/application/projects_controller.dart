import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/local_store.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../finance/application/finance_controller.dart';
import '../../garden/application/garden_controller.dart';
import '../../tasks/application/tasks_controller.dart';
import '../data/project_extras_repository.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(ref.watch(supabaseProvider)),
);

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  return ref.watch(projectsRepositoryProvider).listProjects();
});

final projectDetailProvider = FutureProvider.family<Project, String>((
  ref,
  id,
) async {
  return ref.watch(projectsRepositoryProvider).getProject(id);
});

final projectMembersProvider =
    FutureProvider.family<
      List<(String id, String name, ProjectRole role)>,
      String
    >((ref, id) async {
      return ref.watch(projectsRepositoryProvider).listMembers(id);
    });

final projectExtrasRepositoryProvider = Provider<ProjectExtrasRepository>(
  (ref) => ProjectExtrasRepository(ref.watch(supabaseProvider)),
);

final projectToolsProvider = FutureProvider.family<List<ExternalTool>, String>((
  ref,
  projectId,
) {
  return ref.watch(projectExtrasRepositoryProvider).listTools(projectId);
});

final projectActivityProvider =
    FutureProvider.family<List<ActivityItem>, String>((ref, projectId) {
      return ref.watch(projectExtrasRepositoryProvider).listActivity(projectId);
    });

final projectActionsProvider = NotifierProvider<ProjectActions, bool>(
  ProjectActions.new,
);

class ProjectActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<Project> create(Project project) async {
    final created = await ref
        .read(projectsRepositoryProvider)
        .createProject(project);
    ref.invalidate(projectsProvider);
    return created;
  }

  Future<void> update(Project project, DateTime expectedUpdatedAt) async {
    final online = ref.read(isOnlineProvider);
    if (!online) {
      final store = await ref.read(localStoreProvider.future);
      final userId = ref.read(currentUserProvider)?.id ?? '';
      await store.enqueue(
        PendingMutation(
          id: const Uuid().v4(),
          entity: 'project_update',
          operation: 'update',
          payload: {
            'project': project.toUpdate(userId),
            'id': project.id,
            'expectedUpdatedAt': expectedUpdatedAt.toIso8601String(),
          },
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    await ref
        .read(projectsRepositoryProvider)
        .updateProject(project, expectedUpdatedAt);
    ref.invalidate(projectsProvider);
    ref.invalidate(projectDetailProvider(project.id));
  }

  Future<void> delete(String id) async {
    await ref.read(projectsRepositoryProvider).deleteProject(id);
    // Un proyecto arrastra tareas, jardín y finanzas. Todas las vistas que los
    // consumen deben refrescarse, no sólo la lista de proyectos.
    ref.invalidate(projectsProvider);
    ref.invalidate(taskOccurrencesProvider);
    ref.invalidate(gardenEventsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(subscriptionsProvider);
    ref.read(appDataRevisionProvider.notifier).bump();
  }

  Future<void> addMember(
    String projectId,
    String userId,
    ProjectRole role,
  ) async {
    await ref
        .read(projectsRepositoryProvider)
        .addMember(projectId, userId, role);
    ref.invalidate(projectMembersProvider(projectId));
    ref.invalidate(projectsProvider);
  }

  Future<void> setMemberRole(
    String projectId,
    String userId,
    ProjectRole role,
  ) async {
    await ref
        .read(projectsRepositoryProvider)
        .updateMemberRole(projectId, userId, role);
    ref.invalidate(projectMembersProvider(projectId));
  }

  Future<void> removeMember(String projectId, String userId) async {
    await ref.read(projectsRepositoryProvider).removeMember(projectId, userId);
    ref.invalidate(projectMembersProvider(projectId));
  }

  Future<void> addTool({
    required String projectId,
    required String name,
    required String url,
    String description = '',
    String category = 'other',
  }) async {
    await ref
        .read(projectExtrasRepositoryProvider)
        .createTool(
          projectId: projectId,
          name: name,
          url: url,
          description: description,
          category: category,
        );
    ref.invalidate(projectToolsProvider(projectId));
    ref.invalidate(projectActivityProvider(projectId));
  }

  Future<void> deleteTool(String projectId, String toolId) async {
    await ref.read(projectExtrasRepositoryProvider).deleteTool(toolId);
    ref.invalidate(projectToolsProvider(projectId));
  }
}
