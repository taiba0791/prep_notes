import '../../../core/utils/money.dart';
import '../../../data/models/purchase.dart';

/// Orders as a CSV spreadsheet (Excel / Google Sheets). Amounts in rupees.
String ordersToCsv(List<PurchaseOrder> orders) {
  String cell(Object? v) {
    final s = '${v ?? ''}';
    // Quote cells with commas, quotes or line breaks; double inner quotes.
    // A leading = + - @ is prefixed with ' so spreadsheets don't run it as a
    // formula ("CSV injection").
    final safe = RegExp(r'^[=+\-@]').hasMatch(s) ? "'$s" : s;
    return RegExp(r'[",\r\n]').hasMatch(safe)
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  String iso(DateTime? d) => d?.toIso8601String() ?? '';

  final rows = <List<Object?>>[
    [
      'order_id',
      'created_at',
      'paid_at',
      'status',
      'user_id',
      'notes',
      'amount_inr',
      'payment_id',
      'failure_reason',
      'refunded_at',
      'refund_reason',
    ],
    for (final o in orders)
      [
        o.id,
        iso(o.createdAt),
        iso(o.paidAt),
        o.status,
        o.userId,
        o.noteTitles.join(' | '),
        Money.toRupeesText(o.amount),
        o.razorpayPaymentId,
        o.failureReason,
        iso(o.refundedAt),
        o.refundReason,
      ],
  ];
  return '${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}
