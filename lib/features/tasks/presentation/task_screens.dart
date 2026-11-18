import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/money_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../projects/application/projects_controller.dart';
import '../../time/application/time_controller.dart';
import '../application/tasks_controller.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({this.projectId, this.dueDate, super.key});

  final String? projectId;
  final String? dueDate;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _startDate = TextEditingController();
  final _dueTime = TextEditingController();
  final _interval = TextEditingController(text: '1');
  String? _projectId;
  TaskPriority _priority = TaskPriority.medium;
  Recurrence _recurrence = Recurrence.none;
  int _estimatedMinutes = 25;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _startDate.text = widget.dueDate ?? Date.today().iso;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _startDate.dispose();
    _dueTime.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final start = Date.tryParse(_startDate.text);
    if (start == null) {
      setState(() => _error = 'La fecha debe tener formato YYYY-MM-DD.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = await ref
          .read(taskActionsProvider.notifier)
          .currentUserId();
      final task = TaskItem(
        id: '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        priority: _priority,
        recurrence: _recurrence,
        recurrenceInterval: int.tryParse(_interval.text) ?? 1,
        startDate: start,
        dueTime: _dueTime.text.trim().isEmpty ? null : _dueTime.text.trim(),
        projectId: _projectId,
        createdBy: userId,
        estimatedMinutes: _estimatedMinutes,
      );
      final created = await ref.read(taskActionsProvider.notifier).create(task);
      if (_recurrence != Recurrence.none) {
        await ref
            .read(taskActionsProvider.notifier)
            .materializeRecurrences(created.id, start.addMonths(6));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva tarea')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
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
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startDate,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de inicio',
                          ),
                          validator: (v) => Date.tryParse(v ?? '') == null
                              ? 'YYYY-MM-DD'
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _dueTime,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Hora (opcional)',
                            hintText: '09:30',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  projects.when(
                    data: (list) => DropdownButtonFormField<String?>(
                      initialValue: _projectId,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto',
                        prefixIcon: Icon(Icons.grid_view_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Personal'),
                        ),
                        ...list.map(
                          (project) => DropdownMenuItem<String?>(
                            value: project.id,
                            child: Text(project.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => Text(
                      'No se pudieron cargar los proyectos.',
                      style: TextStyle(color: p.error),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<TaskPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Prioridad'),
                    items: TaskPriority.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _priority = v ?? _priority),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Recurrence>(
                          initialValue: _recurrence,
                          decoration: const InputDecoration(
                            labelText: 'Repetición',
                          ),
                          items: Recurrence.values
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _recurrence = v ?? _recurrence),
                        ),
                      ),
                      if (_recurrence != Recurrence.none) ...[
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: _interval,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cada',
                            ),
                            validator: (v) =>
                                (int.tryParse(v ?? '') ?? 0) > 0 ? null : '> 0',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_recurrence != Recurrence.none)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Próximas fechas: ${generateOccurrences(start: Date.tryParse(_startDate.text) ?? Date.today(), recurrence: _recurrence, interval: int.tryParse(_interval.text) ?? 1, until: (Date.tryParse(_startDate.text) ?? Date.today()).addWeeks(4)).take(4).map((d) => d.shortDate).join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<int>(
                    initialValue: _estimatedMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Duración estimada',
                    ),
                    items: [15, 25, 45, 60, 90, 120]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(formatDuration(v * 60)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _estimatedMinutes = v ?? 25),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: p.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar tarea'),
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

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({required this.occurrenceId, super.key});

  final String occurrenceId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occurrenceAsync = ref.watch(
      taskDetailOccurrenceProvider(widget.occurrenceId),
    );
    return AsyncView(
      value: occurrenceAsync,
      onRetry: () =>
          ref.invalidate(taskDetailOccurrenceProvider(widget.occurrenceId)),
      builder: (context, occurrence) {
        if (occurrence == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tarea')),
            body: const Center(
              child: Text('Esta tarea ya no está disponible.'),
            ),
          );
        }
        final task = occurrence.task;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle de tarea'),
            actions: [
              IconButton(
                tooltip: 'Iniciar temporizador',
                icon: const Icon(Icons.play_arrow),
                onPressed: () async {
                  try {
                    await ref
                        .read(timeActionsProvider.notifier)
                        .start(occurrenceId: occurrence.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Temporizador iniciado.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task?.title ?? 'Tarea',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        StatusChip(
                          label: occurrence.status.label,
                          tone: occurrence.status == TaskStatus.completed
                              ? StateTone.success
                              : StateTone.accent,
                        ),
                        StatusChip(
                          label: occurrence.dueDate.longDate,
                          tone: StateTone.neutral,
                          icon: Icons.calendar_today,
                        ),
                        if (task != null)
                          StatusChip(
                            label: task.priority.label,
                            tone: task.priority == TaskPriority.low
                                ? StateTone.neutral
                                : StateTone.warning,
                          ),
                      ],
                    ),
                    if (task != null && task.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        task.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if (task != null && task.recurrence != Recurrence.none) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Serie ${task.recurrence.label} cada ${task.recurrenceInterval}. '
                        'Esta ocurrencia conserva su propio historial.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () async {
                        final next = occurrence.status == TaskStatus.completed
                            ? TaskStatus.pending
                            : TaskStatus.completed;
                        try {
                          await ref
                              .read(taskActionsProvider.notifier)
                              .setStatus(occurrence.id, next);
                          ref.invalidate(
                            taskDetailOccurrenceProvider(occurrence.id),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        occurrence.status == TaskStatus.completed
                            ? Icons.replay
                            : Icons.check,
                      ),
                      label: Text(
                        occurrence.status == TaskStatus.completed
                            ? 'Reabrir ocurrencia'
                            : 'Marcar completada',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Comentarios',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView(
                      value: ref.watch(taskCommentsProvider(occurrence.id)),
                      empty: (list) => list.isEmpty,
                      builder: (context, comments) => Column(
                        children: comments
                            .map(
                              (c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.comment_outlined,
                                  size: 18,
                                ),
                                title: Text(
                                  c.authorName ?? 'Participante',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                subtitle: Text(c.body),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _comment,
                            decoration: const InputDecoration(
                              labelText: 'Escribe un comentario',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filled(
                          tooltip: 'Enviar',
                          onPressed: () async {
                            final body = _comment.text.trim();
                            if (body.isEmpty) return;
                            try {
                              await ref
                                  .read(taskActionsProvider.notifier)
                                  .addComment(occurrence.id, body);
                              _comment.clear();
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Evidencia',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView(
                      value: ref.watch(taskEvidenceProvider(occurrence.id)),
                      empty: (list) => list.isEmpty,
                      builder: (context, files) => Column(
                        children: files
                            .map(
                              (f) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.attach_file),
                                title: Text(f.$2),
                                onTap: () async {
                                  final url = await ref
                                      .read(tasksRepositoryProvider)
                                      .signedEvidenceUrl(f.$3);
                                  await launchUrl(
                                    Uri.parse(url),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
