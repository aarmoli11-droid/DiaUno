import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_x.dart';
import '../../agenda/application/agenda_controller.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../finance/application/finance_controller.dart';
import '../../finance/domain/finance.dart';
import '../../garden/application/garden_controller.dart';
import '../../garden/domain/garden.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/project.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tasks/domain/task.dart';

class HomeData {
  const HomeData({
    required this.projects,
    required this.todayTasks,
    required this.upcomingTasks,
    required this.events,
    required this.upcomingPayments,
    required this.gardenEvents,
  });

  final List<Project> projects;
  final List<TaskOccurrence> todayTasks;
  final List<TaskOccurrence> upcomingTasks;
  final List<AgendaEvent> events;
  final List<Subscription> upcomingPayments;
  final List<GardenEvent> gardenEvents;
}

Future<T> _safe<T>(Future<T> future, T fallback) =>
    future.catchError((_) => fallback);

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final today = Date.today();
  final tasksRepo = ref.watch(tasksRepositoryProvider);
  final agendaRepo = ref.watch(agendaRepositoryProvider);
  final financeRepo = ref.watch(financeRepositoryProvider);
  final projectsRepo = ref.watch(projectsRepositoryProvider);
  final gardenRepo = ref.watch(gardenRepositoryProvider);

  final results = await Future.wait<Object>([
    _safe(projectsRepo.listProjects(), <Project>[]),
    _safe(
      tasksRepo.listOccurrences(from: today, to: today),
      <TaskOccurrence>[],
    ),
    _safe(
      tasksRepo.listOccurrences(from: today.addDays(1), to: today.addDays(14)),
      <TaskOccurrence>[],
    ),
    _safe(agendaRepo.listEvents(today, today.addDays(14)), <AgendaEvent>[]),
    _safe(financeRepo.listSubscriptions(), <Subscription>[]),
    _safe(gardenRepo.listEvents(), <GardenEvent>[]),
  ]);

  final subscriptions = results[4] as List<Subscription>;
  final payments =
      subscriptions
          .where(
            (s) =>
                s.status == 'active' &&
                s.nextPaymentDate != null &&
                s.nextPaymentDate!.compareTo(today.addDays(30)) <= 0,
          )
          .toList()
        ..sort((a, b) => a.nextPaymentDate!.compareTo(b.nextPaymentDate!));

  return HomeData(
    projects: results[0] as List<Project>,
    todayTasks: results[1] as List<TaskOccurrence>,
    upcomingTasks: results[2] as List<TaskOccurrence>,
    events: results[3] as List<AgendaEvent>,
    upcomingPayments: payments.take(5).toList(),
    gardenEvents: (results[5] as List<GardenEvent>).take(5).toList(),
  );
});
