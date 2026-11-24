import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/money_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../finance/domain/finance.dart';
import '../../garden/domain/garden.dart';
import '../../projects/domain/project.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tasks/domain/task.dart';
import '../application/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final today = Date.today();
    final first = (user?.userMetadata ?? const {})['display_name'] as String?;
    final greeting = first == null || first.trim().isEmpty
        ? 'Hola'
        : 'Hola, ${first.trim().split(' ').first}';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    today.longDate[0].toUpperCase() +
                        today.longDate.substring(1),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: paletteFor(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AsyncView(
                    value: ref.watch(homeDataProvider),
                    onRetry: () => ref.invalidate(homeDataProvider),
                    builder: (context, data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TodayProgress(data: data),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Para hoy',
                          action: 'Ver agenda',
                          onAction: () => context.go('/agenda'),
                        ),
                        if (data.todayTasks.isEmpty && data.events.isEmpty)
                          const EmptyState(
                            icon: Icons.check_circle_outline,
                            title: 'Día despejado',
                            message:
                                'No tienes tareas ni eventos programados para hoy.',
                          )
                        else
                          Column(
                            children: [
                              ...data.todayTasks
                                  .take(5)
                                  .map(
                                    (o) => _TaskRow(occurrence: o, ref: ref),
                                  ),
                              ...data.events
                                  .where((e) => _isToday(e))
                                  .take(3)
                                  .map((e) => _EventRow(event: e)),
                            ],
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Tus proyectos',
                          action: 'Todos',
                          onAction: () => context.go('/projects'),
                        ),
                        if (data.projects.isEmpty)
                          const EmptyState(
                            icon: Icons.grid_view_outlined,
                            title: 'Aún no hay proyectos',
                            message:
                                'Crea tu primer proyecto para empezar a organizarte.',
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: data.projects
                                .take(4)
                                .map(
                                  (p) => SizedBox(
                                    width: _cardWidth(context),
                                    child: _ProjectTile(project: p),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Próximos pagos',
                          action: 'Finanzas',
                          onAction: () => context.push('/finance'),
                        ),
                        if (data.upcomingPayments.isEmpty)
                          const EmptyState(
                            icon: Icons.payments_outlined,
                            title: 'Sin pagos próximos',
                            message:
                                'Cuando registres suscripciones compartidas aparecerán aquí.',
                          )
                        else
                          Column(
                            children: data.upcomingPayments
                                .map((s) => _PaymentRow(subscription: s))
                                .toList(),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Tu jardín',
                          action: 'Abrir',
                          onAction: () => context.go('/garden'),
                        ),
                        _GardenSummary(events: data.gardenEvents),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Más adelante',
                          action: 'Agenda',
                          onAction: () => context.go('/agenda'),
                        ),
                        if (data.upcomingTasks.isEmpty)
                          const EmptyState(
                            icon: Icons.event_available_outlined,
                            title: 'Nada pendiente',
                            message:
                                'No hay tareas programadas para los próximos días.',
                          )
                        else
                          Column(
                            children: data.upcomingTasks
                                .take(4)
                                .map(
                                  (o) => _TaskRow(
                                    occurrence: o,
                                    ref: ref,
                                    showDate: true,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tasks/new'),
        tooltip: 'Nueva tarea',
        child: const Icon(Icons.add),
      ),
    );
  }
}

bool _isToday(AgendaEvent event) =>
    event.startsAt.year == DateTime.now().year &&
    event.startsAt.month == DateTime.now().month &&
    event.startsAt.day == DateTime.now().day;

double _cardWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 760) return (AppSpacing.contentMaxWidth - AppSpacing.md) / 2;
  return width - AppSpacing.lg * 2;
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final total = data.todayTasks.length;
    final done = data.todayTasks
        .where((o) => o.status == TaskStatus.completed)
        .length;
    final percent = total == 0 ? 0 : (done * 100 / total).round();
    return Semantics(
      label: 'Progreso de hoy: $done de $total tareas completadas',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avance de hoy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$percent %',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: p.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 8,
                backgroundColor: p.surfaceMuted,
                color: p.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              total == 0
                  ? 'Añade una tarea para empezar el día.'
                  : '$done de $total tareas completadas · ${data.events.length} evento(s) hoy',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(color: paletteFor(context).text),
                ),
              ),
              if (action != null)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: compact
                        ? MaterialTapTargetSize.shrinkWrap
                        : null,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? AppSpacing.xs : AppSpacing.md,
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    action!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({
    required this.occurrence,
    required this.ref,
    this.showDate = false,
  });

  final TaskOccurrence occurrence;
  final WidgetRef ref;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final p = paletteFor(context);
    final done = occurrence.status == TaskStatus.completed;
    return InkWell(
      onTap: () => context.push('/tasks/${occurrence.id}'),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Semantics(
              button: true,
              selected: done,
              child: Checkbox(
                value: done,
                onChanged: (_) async {
                  try {
                    await ref
                        .read(taskActionsProvider.notifier)
                        .setStatus(
                          occurrence.id,
                          done ? TaskStatus.pending : TaskStatus.completed,
                        );
                  } catch (_) {}
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occurrence.task?.title ?? 'Tarea',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? p.textSecondary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (showDate) occurrence.dueDate.shortDate,
                      if (occurrence.task?.dueTime != null)
                        occurrence.task!.dueTime!,
                      occurrence.task?.projectId == null
                          ? 'Personal'
                          : 'Proyecto',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AgendaEvent event;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(event.title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        event.allDay
            ? 'Todo el día'
            : DateFormat('HH:mm').format(event.startsAt),
      ),
      onTap: () => context.push('/agenda/events/${event.id}'),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final color = Color(
      int.parse(project.colorHex.replaceFirst('#', 'FF'), radix: 16),
    );
    return InkWell(
      onTap: () => context.push('/projects/${project.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: project.progressPercent / 100,
                minHeight: 6,
                backgroundColor: p.surfaceMuted,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${project.progressPercent}% · ${project.completedTasks}/${project.totalTasks} tareas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: p.surfaceMuted,
        child: Icon(Icons.autorenew, size: 18, color: p.primary),
      ),
      title: Text(
        subscription.name,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(subscription.nextPaymentDate?.shortDate ?? 'Sin fecha'),
      trailing: Text(
        formatMoney(subscription.amount, currency: subscription.currency),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: p.primary),
      ),
      onTap: () => context.push('/shared/subscriptions/${subscription.id}'),
    );
  }
}

class _GardenSummary extends StatelessWidget {
  const _GardenSummary({required this.events});

  final List<GardenEvent> events;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final points = events.fold<int>(0, (a, e) => a + e.points);
    final flower = GardenRules.flowerForPoints(points);
    return InkWell(
      onTap: () => context.go('/garden'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(Icons.eco, color: p.primary, size: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GardenRules.flowerLabel(flower),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$points puntos · ${events.length} eventos recientes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
