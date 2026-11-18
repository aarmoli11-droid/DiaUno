import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_x.dart';

enum DistributionMode { amount, percent, equal }

enum TransactionType { income, expense }

enum PaymentStatus { pending, paid, overdue, cancelled }

enum FinancePeriod { day, week, month, range }

enum BillingCycle { weekly, monthly, quarterly, yearly }

extension TransactionTypeX on TransactionType {
  String get value => name;
  static TransactionType from(String value) =>
      TransactionType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => TransactionType.expense,
      );
}

extension PaymentStatusX on PaymentStatus {
  String get value => name;
  String get label => switch (this) {
    PaymentStatus.pending => 'Pendiente',
    PaymentStatus.paid => 'Pagado',
    PaymentStatus.overdue => 'Vencido',
    PaymentStatus.cancelled => 'Cancelado',
  };
  static PaymentStatus from(String value) => PaymentStatus.values.firstWhere(
    (p) => p.name == value,
    orElse: () => PaymentStatus.pending,
  );
}

extension DistributionModeX on DistributionMode {
  String get value => name;
  String get label => switch (this) {
    DistributionMode.amount => 'Importes',
    DistributionMode.percent => 'Porcentajes',
    DistributionMode.equal => 'Partes iguales',
  };
  static DistributionMode from(String value) => DistributionMode.values
      .firstWhere((m) => m.name == value, orElse: () => DistributionMode.equal);
}

extension BillingCycleX on BillingCycle {
  String get value => name;
  String get label => switch (this) {
    BillingCycle.weekly => 'Semanal',
    BillingCycle.monthly => 'Mensual',
    BillingCycle.quarterly => 'Trimestral',
    BillingCycle.yearly => 'Anual',
  };
  static BillingCycle from(String value) => BillingCycle.values.firstWhere(
    (b) => b.name == value,
    orElse: () => BillingCycle.monthly,
  );
}

