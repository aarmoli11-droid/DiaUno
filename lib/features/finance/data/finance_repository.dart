import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_x.dart';
import '../domain/finance.dart';

class FinanceRepository {
  FinanceRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<Transaction>> listTransactions({Date? from, Date? to}) async {
    var query = _client.from('transactions').select();
    if (from != null) query = query.gte('occurred_on', from.iso);
    if (to != null) query = query.lte('occurred_on', to.iso);
    final rows = await query.order('occurred_on', ascending: false);
    return rows
        .map((r) => Transaction.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Transaction> createTransaction(Transaction transaction) async {
    final row = await _client
        .from('transactions')
        .insert(transaction.toInsert(_userId))
        .select()
        .single();
    return Transaction.fromMap(Map<String, dynamic>.from(row));
  }

  /// Sólo se permiten cambios de estado/metadatos; el importe es inmutable.
  Future<void> updateTransactionStatus(String id, PaymentStatus status) async {
    await _client
        .from('transactions')
        .update({'payment_status': status.value})
        .eq('id', id);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<List<Subscription>> listSubscriptions() async {
    final rows = await _client
        .from('subscriptions')
        .select()
        .order('next_payment_date', ascending: true);
    return rows
        .map((r) => Subscription.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Subscription> createSubscription(Subscription subscription) async {
    final row = await _client
        .from('subscriptions')
        .insert(subscription.toInsert(_userId))
        .select()
        .single();
    return Subscription.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await _client
        .from('subscriptions')
        .update(subscription.toUpdate())
        .eq('id', subscription.id);
  }

  Future<void> deleteSubscription(String id) async {
    await _client.from('subscriptions').delete().eq('id', id);
  }

  Future<
    List<
      (
        String id,
        String sourceType,
        String? projectId,
        String? userId,
        DistributionMode mode,
        double value,
      )
    >
  >
  listDistributions(String sourceType, String sourceId) async {
    final rows = await _client
        .from('cost_distributions')
        .select()
        .eq('source_type', sourceType)
        .eq('source_id', sourceId);
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return (
        m['id'] as String,
        m['source_type'] as String,
        m['project_id'] as String?,
        m['user_id'] as String?,
        DistributionModeX.from(m['mode'] as String),
        (m['share_value'] as num).toDouble(),
      );
    }).toList();
  }

  /// Reemplaza la distribución completa. El gasto sigue registrado una sola vez.
  Future<void> saveDistribution({
    required String sourceType,
    required String sourceId,
    required DistributionMode mode,
    required List<({String? projectId, String? userId, double value})> shares,
  }) async {
    await _client
        .from('cost_distributions')
        .delete()
        .eq('source_type', sourceType)
        .eq('source_id', sourceId);
    if (shares.isEmpty) return;
    final rows = shares
        .map(
          (s) => {
            'source_type': sourceType,
            'source_id': sourceId,
            'project_id': s.projectId,
            'user_id': s.userId,
            'mode': mode.value,
            'share_value': s.value,
          },
        )
        .toList();
    await _client.from('cost_distributions').insert(rows);
  }

  Future<String> uploadReceipt({
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? projectId,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_userId/finance/$transactionId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from('finance-receipts')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client.from('files').insert({
      'owner_id': _userId,
      'uploaded_by': _userId,
      'project_id': projectId,
      'transaction_id': transactionId,
      'bucket': 'finance-receipts',
      'storage_path': path,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
    });
    return path;
  }

  Future<List<(String id, String name, String path)>> listReceipts(
    String transactionId,
  ) async {
    final rows = await _client
        .from('files')
        .select('id, file_name, storage_path')
        .eq('transaction_id', transactionId);
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return (
        m['id'] as String,
        m['file_name'] as String,
        m['storage_path'] as String,
      );
    }).toList();
  }

  Future<String> signedReceiptUrl(String path) async {
    return _client.storage.from('finance-receipts').createSignedUrl(path, 3600);
  }

  /// Exportación local en CSV; no depende de permisos de servidor.
  String exportCsv(List<Transaction> transactions) {
    final buffer = StringBuffer(
      'fecha;tipo;categoria;descripcion;importe;moneda;estado\n',
    );
    for (final t in transactions) {
      buffer.writeln(
        [
          t.occurredOn.iso,
          t.type.value,
          t.category,
          t.description.replaceAll(';', ','),
          t.amount.toStringAsFixed(2),
          t.currency,
          t.paymentStatus.value,
        ].join(';'),
      );
    }
    return buffer.toString();
  }
}
