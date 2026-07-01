import 'package:cloud_firestore/cloud_firestore.dart';

/// تقرير تنفيذ يومي: مستندات وملاحظات، صور العمل اليومية،
/// وخطة الأيام القادمة ومدة التنفيذ لكل عمل.
class ExecutionReport {
  final String id;
  final String siteId;
  final String siteName;
  final String ownerName;
  final String executorUid;
  final String executorName;
  final DateTime date;
  final String documentsNotes; // المستندات مع ملاحظات
  final List<String> photoUrls; // الصور اليومية للعمل
  final String plannedNextDays; // ماذا سيُنفَّذ في الأيام القادمة
  final int? durationDays; // كم مدة التنفيذ لهذا العمل
  final String? customerUid; // زبون الموقع — ليقرأ تقاريره وصوره ضمن قواعد الأمان
  final DateTime? createdAt;

  const ExecutionReport({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.ownerName,
    required this.executorUid,
    required this.executorName,
    required this.date,
    this.documentsNotes = '',
    this.photoUrls = const [],
    this.plannedNextDays = '',
    this.durationDays,
    this.customerUid,
    this.createdAt,
  });

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory ExecutionReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return ExecutionReport(
      id: doc.id,
      siteId: (m['siteId'] ?? '') as String,
      siteName: (m['siteName'] ?? '') as String,
      ownerName: (m['ownerName'] ?? '') as String,
      executorUid: (m['executorUid'] ?? '') as String,
      executorName: (m['executorName'] ?? '') as String,
      date: _toDate(m['date']) ?? DateTime.now(),
      documentsNotes: (m['documentsNotes'] ?? '') as String,
      photoUrls: ((m['photoUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      plannedNextDays: (m['plannedNextDays'] ?? '') as String,
      durationDays: (m['durationDays'] as num?)?.toInt(),
      customerUid: m['customerUid'] as String?,
      createdAt: _toDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'siteId': siteId,
        'siteName': siteName,
        'ownerName': ownerName,
        'executorUid': executorUid,
        'executorName': executorName,
        'date': Timestamp.fromDate(date),
        'documentsNotes': documentsNotes,
        'photoUrls': photoUrls,
        'plannedNextDays': plannedNextDays,
        'durationDays': durationDays,
        'customerUid': customerUid,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
