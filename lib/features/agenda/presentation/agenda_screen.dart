import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tasks/domain/task.dart';
import '../application/agenda_controller.dart';
import '../data/agenda_repository.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  final _focused = ValueNotifier<DateTime>(DateTime.now());
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.week;

  @override
  void dispose() {
    _focused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final from = Date.fromDateTime(_selected).addDays(-(_selected.weekday - 1));
    final to = from.addWeeks(2);
    final events = ref.watch(agendaEventsProvider((from: from, to: to)));
    final tasks = ref.watch(
      taskOccurrencesProvider((
        from: Date.fromDateTime(_selected),
        to: Date.fromDateTime(_selected),
        projectId: null,
      )),
    );
    final dayEvents =
        events.value
            ?.where(
              (e) =>
                  e.startsAt.year == _selected.year &&
                  e.startsAt.month == _selected.month &&
                  e.startsAt.day == _selected.day,
            )
            .toList() ??
        [];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Eventos y tareas con fechas independientes.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _focused,
                builder: (context, focused, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: TableCalendar(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2100),
                    focusedDay: focused,
                    selectedDayPredicate: (day) => isSameDay(day, _selected),
                    calendarFormat: _format,
                    availableCalendarFormats: const {
                      CalendarFormat.week: 'Semana',
                      CalendarFormat.month: 'Mes',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    locale: 'es_ES',
                    headerStyle: HeaderStyle(
                      formatButtonDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: p.border),
                      ),
                      formatButtonTextStyle: Theme.of(
                        context,
                      ).textTheme.labelMedium!,
                      titleTextStyle: Theme.of(context).textTheme.titleMedium!,
                      leftChevronIcon: Icon(Icons.chevron_left, color: p.text),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: p.text,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      defaultTextStyle: Theme.of(context).textTheme.bodyMedium!,
                      weekendTextStyle: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: p.textSecondary),
                      outsideTextStyle: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: p.border),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: Theme.of(context).textTheme.labelMedium!,
                      weekendStyle: Theme.of(context).textTheme.labelMedium!,
                    ),
                    eventLoader: (day) =>
                        events.value
                            ?.where(
                              (e) =>
                                  e.startsAt.year == day.year &&
                                  e.startsAt.month == day.month &&
                                  e.startsAt.day == day.day,
                            )
                            .map((e) => e.title)
                            .toList() ??
                        [],
                    onDaySelected: (selected, focusedDay) {
                      setState(() => _selected = selected);
                      _focused.value = focusedDay;
                    },
                    onFormatChanged: (format) =>
                        setState(() => _format = format),
                    onPageChanged: (focusedDay) => _focused.value = focusedDay,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, d MMMM', 'es').format(_selected),
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: compact ? AppSpacing.xs : AppSpacing.sm,
                        ),
                        AgendaQuickAddTaskButton(
                          date: _selected,
                          compact: compact,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AsyncView(
                  value: events,
                  empty: (_) => dayEvents.isEmpty,
                  builder: (context, _) => Column(
                    children: dayEvents
                        .map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 4,
                              height: 42,
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            title: Text(
                              e.title,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              e.allDay
                                  ? 'Todo el día'
                                  : '${DateFormat('HH:mm').format(e.startsAt)} – ${DateFormat('HH:mm').format(e.endsAt)}',
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => context.push('/agenda/events/${e.id}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  'Tareas del día',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AsyncView(
                  value: tasks,
                  empty: (list) => list.isEmpty,
                  builder: (context, list) => Column(
                    children: list
                        .map(
                          (o) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              o.status == TaskStatus.completed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: o.status == TaskStatus.completed
                                  ? p.success
                                  : p.border,
                            ),
                            title: Text(
                              o.task?.title ?? 'Tarea',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    decoration: o.status == TaskStatus.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            subtitle: Text(o.task?.dueTime ?? 'Sin hora'),
                            onTap: () => context.push('/tasks/${o.id}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva tarea',
        onPressed: () =>
            context.push('/tasks/new?date=${Date.fromDateTime(_selected).iso}'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Acceso rápido situado bajo el calendario.
///
/// Apunta al mismo formulario de tareas que el botón inferior, sin estado de
/// carga propio. Antes abría `/agenda/events/new`, que colisiona con la ruta
/// de edición `events/:eventId` y dejaba la pantalla cargando indefinidamente.
class AgendaQuickAddTaskButton extends StatelessWidget {
  const AgendaQuickAddTaskButton({
    required this.date,
    required this.compact,
    super.key,
  });

  final DateTime date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () =>
          context.push('/tasks/new?date=${Date.fromDateTime(date).iso}'),
      icon: Icon(
        compact ? Icons.add : Icons.add_task_outlined,
        size: compact ? 18 : null,
      ),
      label: Text(compact ? 'Nuevo' : 'Nueva tarea'),
    );
  }
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _start = TimeOfDay.now();
  TimeOfDay _end = TimeOfDay(
    hour: (TimeOfDay.now().hour + 1) % 24,
    minute: TimeOfDay.now().minute,
  );
  bool _allDay = false;
  bool _loading = false;
  String? _error;
  AgendaEvent? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) _load();
  }

  Future<void> _load() async {
    try {
      final event = await ref
          .read(agendaRepositoryProvider)
          .getEvent(widget.eventId!);
      if (!mounted) return;
      if (event != null) {
        _existing = event;
        _title.text = event.title;
        _description.text = event.description;
        _location.text = event.location ?? '';
        _date = event.startsAt;
        _start = TimeOfDay.fromDateTime(event.startsAt);
        _end = TimeOfDay.fromDateTime(event.endsAt);
        _allDay = event.allDay;
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el evento: $e');
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _allDay ? 0 : _start.hour,
      _allDay ? 0 : _start.minute,
    );
    final end = _allDay
        ? start
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1))
        : DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);
    try {
      final event = AgendaEvent(
        id: _existing?.id ?? '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        startsAt: start,
        endsAt: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
        allDay: _allDay,
        ownerId: _existing?.ownerId ?? ref.read(currentUserProvider)?.id ?? '',
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      );
      if (_existing == null) {
        await ref.read(agendaActionsProvider.notifier).create(event);
      } else {
        await ref.read(agendaActionsProvider.notifier).update(event);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eventId != null && !_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nuevo evento' : 'Editar evento'),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref
                    .read(agendaActionsProvider.notifier)
                    .delete(_existing!.id);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe un título'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(_date.longDate),
                    trailing: const Text('Cambiar'),
                    onTap: _pickDate,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Todo el día'),
                    value: _allDay,
                    onChanged: (v) => setState(() => _allDay = v),
                  ),
                  if (!_allDay) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text('Inicio: ${_start.format(context)}'),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _start,
                        );
                        if (picked != null) setState(() => _start = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text('Fin: ${_end.format(context)}'),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _end,
                        );
                        if (picked != null) setState(() => _end = picked);
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Lugar (opcional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar evento'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
