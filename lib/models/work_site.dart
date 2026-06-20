import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// موقع عمل للتنفيذ — تضيفه الإدارة بناءً على التصميم وتسنده لموظف تنفيذ.
class WorkSite {
  final String id;
  final String ownerName; // اسم صاحب المشروع
  final String siteName; // اسم/عنوان الموقع
  final String address; // وصف العنوان
  final double? lat;
  final double? lng;
  final int radius; // نطاق السماح بالحضور (متر) — للـ geofence (يستخدمه T-3.1)
  final int? durationDays; // مدة التنفيذ المتوقعة (أيام)
  final String? projectId; // ربط بمشروع تصميم إن وجد
  final String? executorUid; // الموظف الأساسي (أول منفّذ — للتوافق الرجعي)
  final String? executorName;
  // قائمة كل المنفّذين المسندين لنفس الموقع (يدعم أكثر من موظف).
  final List<String> executorUids;
  final List<String> executorNames;
  final String? customerUid; // لربط الزبون
  final WorkCategory category; // تنفيذ عام / إشراف مسابح / تنفيذ مسابح
  final DateTime? createdAt;

  const WorkSite({
    required this.id,
    required this.ownerName,
    required this.siteName,
    this.address = '',
    this.lat,
    this.lng,
    this.radius = 100,
    this.durationDays,
    this.projectId,
    this.executorUid,
    this.executorName,
    this.executorUids = const [],
    this.executorNames = const [],
    this.customerUid,
    this.category = WorkCategory.general,
    this.createdAt,
  });

  /// أسماء المنفّذين الصالحة للعرض (بعد حذف الفارغة)، أو الاسم الأساسي القديم.
  List<String> get executorDisplayNames {
    final names =
        executorNames.where((n) => n.trim().isNotEmpty).toList();
    if (names.isNotEmpty) return names;
    if (executorName != null && executorName!.trim().isNotEmpty) {
      return [executorName!];
    }
    return const [];
  }

  /// نص أسماء كل المنفّذين (للعرض).
  String get executorsLabel => executorDisplayNames.join('، ');

  /// عدد المنفّذين المعتمد للعرض — نفس مصدر الأسماء لتفادي عدم التطابق.
  int get executorCount {
    if (executorUids.isNotEmpty) return executorUids.length;
    if (executorUid != null && executorUid!.isNotEmpty) return 1;
    return executorDisplayNames.length;
  }

  bool get hasExecutor => executorUids.isNotEmpty ||
      (executorUid != null && executorUid!.isNotEmpty);

  /// نسبة الإنجاز التقديرية (0..100) محسوبة تلقائياً من الأيام المنقضية منذ
  /// إنشاء الموقع مقابل المدّة المتوقّعة. تُرجع null إذا غابت المدّة أو التاريخ.
  int? get autoProgressPercent {
    final d = durationDays;
    if (d == null || d <= 0 || createdAt == null) return null;
    final elapsed = DateTime.now().difference(createdAt!).inDays;
    if (elapsed <= 0) return 0;
    return ((elapsed / d) * 100).clamp(0, 100).round();
  }

  factory WorkSite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    // التوافق الرجعي: المواقع القديمة تحوي منفّذاً واحداً فقط (executorUid).
    final uids = (m['executorUids'] as List?)?.map((e) => e.toString()).toList() ??
        (m['executorUid'] != null ? [m['executorUid'] as String] : <String>[]);
    var names = (m['executorNames'] as List?)?.map((e) => e.toString()).toList() ??
        (m['executorName'] != null ? [m['executorName'] as String] : <String>[]);
    // ضمان تطابق طول القائمتين حتى مع المستندات القديمة/المعدّلة يدوياً،
    // كي يبقى العدّ والأسماء والإزالة بالفهرس متّسقة.
    if (uids.isNotEmpty && names.length != uids.length) {
      names = [
        for (var i = 0; i < uids.length; i++) i < names.length ? names[i] : ''
      ];
    }
    return WorkSite(
      id: doc.id,
      ownerName: (m['ownerName'] ?? '') as String,
      siteName: (m['siteName'] ?? '') as String,
      address: (m['address'] ?? '') as String,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      radius: (m['radius'] as num?)?.toInt() ?? 100,
      durationDays: (m['durationDays'] as num?)?.toInt(),
      projectId: m['projectId'] as String?,
      executorUid: m['executorUid'] as String?,
      executorName: m['executorName'] as String?,
      executorUids: uids,
      executorNames: names,
      customerUid: m['customerUid'] as String?,
      category: WorkCategoryX.fromId(m['category'] as String?),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerName': ownerName,
        'siteName': siteName,
        'address': address,
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'durationDays': durationDays,
        'projectId': projectId,
        'executorUid': executorUid,
        'executorName': executorName,
        'executorUids': executorUids,
        'executorNames': executorNames,
        'customerUid': customerUid,
        'category': category.id,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