class Transaction {
  const Transaction({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.category,
    required this.amount,
    required this.currency,
    required this.description,
    required this.occurredOn,
    required this.paymentStatus,
    this.projectId,
    this.subscriptionId,
    this.dueDate,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final TransactionType type;
  final String category;
  final double amount;
  final String currency;
  final String description;
  final Date occurredOn;
  final PaymentStatus paymentStatus;
  final String? projectId;
  final String? subscriptionId;
  final Date? dueDate;
  final String? reference;
  final DateTime createdAt;

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    type: TransactionTypeX.from(map['type'] as String),
    category: map['category'] as String? ?? 'general',
    amount: (map['amount'] as num).toDouble(),
    currency: map['currency'] as String? ?? 'USD',
    description: map['description'] as String? ?? '',
    occurredOn:
        Date.tryParse(map['occurred_on'] as String? ?? '') ?? Date.today(),
    paymentStatus: PaymentStatusX.from(
      map['payment_status'] as String? ?? 'paid',
    ),
    projectId: map['project_id'] as String?,
    subscriptionId: map['subscription_id'] as String?,
    dueDate: Date.tryParse(map['due_date'] as String?),
    reference: map['reference'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  Map<String, dynamic> toInsert(String userId) => {
    'owner_id': userId,
    'created_by': userId,
    'type': type.value,
    'category': category,
    'amount': amount,
    'currency': currency,
    'description': description,
    'occurred_on': occurredOn.iso,
    'due_date': dueDate?.iso,
    'payment_status': paymentStatus.value,
    'project_id': projectId,
    'subscription_id': subscriptionId,
    'reference': reference,
  };
}

class Subscription {
  const Subscription({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.status,
    required this.isShared,
    required this.createdAt,
    this.projectId,
    this.nextPaymentDate,
    int? distributionCount,
  }) : distributionCount = distributionCount ?? 0;

  final String id;
  final String ownerId;
  final String name;
  final String provider;
  final double amount;
  final String currency;
  final BillingCycle billingCycle;
  final String status;
  final bool isShared;
  final DateTime createdAt;
  final String? projectId;
  final Date? nextPaymentDate;
  final int distributionCount;

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String,
    provider: map['provider'] as String? ?? '',
    amount: (map['amount'] as num).toDouble(),
    currency: map['currency'] as String? ?? 'USD',
    billingCycle: BillingCycleX.from(
      map['billing_cycle'] as String? ?? 'monthly',
    ),
    status: map['status'] as String? ?? 'active',
    isShared: map['is_shared'] as bool? ?? false,
    createdAt: DateTime.parse(map['created_at'] as String),
    projectId: map['project_id'] as String?,
    nextPaymentDate: Date.tryParse(map['next_payment_date'] as String?),
    distributionCount: (map['distribution_count'] as num?)?.toInt(),
  );

  Map<String, dynamic> toInsert(String userId) => {
    'owner_id': userId,
    'created_by': userId,
    'name': name,
    'provider': provider,
    'amount': amount,
    'currency': currency,
    'billing_cycle': billingCycle.value,
    'next_payment_date': nextPaymentDate?.iso,
    'status': status,
    'is_shared': isShared,
    'project_id': projectId,
  };

  Map<String, dynamic> toUpdate() => {
    'name': name,
    'provider': provider,
    'amount': amount,
    'currency': currency,
    'billing_cycle': billingCycle.value,
    'next_payment_date': nextPaymentDate?.iso,
    'status': status,
    'is_shared': isShared,
    'project_id': projectId,
  };
}

class DistributionShare {
  const DistributionShare(this.label, this.value, this.amount);

  final String label;
  final double value;
  final double amount;
}

/// Cálculo puro de distribuciones. No duplica el gasto: solo reparte su importe.
List<DistributionShare> calculateDistribution({
  required double total,
  required DistributionMode mode,
  required List<(String label, double value)> entries,
}) {
  if (total <= 0) {
    throw const ValidationFailure('El importe debe ser mayor que cero.');
  }
  if (entries.isEmpty) {
    throw const ValidationFailure('Añade al menos un participante o proyecto.');
  }

  switch (mode) {
    case DistributionMode.amount:
      final sum = entries.fold<double>(0, (a, e) => a + e.$2);
      if (sum > total + 0.01) {
        throw const ValidationFailure('La suma de importes supera el total.');
      }
      return entries.map((e) => DistributionShare(e.$1, e.$2, e.$2)).toList();

    case DistributionMode.percent:
      final sum = entries.fold<double>(0, (a, e) => a + e.$2);
      if (sum > 100.01) {
        throw const ValidationFailure(
          'La suma de porcentajes supera el 100 %.',
        );
      }
      return entries
          .map(
            (e) => DistributionShare(
              e.$1,
              e.$2,
              (total * e.$2 / 100 * 100).roundToDouble() / 100,
            ),
          )
          .toList();

    case DistributionMode.equal:
      final raw = total / entries.length;
      final per = (raw * 100).roundToDouble() / 100;
      var remaining =
          (total * 100).round() - (per * 100).round() * entries.length;
      return entries.map((e) {
        var amount = per;
        if (remaining > 0) {
          amount += 0.01;
          remaining--;
        }
        return DistributionShare(e.$1, 1, amount);
      }).toList();
  }
}

class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
    required this.pending,
    required this.count,
  });

  final double income;
  final double expense;
  final double pending;
  final int count;
  double get balance => income - expense;

  factory FinanceSummary.from(List<Transaction> items) {
    var income = 0.0;
    var expense = 0.0;
    var pending = 0.0;
    for (final t in items) {
      if (t.paymentStatus == PaymentStatus.cancelled) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
        if (t.paymentStatus == PaymentStatus.pending ||
            t.paymentStatus == PaymentStatus.overdue) {
          pending += t.amount;
        }
      }
    }
    return FinanceSummary(
      income: income,
      expense: expense,
      pending: pending,
      count: items.length,
    );
  }
}

List<Transaction> filterTransactions(
  List<Transaction> items,
  FinancePeriod period, {
  Date? start,
  Date? end,
  Date? today,
}) {
  final now = today ?? Date.today();
  final (from, to) = switch (period) {
    FinancePeriod.day => (now, now),
    FinancePeriod.week => (
      now.addDays(-(now.weekday - 1)),
      now.addDays(7 - now.weekday),
    ),
    FinancePeriod.month => (
      Date(now.year, now.month, 1),
      Date(now.year, now.month, DateTime(now.year, now.month + 1, 0).day),
    ),
    FinancePeriod.range => (start ?? now, end ?? now),
  };
  return items
      .where(
        (t) =>
            t.occurredOn.compareTo(from) >= 0 &&
            t.occurredOn.compareTo(to) <= 0,
      )
      .toList();
}
