import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_x.dart';
import '../data/agenda_repository.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.watch(supabaseProvider)),
);

typedef AgendaScope = ({Date from, Date to});

final agendaEventsProvider =
    FutureProvider.family<List<AgendaEvent>, AgendaScope>((ref, scope) {
      return ref
          .watch(agendaRepositoryProvider)
          .listEvents(scope.from, scope.to);
    });

final agendaActionsProvider = NotifierProvider<AgendaActions, bool>(
  AgendaActions.new,
);

class AgendaActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<AgendaEvent> create(AgendaEvent event) async {
    final created = await ref.read(agendaRepositoryProvider).createEvent(event);
    ref.invalidate(agendaEventsProvider);
    return created;
  }

  Future<void> update(AgendaEvent event) async {
    await ref.read(agendaRepositoryProvider).updateEvent(event);
    ref.invalidate(agendaEventsProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(agendaRepositoryProvider).deleteEvent(id);
    ref.invalidate(agendaEventsProvider);
  }
}
