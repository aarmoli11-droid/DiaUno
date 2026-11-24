import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_x.dart';
import '../data/finance_repository.dart';
import '../domain/finance.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(supabaseProvider)),
);

final transactionsProvider =
    FutureProvider.family<List<Transaction>, ({Date? from, Date? to})>(
      (ref, scope) => ref
          .watch(financeRepositoryProvider)
          .listTransactions(from: scope.from, to: scope.to),
    );

final subscriptionsProvider = FutureProvider<List<Subscription>>(
  (ref) => ref.watch(financeRepositoryProvider).listSubscriptions(),
);

final financeSummaryProvider =
    Provider.family<FinanceSummary, List<Transaction>>((ref, items) {
      return FinanceSummary.from(items);
    });

final financeActionsProvider = NotifierProvider<FinanceActions, bool>(
  FinanceActions.new,
);

class FinanceActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<Transaction> createTransaction(Transaction transaction) async {
    final created = await ref
        .read(financeRepositoryProvider)
        .createTransaction(transaction);
    ref.invalidate(transactionsProvider);
    return created;
  }

  Future<void> setTransactionStatus(String id, PaymentStatus status) async {
    await ref
        .read(financeRepositoryProvider)
        .updateTransactionStatus(id, status);
    ref.invalidate(transactionsProvider);
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(financeRepositoryProvider).deleteTransaction(id);
    ref.invalidate(transactionsProvider);
    ref.invalidate(subscriptionsProvider);
    ref.read(appDataRevisionProvider.notifier).bump();
  }

  Future<Subscription> createSubscription(Subscription subscription) async {
    final created = await ref
        .read(financeRepositoryProvider)
        .createSubscription(subscription);
    ref.invalidate(subscriptionsProvider);
    return created;
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await ref.read(financeRepositoryProvider).updateSubscription(subscription);
    ref.invalidate(subscriptionsProvider);
  }

  Future<void> deleteSubscription(String id) async {
    await ref.read(financeRepositoryProvider).deleteSubscription(id);
    ref.invalidate(subscriptionsProvider);
    ref.invalidate(transactionsProvider);
    ref.read(appDataRevisionProvider.notifier).bump();
  }

  Future<void> saveDistribution({
    required String sourceType,
    required String sourceId,
    required DistributionMode mode,
    required List<({String? projectId, String? userId, double value})> shares,
  }) async {
    await ref
        .read(financeRepositoryProvider)
        .saveDistribution(
          sourceType: sourceType,
          sourceId: sourceId,
          mode: mode,
          shares: shares,
        );
  }
}
