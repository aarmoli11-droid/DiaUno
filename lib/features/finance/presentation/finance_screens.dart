import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/money_x.dart';
import '../../../shared/widgets/async_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/finance_controller.dart';
import '../domain/finance.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  FinancePeriod _period = FinancePeriod.month;
  Date? _start;
  Date? _end;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final transactions = ref.watch(
      transactionsProvider((from: null, to: null)),
    );
    final filtered = transactions.whenData(
      (list) => filterTransactions(list, _period, start: _start, end: _end),
    );
    final summary = FinanceSummary.from(filtered.value ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final csv = ref
                  .read(financeRepositoryProvider)
                  .exportCsv(filtered.value ?? const []);
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copiado al portapapeles.')),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<FinancePeriod>(
                  segments: const [
                    ButtonSegment(value: FinancePeriod.day, label: Text('Hoy')),
                    ButtonSegment(
                      value: FinancePeriod.week,
                      label: Text('Semana'),
                    ),
                    ButtonSegment(
                      value: FinancePeriod.month,
                      label: Text('Mes'),
                    ),
                    ButtonSegment(
                      value: FinancePeriod.range,
                      label: Text('Rango'),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (values) async {
                    if (values.first == FinancePeriod.range) {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (range == null) return;
                      _start = Date.fromDateTime(range.start);
                      _end = Date.fromDateTime(range.end);
                    }
                    setState(() => _period = values.first);
                  },
                ),
              ),
            ),
            _SummaryStrip(summary: summary, currency: 'USD'),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: AsyncView(
                value: filtered,
                onRetry: () => ref.invalidate(transactionsProvider),
                empty: (list) => list.isEmpty,
                builder: (context, list) => ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = list[index];
                    final isIncome = t.type == TransactionType.income;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: p.surfaceMuted,
                        child: Icon(
                          isIncome ? Icons.south_west : Icons.north_east,
                          color: isIncome ? p.success : p.error,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        t.description.isEmpty ? t.category : t.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        '${t.occurredOn.shortDate} · ${t.category} · ${t.paymentStatus == PaymentStatus.paid
                            ? 'Pagado'
                            : t.paymentStatus == PaymentStatus.pending
                            ? 'Pendiente'
                            : t.paymentStatus == PaymentStatus.overdue
                            ? 'Vencido'
                            : 'Cancelado'}',
                      ),
                      trailing: Text(
                        '${isIncome ? '+' : '-'}${formatMoney(t.amount, currency: t.currency)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: isIncome ? p.success : p.text),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar movimiento',
        onPressed: () => context.push('/finance/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.currency});

  final FinanceSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _SummaryCell(
            label: 'Ingresos',
            value: formatMoney(summary.income, currency: currency),
            color: p.success,
          ),
          _SummaryCell(
            label: 'Gastos',
            value: formatMoney(summary.expense, currency: currency),
            color: p.error,
          ),
          _SummaryCell(
            label: 'Balance',
            value: formatMoney(summary.balance, currency: currency),
            color: p.primary,
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController(text: 'general');
  final _date = TextEditingController(text: Date.today().iso);
  TransactionType _type = TransactionType.expense;
  PaymentStatus _status = PaymentStatus.paid;
  String _currency = 'USD';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _category.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final date = Date.tryParse(_date.text);
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (date == null || amount == null || amount <= 0) {
      setState(() => _error = 'Revisa la fecha y el importe.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserProvider)?.id ?? '';
      final transaction = Transaction(
        id: '',
        ownerId: userId,
        type: _type,
        category: _category.text.trim().isEmpty
            ? 'general'
            : _category.text.trim(),
        amount: amount,
        currency: _currency,
        description: _description.text.trim(),
        occurredOn: date,
        paymentStatus: _status,
        createdAt: DateTime.now(),
      );
      await ref
          .read(financeActionsProvider.notifier)
          .createTransaction(transaction);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar movimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Gasto'),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Ingreso'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (v) => setState(() => _type = v.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _description,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe una descripción'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Importe',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                              ? null
                              : 'Mayor que cero',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'CRC', child: Text('CRC')),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'USD'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _date,
                          decoration: const InputDecoration(
                            labelText: 'Fecha (YYYY-MM-DD)',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _category,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<PaymentStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: PaymentStatus.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InfoCard(
                    text:
                        'El importe histórico es inmutable: se guarda una vez y no se reescribe.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
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
                        : const Text('Guardar movimiento'),
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

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: p.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({this.subscriptionId, super.key});

  final String? subscriptionId;

  @override
  ConsumerState<SubscriptionFormScreen> createState() =>
      _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState
    extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _provider = TextEditingController();
  final _amount = TextEditingController();
  final _nextPayment = TextEditingController();
  BillingCycle _cycle = BillingCycle.monthly;
  bool _shared = true;
  bool _saving = false;
  String? _error;
  Subscription? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionId != null) _load();
  }

  Future<void> _load() async {
    final subs = await ref.read(subscriptionsProvider.future);
    final found = subs
        .where((s) => s.id == widget.subscriptionId)
        .cast<Subscription?>()
        .firstOrNull;
    if (!mounted) return;
    if (found != null) {
      _existing = found;
      _name.text = found.name;
      _provider.text = found.provider;
      _amount.text = found.amount.toStringAsFixed(2);
      _nextPayment.text = found.nextPaymentDate?.iso ?? '';
      _cycle = found.billingCycle;
      _shared = found.isShared;
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _amount.dispose();
    _nextPayment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Importe no válido.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserProvider)?.id ?? '';
      final subscription = Subscription(
        id: _existing?.id ?? '',
        ownerId: _existing?.ownerId ?? userId,
        name: _name.text.trim(),
        provider: _provider.text.trim(),
        amount: amount,
        currency: 'USD',
        billingCycle: _cycle,
        status: 'active',
        isShared: _shared,
        createdAt: _existing?.createdAt ?? DateTime.now(),
        nextPaymentDate: Date.tryParse(_nextPayment.text),
        distributionCount: _existing?.distributionCount,
      );
      if (_existing == null) {
        final created = await ref
            .read(financeActionsProvider.notifier)
            .createSubscription(subscription);
        if (!mounted) return;
        context.go('/shared/distributions/subscription/${created.id}');
      } else {
        await ref
            .read(financeActionsProvider.notifier)
            .updateSubscription(subscription);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subscriptionId != null && !_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Nueva suscripción' : 'Editar suscripción',
        ),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: () async {
                await ref
                    .read(financeActionsProvider.notifier)
                    .deleteSubscription(_existing!.id);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _provider,
                    decoration: const InputDecoration(labelText: 'Proveedor'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Importe'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<BillingCycle>(
                    initialValue: _cycle,
                    decoration: const InputDecoration(labelText: 'Ciclo'),
                    items: BillingCycle.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _cycle = v ?? _cycle),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _nextPayment,
                    decoration: const InputDecoration(
                      labelText: 'Próximo pago (YYYY-MM-DD)',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compartida'),
                    subtitle: const Text(
                      'Permite distribuir el coste entre proyectos/personas.',
                    ),
                    value: _shared,
                    onChanged: (v) => setState(() => _shared = v),
                  ),
                  const InfoCard(
                    text:
                        'La suscripción se registra una sola vez. Las distribuciones reparten ese importe; no crean gastos nuevos.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
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
                        : const Text('Guardar suscripción'),
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

class DistributionScreen extends ConsumerStatefulWidget {
  const DistributionScreen({
    required this.sourceType,
    required this.sourceId,
    super.key,
  });

  final String sourceType;
  final String sourceId;

  @override
  ConsumerState<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends ConsumerState<DistributionScreen> {
  final _entries = <(String label, double value)>[];
  final _label = TextEditingController();
  final _value = TextEditingController();
  DistributionMode _mode = DistributionMode.equal;
  double _total = 0;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.sourceType == 'subscription') {
      final subs = await ref.read(subscriptionsProvider.future);
      for (final s in subs) {
        if (s.id == widget.sourceId) {
          _total = s.amount;
          break;
        }
      }
    } else {
      final list = await ref.read(
        transactionsProvider((from: null, to: null)).future,
      );
      for (final t in list) {
        if (t.id == widget.sourceId) {
          _total = t.amount;
          break;
        }
      }
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  void _addEntry() {
    final label = _label.text.trim();
    final value = double.tryParse(_value.text.replaceAll(',', '.'));
    if (label.isEmpty || value == null) return;
    setState(() {
      _entries.add((label, value));
      _label.clear();
      _value.clear();
    });
  }

  List<({String? projectId, String? userId, double value})> _toShares(
    List<DistributionShare> shares,
  ) {
    // La UI usa etiquetas legibles; el backend exige ids. Para la versión 1 se
    // guardan como proyecto cuando la etiqueta coincide con un id UUID.
    return shares
        .map(
          (s) => (
            projectId: RegExp(r'^[0-9a-f-]{36}$').hasMatch(s.label)
                ? s.label
                : null,
            userId: null,
            value: s.value,
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final shares = calculateDistribution(
        total: _total,
        mode: _mode,
        entries: _entries,
      );
      await ref
          .read(financeActionsProvider.notifier)
          .saveDistribution(
            sourceType: widget.sourceType,
            sourceId: widget.sourceId,
            mode: _mode,
            shares: _toShares(shares),
          );
      if (mounted) context.pop();
    } on ValidationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    List<DistributionShare> preview = [];
    String? previewError;
    try {
      preview = calculateDistribution(
        total: _total,
        mode: _mode,
        entries: _entries,
      );
    } on ValidationFailure catch (e) {
      previewError = e.message;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Distribuir coste')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoCard(
                  text:
                      'Total a repartir: ${formatMoney(_total)}. El gasto original no se duplica.',
                ),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<DistributionMode>(
                  segments: DistributionMode.values
                      .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                      .toList(),
                  selected: {_mode},
                  onSelectionChanged: (v) => setState(() => _mode = v.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _label,
                        decoration: InputDecoration(
                          labelText: _mode == DistributionMode.equal
                              ? 'Participante / proyecto'
                              : 'Participante',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _value,
                        enabled: _mode != DistributionMode.equal,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _mode == DistributionMode.amount
                              ? 'Importe'
                              : _mode == DistributionMode.percent
                              ? '%'
                              : '1 parte',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Añadir',
                      onPressed: _addEntry,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_entries.isEmpty)
                  const EmptyState(
                    icon: Icons.group_outlined,
                    title: 'Sin participantes',
                    message:
                        'Añade al menos una persona o proyecto para repartir el coste.',
                  )
                else
                  Column(
                    children: _entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.$1),
                        subtitle: Text(
                          _mode == DistributionMode.equal
                              ? '1 parte'
                              : _mode == DistributionMode.percent
                              ? '${item.$2} %'
                              : formatMoney(item.$2),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _entries.removeAt(index)),
                        ),
                      );
                    }).toList(),
                  ),
                if (previewError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      previewError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else if (preview.isNotEmpty) ...[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    'Vista previa',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...preview.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.label),
                      trailing: Text(formatMoney(s.amount)),
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving || previewError != null || _entries.isEmpty
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar distribución'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
