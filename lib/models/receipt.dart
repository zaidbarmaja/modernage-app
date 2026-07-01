import 'package:cloud_firestore/cloud_firestore.dart';

/// وصل إلكتروني: يُصدره موظف التنفيذ عند دفع/استلام مبلغ ضمن المشروع، مع صورة
/// مرفقة اختيارية. مرتبط بموقع العمل (وبالزبون إن وُجد)، ويظهر للزبون والإدارة
/// لحظياً. يقابل مجموعة `receipts` في نموذج البيانات.
class Receipt {
  final String id;
  final String siteId;
  final String siteName;
  final String ownerName; // صاحب المشروع
  final String? projectId; // ربط بمشروع تصميم إن وُجد
  final String? customerUid; // لظهور الوصل في بوابة الزبون
  final num amount; // المبلغ (مقبوض أو مصروف)
  final bool expense; // false = وصل قبض، true = وصل صرف
  final String description; // وصف الدفعة
  final String recipient; // المستلِم (اسم من استلم/سُلِّم له المبلغ)
  final String imageUrl; // رابط صورة الوصل في Storage (قد يكون فارغاً)
  final String createdByUid; // منشئ الوصل (موظف التنفيذ)
  final String createdByName;
  final DateTime date; // تاريخ الدفع
  final DateTime? createdAt;

  const Receipt({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.ownerName,
    this.projectId,
    this.customerUid,
    required this.amount,
    this.expense = false,
    this.description = '',
    this.recipient = '',
    this.imageUrl = '',
    required this.createdByUid,
    required this.createdByName,
    required this.date,
    this.createdAt,
  });

  /// رقم وصل قصير مقروء مشتقّ من معرّف المستند.
  String get shortNo =>
      id.isEmpty ? '—' : id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();

  /// يحوّل قيمة تاريخ سواء كانت Timestamp أو نصًا ISO أو DateTime (للتوافق مع
  /// الوصولات القديمة التي خُزِّن تاريخها كنصّ في النظام السابق).
  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory Receipt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Receipt(
      id: doc.id,
      siteId: _str(m['siteId']),
      siteName: _str(m['siteName']),
      ownerName: _str(m['ownerName']),
      projectId: m['projectId']?.toString(),
      customerUid: m['customerUid']?.toString(),
      amount: (m['amount'] as num?) ?? 0,
      expense: (m['expense'] as bool?) ?? false,
      // الحقول القديمة: 'note' بدل 'description' و'payer' بدل 'recipient'.
      description: _str(m['description'] ?? m['note']),
      recipient: _str(m['recipient'] ?? m['payer']),
      imageUrl: _str(m['imageUrl']),
      createdByUid: _str(m['createdByUid'] ?? m['employeeId']),
      createdByName: _str(m['createdByName']),
      date: _toDate(m['date']) ?? _toDate(m['createdAt']) ?? DateTime.now(),
      createdAt: _toDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'siteId': siteId,
        'siteName': siteName,
        'ownerName': ownerName,
        'projectId': projectId,
        'customerUid': customerUid,
        'amount': amount,
        'expense': expense,
        'description': description,
        'recipient': recipient,
        'imageUrl': imageUrl,
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'date': Timestamp.fromDate(date),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
