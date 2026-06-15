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
  final num amount; // المبلغ المدفوع
  final String description; // وصف الدفعة
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
    this.description = '',
    this.imageUrl = '',
    required this.createdByUid,
    required this.createdByName,
    required this.date,
    this.createdAt,
  });

  /// رقم وصل قصير مقروء مشتقّ من معرّف المستند.
  String get shortNo =>
      id.isEmpty ? '—' : id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();

  factory Receipt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Receipt(
      id: doc.id,
      siteId: (m['siteId'] ?? '') as String,
      siteName: (m['siteName'] ?? '') as String,
      ownerName: (m['ownerName'] ?? '') as String,
      projectId: m['projectId'] as String?,
      customerUid: m['customerUid'] as String?,
      amount: (m['amount'] as num?) ?? 0,
      description: (m['description'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      createdByUid: (m['createdByUid'] ?? '') as String,
      createdByName: (m['createdByName'] ?? '') as String,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'siteId': siteId,
        'siteName': siteName,
        'ownerName': ownerName,
        'projectId': projectId,
        'customerUid': customerUid,
        'amount': amount,
        'description': description,
        'imageUrl': imageUrl,
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'date': Timestamp.fromDate(date),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
