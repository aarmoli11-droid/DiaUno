import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/core/errors/app_failure.dart';
import 'package:diauno/core/utils/date_x.dart';
import 'package:diauno/features/finance/domain/finance.dart';

Transaction _tx({
  required String id,
  required TransactionType type,
  required double amount,
  required Date date,
  PaymentStatus status = PaymentStatus.paid,
}) {
  return Transaction(
    id: id,
    ownerId: 'u1',
    type: type,
    category: 'general',
    amount: amount,
    currency: 'USD',
    description: id,
    occurredOn: date,
    paymentStatus: status,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('calculateDistribution', () {
    test('partes iguales conserva el total y reparte el céntimo sobrante', () {
      final shares = calculateDistribution(
        total: 10,
        mode: DistributionMode.equal,
        entries: [('A', 1), ('B', 1), ('C', 1)],
      );
      expect(shares.map((s) => s.amount), [3.34, 3.33, 3.33]);
      final sum = shares.fold<double>(0, (a, s) => a + s.amount);
      expect(sum, closeTo(10, 0.001));
    });

    test('porcentajes redondean a céntimos', () {
      final shares = calculateDistribution(
        total: 100,
        mode: DistributionMode.percent,
        entries: [('A', 33.33), ('B', 66.67)],
      );
      expect(shares.map((s) => s.amount), [33.33, 66.67]);
    });

    test('importes no pueden superar el total', () {
      expect(
        () => calculateDistribution(
          total: 50,
          mode: DistributionMode.amount,
          entries: [('A', 30), ('B', 30)],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('porcentajes no pueden superar 100', () {
      expect(
        () => calculateDistribution(
          total: 50,
          mode: DistributionMode.percent,
          entries: [('A', 101)],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('FinanceSummary', () {
    test('excluye cancelados y cuenta pendientes como gasto', () {
      final summary = FinanceSummary.from([
        _tx(
          id: 'i',
          type: TransactionType.income,
          amount: 100,
          date: Date(2026, 1, 1),
        ),
        _tx(
          id: 'e',
          type: TransactionType.expense,
          amount: 30,
          date: Date(2026, 1, 2),
        ),
        _tx(
          id: 'p',
          type: TransactionType.expense,
          amount: 20,
          date: Date(2026, 1, 3),
          status: PaymentStatus.pending,
        ),
        _tx(
          id: 'c',
          type: TransactionType.expense,
          amount: 999,
          date: Date(2026, 1, 4),
          status: PaymentStatus.cancelled,
        ),
      ]);
      expect(summary.income, 100);
      expect(summary.expense, 50);
      expect(summary.pending, 20);
      expect(summary.balance, 50);
    });

    test('filterTransactions acota el mes solicitado', () {
      final items = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 1,
          date: Date(2026, 1, 31),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 2,
          date: Date(2026, 2, 1),
        ),
      ];
      final result = filterTransactions(
        items,
        FinancePeriod.month,
        today: Date(2026, 1, 15),
      );
      expect(result.map((t) => t.id), ['1']);
    });
  });
}
