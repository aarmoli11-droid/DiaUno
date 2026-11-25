import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tasks/domain/task.dart';
import '../application/projects_controller.dart';
import '../domain/project.dart';

String _safeError(Object error) {
  final failure = error is AppFailure ? error : mapPostgrestError(error);
  return failure.message;
}

/// Título de los diálogos de proyectos.
///
/// El estilo por defecto de `AlertDialog` en Material 3 usa `headlineSmall`,
/// que no está definido en [AppTheme] y conserva el color de la tipografía
/// base (oscura). Se conserva la tipografía del tema y se aplica el color
/// semántico resuelto para que responda al cambio claro/oscuro.
class ProjectDialogTitle extends StatelessWidget {
  const ProjectDialogTitle({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Proyectos',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: _showArchived
                            ? 'Ocultar archivados'
                            : 'Mostrar archivados',
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        icon: Icon(
                          _showArchived
                              ? Icons.visibility
                              : Icons.archive_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Cada proyecto concentra sus tareas, finanzas y colaboradores.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: paletteFor(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AsyncView(
                    value: projects,
                    onRetry: () => ref.invalidate(projectsProvider),
                    empty: (list) => list
                        .where((p) => _showArchived || !p.isArchived)
                        .isEmpty,
                    builder: (context, list) {
                      final visible = list
                          .where((p) => _showArchived || !p.isArchived)
                          .toList();
                      return Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: visible
                            .map((p) => _ProjectCard(project: p))
                            .toList(),
                      );
                    },
                  ),
                  if (projects.value?.isEmpty ?? true)
                    const EmptyState(
                      icon: Icons.grid_view_outlined,
                      title: 'Empieza con un proyecto',
                      message:
                          'Agrupa tareas, pagos y personas alrededor de un objetivo.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectForm(context, ref),
        tooltip: 'Nuevo proyecto',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paletteFor(context);
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width >= 740
        ? (AppSpacing.contentMaxWidth - AppSpacing.md) / 2
        : width - 48;
    final color = Color(
      int.parse(project.colorHex.replaceFirst('#', 'FF'), radix: 16),
    );
    return SizedBox(
      width: cardWidth,
      child: InkWell(
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
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(Icons.folder_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (project.myRole != null)
                          Text(
                            project.myRole!.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (project.isArchived)
                    const StatusChip(
                      label: 'Archivado',
                      tone: StateTone.neutral,
                    ),
                ],
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: project.progressPercent / 100,
                        minHeight: 6,
                        backgroundColor: p.surfaceMuted,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${project.progressPercent}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${project.completedTasks}/${project.totalTasks} ocurrencias · 🌱 ${project.gardenPoints}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showProjectForm(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();
  String color = '#2E6B4E';
  String? error;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const ProjectDialogTitle(text: 'Nuevo proyecto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: start,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Inicio (YYYY-MM-DD)',
                  hintText: '2026-01-01',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: end,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Fin (YYYY-MM-DD, opcional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: color,
                decoration: const InputDecoration(labelText: 'Color'),
                items: const [
                  DropdownMenuItem(value: '#2E6B4E', child: Text('Verde')),
                  DropdownMenuItem(value: '#5A4A86', child: Text('Morado')),
                  DropdownMenuItem(value: '#B25A2E', child: Text('Terracota')),
                  DropdownMenuItem(value: '#2E5A86', child: Text('Azul')),
                ],
                onChanged: (v) => setState(() => color = v ?? color),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final trimmed = name.text.trim();
              if (trimmed.isEmpty) {
                setState(() => error = 'Escribe un nombre.');
                return;
              }
              final now = DateTime.now();
              final project = Project(
                id: '',
                ownerId: '',
                name: trimmed,
                description: description.text.trim(),
                colorHex: color,
                iconName: 'folder',
                status: 'active',
                startDate: Date.tryParse(start.text)?.toDateTime(),
                endDate: Date.tryParse(end.text)?.toDateTime(),
                createdAt: now,
                updatedAt: now,
              );
              try {
                await ref.read(projectActionsProvider.notifier).create(project);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (e) {
                setState(() => error = _safeError(e));
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  );
  if (result == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Proyecto creado.')));
  }
}

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({required this.projectId, this.tab, super.key});

  final String projectId;
  final String? tab;

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.tab == 'finance' ? 3 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(projectDetailProvider(widget.projectId));
    return AsyncView(
      value: detail,
      onRetry: () => ref.invalidate(projectDetailProvider(widget.projectId)),
      builder: (context, project) => Scaffold(
        body: DefaultTabController(
          length: 4,
          initialIndex: _tab,
          child: NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              SliverAppBar(
                pinned: true,
                title: Text(project.name),
                actions: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editProject(context, ref, project),
                  ),
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Tareas'),
                    Tab(text: 'Personas'),
                    Tab(text: 'Herramientas'),
                    Tab(text: 'Actividad'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _ProjectTasks(project: project),
                _MembersTab(project: project),
                _ToolsTab(project: project),
                _ActivityTab(project: project),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nueva tarea en este proyecto',
          onPressed: () => context.push('/tasks/new?projectId=${project.id}'),
          child: const Icon(Icons.add_task),
        ),
      ),
    );
  }
}

Future<void> _editProject(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final p = paletteFor(context);
  final name = TextEditingController(text: project.name);
  final description = TextEditingController(text: project.description);
  String status = project.status;
  String? error;
  var deleted = false;
  final canDelete = project.ownerId == ref.read(currentUserProvider)?.id;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const ProjectDialogTitle(text: 'Editar proyecto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Activo')),
                  DropdownMenuItem(value: 'archived', child: Text('Archivado')),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (canDelete)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: p.error),
              onPressed: () async {
                final confirmed = await _confirmDeleteProject(
                  dialogContext,
                  project.name,
                );
                if (!confirmed || !dialogContext.mounted) return;
                try {
                  await ref
                      .read(projectActionsProvider.notifier)
                      .delete(project.id);
                  deleted = true;
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  if (context.mounted) context.go('/projects');
                } catch (e) {
                  if (dialogContext.mounted) {
                    setState(() => error = _safeError(e));
                  }
                }
              },
              child: const Text('Eliminar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final updated = Project(
                id: project.id,
                ownerId: project.ownerId,
                name: name.text.trim().isEmpty
                    ? project.name
                    : name.text.trim(),
                description: description.text.trim(),
                colorHex: project.colorHex,
                iconName: project.iconName,
                status: status,
                startDate: project.startDate,
                endDate: project.endDate,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                myRole: project.myRole,
              );
              try {
                await ref
                    .read(projectActionsProvider.notifier)
                    .update(updated, project.updatedAt);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } on ConflictFailure {
                setState(
                  () => error =
                      'Otro dispositivo cambió este proyecto. Se guardó un conflicto para que decidas.',
                );
              } catch (e) {
                setState(() => error = _safeError(e));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && !deleted && context.mounted) {
    ref.invalidate(projectDetailProvider(project.id));
  }
}

Future<bool> _confirmDeleteProject(BuildContext context, String name) async {
  final p = paletteFor(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Eliminar “$name”?'),
      content: Text(
        'Se borrarán también sus tareas, finanzas, comprobantes y eventos del '
        'jardín. Esta acción no se puede deshacer.',
        style: Theme.of(
          dialogContext,
        ).textTheme.bodyMedium?.copyWith(color: p.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _ProjectTasks extends ConsumerWidget {
  const _ProjectTasks({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = Date.today();
    final occurrences = ref.watch(
      taskOccurrencesProvider((
        from: today.addMonths(-1),
        to: today.addMonths(3),
        projectId: project.id,
      )),
    );
    return AsyncView(
      value: occurrences,
      onRetry: () => ref.invalidate(taskOccurrencesProvider),
      empty: (list) => list.isEmpty,
      builder: (context, list) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final o = list[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: o.status == TaskStatus.completed,
              onChanged: (_) async {
                try {
                  await ref
                      .read(taskActionsProvider.notifier)
                      .setStatus(
                        o.id,
                        o.status == TaskStatus.completed
                            ? TaskStatus.pending
                            : TaskStatus.completed,
                      );
                } catch (_) {}
              },
            ),
            title: Text(
              o.task?.title ?? 'Tarea',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: o.status == TaskStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text('${o.dueDate.shortDate} · ${o.status.label}'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/tasks/${o.id}'),
          );
        },
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(projectMembersProvider(project.id));
    final canManage =
        project.myRole?.canEdit ??
        project.ownerId == ref.watch(currentUserProvider)?.id;
    return AsyncView(
      value: members,
      onRetry: () => ref.invalidate(projectMembersProvider(project.id)),
      builder: (context, list) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ...list.map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline, size: 18),
              ),
              title: Text(m.$2, style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text('Rol: ${m.$3.name}'),
              trailing: canManage && m.$3 != ProjectRole.owner
                  ? DropdownButton<ProjectRole>(
                      value: m.$3,
                      items: ProjectRole.values
                          .where((r) => r != ProjectRole.owner)
                          .map(
                            (r) =>
                                DropdownMenuItem(value: r, child: Text(r.name)),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        try {
                          await ref
                              .read(projectActionsProvider.notifier)
                              .setMemberRole(project.id, m.$1, value);
                        } catch (_) {}
                      },
                    )
                  : StatusChip(label: m.$3.name, tone: StateTone.accent),
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _invite(context, ref, project.id),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invitar colaborador'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _invite(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final query = TextEditingController();
  List<(String id, String name)> results = [];
  (String, ProjectRole)? selected;
  String? error;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Invitar a un proyecto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: query,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre visible',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) async {
                  try {
                    final found = await ref
                        .read(projectExtrasRepositoryProvider)
                        .searchProfiles(value);
                    setState(() => results = found);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (results.isNotEmpty)
                DropdownButtonFormField<(String, ProjectRole)>(
                  decoration: const InputDecoration(labelText: 'Persona y rol'),
                  items: [
                    for (final person in results)
                      for (final role in [
                        ProjectRole.admin,
                        ProjectRole.collaborator,
                        ProjectRole.viewer,
                      ])
                        DropdownMenuItem(
                          value: (person.$1, role),
                          child: Text('${person.$2} · ${role.name}'),
                        ),
                  ],
                  onChanged: (v) => setState(() => selected = v),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: selected == null
                ? null
                : () async {
                    try {
                      await ref
                          .read(projectActionsProvider.notifier)
                          .addMember(projectId, selected!.$1, selected!.$2);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      setState(() => error = _safeError(e));
                    }
                  },
            child: const Text('Añadir'),
          ),
        ],
      ),
    ),
  );
}

class _ToolsTab extends ConsumerWidget {
  const _ToolsTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(projectToolsProvider(project.id));
    return AsyncView(
      value: tools,
      onRetry: () => ref.invalidate(projectToolsProvider(project.id)),
      builder: (context, list) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.link,
              title: 'Sin herramientas',
              message:
                  'Guarda enlaces a tableros, documentos o servicios del proyecto.',
            ),
          ...list.map(
            (tool) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(
                tool.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                tool.description.isEmpty ? tool.url : tool.description,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref
                      .read(projectActionsProvider.notifier)
                      .deleteTool(project.id, tool.id);
                },
              ),
              onTap: () => context.push('/search'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => _addTool(context, ref, project.id),
            icon: const Icon(Icons.add_link),
            label: const Text('Añadir herramienta'),
          ),
        ],
      ),
    );
  }
}

Future<void> _addTool(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final name = TextEditingController();
  final url = TextEditingController();
  final description = TextEditingController();
  String? error;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nueva herramienta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || url.text.trim().isEmpty) {
                setState(() => error = 'Nombre y URL son obligatorios.');
                return;
              }
              try {
                await ref
                    .read(projectActionsProvider.notifier)
                    .addTool(
                      projectId: projectId,
                      name: name.text.trim(),
                      url: url.text.trim(),
                      description: description.text.trim(),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                setState(() => error = _safeError(e));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(projectActivityProvider(project.id));
    return AsyncView(
      value: activity,
      onRetry: () => ref.invalidate(projectActivityProvider(project.id)),
      empty: (list) => list.isEmpty,
      builder: (context, list) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = list[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, size: 18),
            title: Text(
              '${item.actorName ?? 'Alguien'} · ${item.action}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(item.entityType),
            trailing: Text(
              item.createdAt.shortDate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    );
  }
}
