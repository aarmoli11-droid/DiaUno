import 'package:flutter/material.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';

/// Estado informativo: el envío de notificaciones aún no está disponible.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: p.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Notificaciones no disponibles',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(color: p.text),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Esta función todavía no está disponible en DíaUno.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: p.textSecondary,
                    ),
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
