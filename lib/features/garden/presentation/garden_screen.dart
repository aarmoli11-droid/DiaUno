import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../projects/application/projects_controller.dart';
import '../application/garden_controller.dart';
import '../domain/garden.dart';

class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(gardenEventsProvider(null));
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
                  Text(
                    'Jardín',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tu progreso real, representado de forma sencilla.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: paletteFor(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AsyncView(
                    value: events,
                    onRetry: () => ref.invalidate(gardenEventsProvider(null)),
                    builder: (context, gardenEvents) {
                      // Las tareas personales no tienen proyecto: se agrupan
                      // bajo null y siguen sumando al total del jardín.
                      final byProject = <String?, int>{};
                      for (final event in gardenEvents) {
                        byProject[event.projectId] =
                            (byProject[event.projectId] ?? 0) + event.points;
                      }
                      final total = byProject.values.fold<int>(
                        0,
                        (a, b) => a + b,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GardenCanvas(points: total),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '${GardenRules.flowerLabel(GardenRules.flowerForPoints(total))} · $total puntos acumulados',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Las flores aparecen cuando completas ocurrencias reales. Tocar una flor muestra su proyecto.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Proyectos en flor',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AsyncView(
                            value: projects,
                            empty: (list) => list.isEmpty,
                            builder: (context, projectList) => Column(
                              children: projectList.map((project) {
                                final points = byProject[project.id] ?? 0;
                                return _ProjectBloom(
                                  projectName: project.name,
                                  progress: project.progressPercent,
                                  points: points,
                                  projectId: project.id,
                                  onSelect: () =>
                                      _showBloom(context, project.name, points),
                                );
                              }).toList(),
                            ),
                          ),
                          if (gardenEvents.isEmpty)
                            const EmptyState(
                              icon: Icons.eco_outlined,
                              title: 'El jardín está germinando',
                              message:
                                  'Completa tareas de un proyecto para ver crecer su primera flor.',
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Historial',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (gardenEvents.isEmpty)
                            Text(
                              'Aún no hay eventos.',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            Column(
                              children: gardenEvents
                                  .take(8)
                                  .map(
                                    (e) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.eco, size: 18),
                                      title: Text(
                                        '${e.points} puntos · ${e.projectName ?? "Proyecto"}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      subtitle: Text(e.eventType),
                                      trailing: Text(
                                        e.createdAt.shortDate,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      );
                    },
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

void _showBloom(BuildContext context, String name, int points) {
  final p = paletteFor(context);
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$points puntos · ${GardenRules.flowerLabel(GardenRules.flowerForPoints(points))}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: p.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Esta flor refleja los cumplimientos registrados. No otorga recompensas aleatorias.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProjectBloom extends StatelessWidget {
  const _ProjectBloom({
    required this.projectName,
    required this.progress,
    required this.points,
    required this.projectId,
    required this.onSelect,
  });

  final String projectName;
  final int progress;
  final int points;
  final String projectId;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final stage = GardenRules.treeStage(progress);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CustomPaint(
                painter: _FlowerPainter(
                  color: p.primary,
                  accent: p.accent,
                  petals: 4 + stage,
                  scale: 0.55,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${GardenRules.stageLabel(stage)} · $progress% · $points puntos',
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

class _GardenCanvas extends StatelessWidget {
  const _GardenCanvas({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final flower = GardenRules.flowerForPoints(points);
    return GestureDetector(
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              local.dx < box.size.width / 2
                  ? 'Cada flor viene de una tarea completada.'
                  : '${GardenRules.flowerLabel(flower)}: $points puntos reales.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: p.border),
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: _GardenPainter(
            sky: p.surfaceMuted,
            ground: p.primary.withValues(alpha: 0.25),
            sun: p.warning,
            stem: p.primary,
            petal: p.accent,
            points: points,
          ),
        ),
      ),
    );
  }
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter({
    required this.sky,
    required this.ground,
    required this.sun,
    required this.stem,
    required this.petal,
    required this.points,
  });

  final Color sky;
  final Color ground;
  final Color sun;
  final Color stem;
  final Color petal;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);

    final horizon = size.height * 0.72;
    final groundPaint = Paint()..color = ground;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
        bottomLeft: const Radius.circular(24),
        bottomRight: const Radius.circular(24),
      ),
      groundPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.2),
      24,
      Paint()..color = sun,
    );

    final flowerCount = math.min(1 + points ~/ 40, 7);
    final random = math.Random(points * 7919 + 13);
    for (var i = 0; i < flowerCount; i++) {
      final x =
          size.width * (0.12 + 0.76 * (i / math.max(1, flowerCount - 1))) +
          (i == 0 ? 0 : random.nextInt(14) - 7);
      final height = 42 + random.nextDouble() * 38;
      final base = Offset(x, horizon + 12);
      final petalRadius = 6 + random.nextDouble() * 4;
      final flowerPainter = _FlowerPainter(
        color: stem,
        accent: petal,
        petals: 5 + (i % 3),
        scale: 1,
        stemHeight: height,
        petalRadius: petalRadius,
      );
      canvas.save();
      canvas.translate(x - 30, base.dy - height - 24);
      flowerPainter.paint(canvas, Size(60, height + 60));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({
    required this.color,
    required this.accent,
    required this.petals,
    required this.scale,
    this.stemHeight,
    this.petalRadius,
  });

  final Color color;
  final Color accent;
  final int petals;
  final double scale;
  final double? stemHeight;
  final double? petalRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (stemHeight == null) {
      final radius = 14 * scale;
      for (var i = 0; i < petals; i++) {
        final angle = 2 * math.pi * i / petals;
        canvas.drawCircle(
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          6 * scale,
          Paint()..color = accent,
        );
      }
      canvas.drawCircle(center, 6 * scale, Paint()..color = color);
      return;
    }

    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final baseY = size.height * 0 + stemHeight! + 30;
    final flowerCenter = Offset(size.width / 2, 30);
    canvas.drawLine(Offset(size.width / 2, baseY), flowerCenter, stemPaint);
    final radius = petalRadius ?? 8;
    for (var i = 0; i < petals; i++) {
      final angle = 2 * math.pi * i / petals;
      canvas.drawCircle(
        flowerCenter +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        radius * 0.75,
        Paint()..color = accent,
      );
    }
    canvas.drawCircle(flowerCenter, radius * 0.7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter oldDelegate) =>
      oldDelegate.petals != petals || oldDelegate.color != color;
}
