import 'package:cloud_firestore/cloud_firestore.dart';

/// تقرير يومي: ماذا أنجز الموظف اليوم. مرتبط بالموظف والتاريخ،
/// وربط اختياري بمشروع. تقرير واحد لكل يوم عمل (معرّف حتمي uid_dayKey).
class DailyReport {
  final String id;
  final String uid;
  final String userName;
  final DateTime date;
  final String content;
  final String? projectId; // ربط اختياري بمشروع/موقع
  final String projectName;
  final DateTime? createdAt;

  /// مفتاح اليوم المخزّن (yyyy-MM-dd). يُقرأ من الوثيقة لا يُعاد حسابه من
  /// الطابع الزمني، حتى يتطابق دائماً مع معرّف المستند الحتمي والفلاتر.
  final String dayKey;

  DailyReport({
    required this.id,
    required this.uid,
    required this.userName,
    required this.date,
    required this.content,
    this.projectId,
    this.projectName = '',
    this.createdAt,
    String? dayKey,
  }) : dayKey = (dayKey == null || dayKey.isEmpty) ? dayKeyOf(date) : dayKey;

  static String dayKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory DailyReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return DailyReport(
      id: doc.id,
      uid: (m['uid'] ?? '') as String,
      userName: (m['userName'] ?? '') as String,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      content: (m['content'] ?? '') as String,
      projectId: m['projectId'] as String?,
      projectName: (m['projectName'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      dayKey: m['dayKey'] as String?, // المخزّن أولاً، وإلا يُحسب من التاريخ
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'date': Timestamp.fromDate(date),
        'dayKey': dayKey,
        'content': content,
        'projectId': projectId,
        'projectName': projectName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
