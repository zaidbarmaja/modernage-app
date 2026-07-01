import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع الحركة المالية لموظف التنفيذ.
enum ExpenseType {
  advance, // سلفة
  spending, // صرفية (مبلغ مصروف)
}

extension ExpenseTypeX on ExpenseType {
  String get id => name;
  String get labelAr => this == ExpenseType.advance ? 'سلفة' : 'صرفية';

  static ExpenseType fromId(String? v) => ExpenseType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ExpenseType.spending,
      );
}

/// السلف والصرفيات: المبلغ المصروف مع الملاحظة.
class Expense {
  final String id;
  final String siteId;
  final String siteName;
  final String ownerName;
  final String executorUid;
  final String executorName;
  final ExpenseType type;
  final num amount; // المبلغ المصروف
  final String note; // الملاحظة
  final DateTime date;

  const Expense({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.ownerName,
    required this.executorUid,
    required this.executorName,
    required this.type,
    required this.amount,
    this.note = '',
    required this.date,
  });

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Expense(
      id: doc.id,
      siteId: (m['siteId'] ?? '') as String,
      siteName: (m['siteName'] ?? '') as String,
      ownerName: (m['ownerName'] ?? '') as String,
      executorUid: (m['executorUid'] ?? '') as String,
      executorName: (m['executorName'] ?? '') as String,
      type: ExpenseTypeX.fromId(m['type'] as String?),
      amount: (m['amount'] as num?) ?? 0,
      note: (m['note'] ?? '') as String,
      date: _toDate(m['date']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'siteId': siteId,
        'siteName': siteName,
        'ownerName': ownerName,
        'executorUid': executorUid,
        'executorName': executorName,
        'type': type.id,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(date),
      };
}
