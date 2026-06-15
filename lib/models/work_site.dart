import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? executorUid; // الموظف المسند إليه التنفيذ
  final String? executorName;
  final String? customerUid; // لربط الزبون
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
    this.customerUid,
    this.createdAt,
  });

  factory WorkSite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
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
      customerUid: m['customerUid'] as String?,
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
        'customerUid': customerUid,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
