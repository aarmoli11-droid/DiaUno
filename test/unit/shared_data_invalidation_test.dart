import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/core/utils/date_x.dart';
import 'package:diauno/features/finance/application/finance_controller.dart';
import 'package:diauno/features/finance/data/finance_repository.dart';
import 'package:diauno/features/finance/domain/finance.dart';
import 'package:diauno/features/garden/application/garden_controller.dart';
import 'package:diauno/features/garden/data/garden_repository.dart';
import 'package:diauno/features/garden/domain/garden.dart';
import 'package:diauno/features/projects/application/projects_controller.dart';
import 'package:diauno/features/projects/data/projects_repository.dart';
import 'package:diauno/features/projects/domain/project.dart';
import 'package:diauno/features/tasks/application/tasks_controller.dart';
import 'package:diauno/features/tasks/data/tasks_repository.dart';
import 'package:diauno/features/tasks/domain/task.dart';

SupabaseClient _client() => SupabaseClient(
  'http://127.0.0.1:54321',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _TasksFake extends TasksRepository {
  _TasksFake() : super(_client());

  int occurrenceReads = 0;
  int statusWrites = 0;

  @override
  Future<List<TaskOccurrence>> listOccurrences({
    Date? from,
    Date? to,
    String? projectId,
  }) async {
    occurrenceReads++;
    return const <TaskOccurrence>[];
  }

  @override
  Future<TaskOccurrence> setOccurrenceStatus(
    String occurrenceId,
    TaskStatus status, {
    DateTime? expectedUpdatedAt,
  }) async {
    statusWrites++;
    return TaskOccurrence(
      id: occurrenceId,
      taskId: 'task-1',
      dueDate: const Date(2026, 1, 1),
      status: status,
    );
  }
}

class _GardenFake extends GardenRepository {
  _GardenFake() : super(_client());

  int reads = 0;

  @override
  Future<List<GardenEvent>> listEvents({String? projectId}) async {
    reads++;
    return const <GardenEvent>[];
  }
}

class _ProjectsFake extends ProjectsRepository {
  _ProjectsFake() : super(_client());

  int reads = 0;
  int deletes = 0;

  @override
  Future<List<Project>> listProjects() async {
    reads++;
    return const <Project>[];
  }

  @override
  Future<void> deleteProject(String id) async {
    deletes++;
  }
}

class _FinanceFake extends FinanceRepository {
  _FinanceFake() : super(_client());

  int transactionReads = 0;
  int subscriptionReads = 0;
  int transactionDeletes = 0;
  int subscriptionDeletes = 0;

  @override
  Future<List<Transaction>> listTransactions({Date? from, Date? to}) async {
    transactionReads++;
    return const <Transaction>[];
  }

  @override
  Future<List<Subscription>> listSubscriptions() async {
    subscriptionReads++;
    return const <Subscription>[];
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactionDeletes++;
  }

  @override
  Future<void> deleteSubscription(String id) async {
    subscriptionDeletes++;
  }
}

({TaskScope scope, ProviderContainer container}) _setup({
  required _TasksFake tasks,
  required _GardenFake garden,
  required _ProjectsFake projects,
  required _FinanceFake finance,
}) {
  final container = ProviderContainer(
    overrides: [
      isOnlineProvider.overrideWithValue(true),
      tasksRepositoryProvider.overrideWithValue(tasks),
      gardenRepositoryProvider.overrideWithValue(garden),
      projectsRepositoryProvider.overrideWithValue(projects),
      financeRepositoryProvider.overrideWithValue(finance),
    ],
  );
  addTearDown(container.dispose);
  return (
    scope: (
      from: const Date(2026, 1, 1),
      to: const Date(2026, 1, 31),
      projectId: null,
    ),
    container: container,
  );
}

void main() {
  test(
    'completar una tarea refresca ocurrencias, jardín y proyectos',
    () async {
      final tasks = _TasksFake();
      final garden = _GardenFake();
      final projects = _ProjectsFake();
      final finance = _FinanceFake();
      final setup = _setup(
        tasks: tasks,
        garden: garden,
        projects: projects,
        finance: finance,
      );
      final container = setup.container;
      final scope = setup.scope;

      await container.read(gardenEventsProvider(null).future);
      await container.read(taskOccurrencesProvider(scope).future);
      await container.read(projectsProvider.future);
      final revision = container.read(appDataRevisionProvider);
      expect(garden.reads, 1);
      expect(tasks.occurrenceReads, 1);
      expect(projects.reads, 1);

      await container
          .read(taskActionsProvider.notifier)
          .setStatus('occurrence-1', TaskStatus.completed);

      expect(tasks.statusWrites, 1);
      await container.read(gardenEventsProvider(null).future);
      await container.read(taskOccurrencesProvider(scope).future);
      await container.read(projectsProvider.future);
      expect(garden.reads, 2);
      expect(tasks.occurrenceReads, 2);
      expect(projects.reads, 2);
      expect(container.read(appDataRevisionProvider), revision + 1);
    },
  );

  test('borrar un proyecto refresca tareas, jardín y finanzas', () async {
    final tasks = _TasksFake();
    final garden = _GardenFake();
    final projects = _ProjectsFake();
    final finance = _FinanceFake();
    final setup = _setup(
      tasks: tasks,
      garden: garden,
      projects: projects,
      finance: finance,
    );
    final container = setup.container;
    final scope = setup.scope;
    final financeScope = (from: null, to: null);

    await container.read(projectsProvider.future);
    await container.read(taskOccurrencesProvider(scope).future);
    await container.read(gardenEventsProvider(null).future);
    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    final revision = container.read(appDataRevisionProvider);

    await container.read(projectActionsProvider.notifier).delete('project-1');

    expect(projects.deletes, 1);
    await container.read(projectsProvider.future);
    await container.read(taskOccurrencesProvider(scope).future);
    await container.read(gardenEventsProvider(null).future);
    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    expect(projects.reads, 2);
    expect(tasks.occurrenceReads, 2);
    expect(garden.reads, 2);
    expect(finance.transactionReads, 2);
    expect(finance.subscriptionReads, 2);
    expect(container.read(appDataRevisionProvider), revision + 1);
  });

  test('borrar un movimiento financiero refresca todas sus vistas', () async {
    final tasks = _TasksFake();
    final garden = _GardenFake();
    final projects = _ProjectsFake();
    final finance = _FinanceFake();
    final setup = _setup(
      tasks: tasks,
      garden: garden,
      projects: projects,
      finance: finance,
    );
    final container = setup.container;
    final financeScope = (from: null, to: null);

    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    final revision = container.read(appDataRevisionProvider);

    await container
        .read(financeActionsProvider.notifier)
        .deleteTransaction('transaction-1');

    expect(finance.transactionDeletes, 1);
    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    expect(finance.transactionReads, 2);
    expect(finance.subscriptionReads, 2);
    expect(container.read(appDataRevisionProvider), revision + 1);
  });

  test('borrar una suscripción refresca movimientos y suscripciones', () async {
    final tasks = _TasksFake();
    final garden = _GardenFake();
    final projects = _ProjectsFake();
    final finance = _FinanceFake();
    final setup = _setup(
      tasks: tasks,
      garden: garden,
      projects: projects,
      finance: finance,
    );
    final container = setup.container;
    final financeScope = (from: null, to: null);

    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    final revision = container.read(appDataRevisionProvider);

    await container
        .read(financeActionsProvider.notifier)
        .deleteSubscription('subscription-1');

    expect(finance.subscriptionDeletes, 1);
    await container.read(transactionsProvider(financeScope).future);
    await container.read(subscriptionsProvider.future);
    expect(finance.transactionReads, 2);
    expect(finance.subscriptionReads, 2);
    expect(container.read(appDataRevisionProvider), revision + 1);
  });
}
