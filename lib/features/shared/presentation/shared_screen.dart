import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../finance/application/finance_controller.dart';
import '../../finance/domain/finance.dart';

class SharedScreen extends ConsumerWidget {
  const SharedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider);
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
                    'Compartidos',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Suscripciones y costes repartidos una sola vez.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: paletteFor(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/shared/subscriptions/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Suscripción'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/finance'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Ver finanzas'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Suscripciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AsyncView(
                    value: subscriptions,
                    onRetry: () => ref.invalidate(subscriptionsProvider),
                    empty: (list) => list.isEmpty,
                    builder: (context, list) => Column(
                      children: list
                          .map((s) => _SubscriptionTile(subscription: s))
                          .toList(),
                    ),
                  ),
                  if (subscriptions.value?.isEmpty ?? true)
                    const EmptyState(
                      icon: Icons.autorenew,
                      title: 'Sin suscripciones',
                      message:
                          'Registra un servicio compartido para repartir su coste.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar suscripción',
        onPressed: () => context.push('/shared/subscriptions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return InkWell(
      onTap: () => context.push('/shared/subscriptions/${subscription.id}'),
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
            CircleAvatar(
              backgroundColor: p.surfaceMuted,
              child: Icon(Icons.autorenew, color: p.primary, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${subscription.provider.isEmpty ? subscription.billingCycle.label : subscription.provider} · ${subscription.nextPaymentDate?.shortDate ?? 'sin fecha'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(
                    subscription.amount,
                    currency: subscription.currency,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: p.primary),
                ),
                if (subscription.isShared)
                  const StatusChip(label: 'Compartida', tone: StateTone.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
