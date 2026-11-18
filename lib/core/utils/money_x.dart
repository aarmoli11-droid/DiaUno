import 'package:intl/intl.dart';

String formatMoney(num amount, {String currency = 'USD'}) {
  final symbol = switch (currency) {
    'USD' => '\$',
    'EUR' => '€',
    'CRC' => '₡',
    _ => '$currency ',
  };
  return '$symbol${NumberFormat('#,##0.00', 'es').format(amount)}';
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
