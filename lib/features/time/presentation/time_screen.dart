import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../projects/application/projects_controller.dart';
import '../application/time_controller.dart';

class TimeScreen extends ConsumerStatefulWidget {
  const TimeScreen({super.key});

  @override
  ConsumerState<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends ConsumerState<TimeScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final active = ref.watch(activeTimerProvider);
    final entries = ref.watch(timeEntriesProvider);
    final projects = ref.watch(projectsProvider);
    final activeEntry = active.value;
    if (activeEntry != null && _startedAt == null) {
      _startedAt = activeEntry.startedAt.toLocal();
      _elapsed = DateTime.now().difference(_startedAt!);
    }
    if (activeEntry == null) _startedAt = null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tiempo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatDuration(_elapsed.inSeconds),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(color: p.primary, fontSize: 46),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        activeEntry == null
                            ? 'Sin temporizador activo'
                            : 'Temporizador en curso',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (activeEntry == null)
                        FilledButton.icon(
                          onPressed: () async {
                            final list = projects.value ?? const [];
                            if (list.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Crea un proyecto antes de iniciar el temporizador.',
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await ref
                                  .read(timeActionsProvider.notifier)
                                  .start(projectId: list.first.id);
                              ref.invalidate(activeTimerProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar temporizador'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(timeActionsProvider.notifier)
                                .stop(activeEntry.id);
                            _startedAt = null;
                            _elapsed = Duration.zero;
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Detener y guardar'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Registro manual',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showManualDialog(context, ref),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Añadir tiempo manualmente'),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Registros',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AsyncView(
                  value: entries,
                  empty: (list) => list.isEmpty,
                  builder: (context, list) => Column(
                    children: list
                        .map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              e.isManual ? Icons.edit_calendar : Icons.timer,
                              size: 18,
                            ),
                            title: Text(
                              e.description.isEmpty
                                  ? (e.projectId == null
                                        ? 'Tiempo registrado'
                                        : 'Proyecto')
                                  : e.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              DateFormat(
                                'd MMM',
                                'es',
                              ).format(e.startedAt.toLocal()),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatDuration(e.durationSeconds)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await ref
                                        .read(timeActionsProvider.notifier)
                                        .delete(e.id);
                                  },
                                ),
                              ],
                            ),
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
  }
}

Future<void> _showManualDialog(BuildContext context, WidgetRef ref) async {
  final hours = TextEditingController(text: '1');
  final minutes = TextEditingController(text: '0');
  final description = TextEditingController();
  final projects = ref.read(projectsProvider).value ?? const [];
  String? projectId = projects.firstOrNull?.id;
  String? error;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Registro manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Proyecto'),
                items: [
                  ...projects.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => projectId = v),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: hours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Horas'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Descripción'),
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
            onPressed: () async {
              final duration = Duration(
                hours: int.tryParse(hours.text) ?? 0,
                minutes: int.tryParse(minutes.text) ?? 0,
              );
              if (duration.inSeconds <= 0 || projectId == null) {
                setState(() => error = 'Indica una duración y un proyecto.');
                return;
              }
              try {
                await ref
                    .read(timeActionsProvider.notifier)
                    .addManual(
                      duration: duration,
                      date: DateTime.now(),
                      projectId: projectId,
                      description: description.text.trim(),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                setState(() => error = e.toString());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
