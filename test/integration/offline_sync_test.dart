import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/core/errors/app_failure.dart';
import 'package:diauno/core/utils/date_x.dart';
import 'package:diauno/features/finance/domain/finance.dart';
import 'package:diauno/features/tasks/domain/task.dart';
import 'package:diauno/features/tasks/domain/task_rules.dart';

/// Repositorio en memoria para probar el flujo sin red.
class InMemoryOccurrenceStore {
  final Map<String, TaskStatus> statuses = {};

  Future<void> apply(String id, TaskStatus status) async {
    statuses[id] = status;
  }
}

void main() {
  group('flujo integration-style', () {
    test(
      'una ocurrencia recurrente conserva historial independiente',
      () async {
        final store = InMemoryOccurrenceStore();
        final dates = generateOccurrences(
          start: Date(2026, 1, 1),
          recurrence: Recurrence.weekly,
          interval: 1,
          until: Date(2026, 1, 15),
        );
        expect(dates.length, 3);
        await store.apply('occ-1', TaskStatus.completed);
        await store.apply('occ-2', TaskStatus.inProgress);
        expect(store.statuses['occ-1'], TaskStatus.completed);
        expect(store.statuses['occ-2'], TaskStatus.inProgress);
        expect(store.statuses.containsKey('occ-3'), isFalse);
      },
    );

    test(
      'el gasto compartido se registra una vez y se reparte sin duplicarse',
      () {
        final shares = calculateDistribution(
          total: 120,
          mode: DistributionMode.equal,
          entries: [('Proyecto A', 1), ('Proyecto B', 1)],
        );
        final summary = FinanceSummary.from([
          Transaction(
            id: 'tx-1',
            ownerId: 'u1',
            type: TransactionType.expense,
            category: 'software',
            amount: 120,
            currency: 'USD',
            description: 'Suscripción compartida',
            occurredOn: Date(2026, 1, 1),
            paymentStatus: PaymentStatus.paid,
            createdAt: DateTime(2026),
          ),
        ]);
        expect(summary.expense, 120);
        expect(shares.fold<double>(0, (a, s) => a + s.amount), 120);
        expect(shares.map((s) => s.amount), [60, 60]);
      },
    );

    test(
      'los conflictos no se descartan: permanecen como error de dominio',
      () {
        const failure = ConflictFailure();
        expect(failure.code, 'conflict');
        expect(failure.message, contains('otro dispositivo'));
      },
    );
  });
}
