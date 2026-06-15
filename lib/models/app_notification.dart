import 'package:cloud_firestore/cloud_firestore.dart';

/// إشعار داخلي يظهر في لوحة الإدارة/المحاسبة
/// (مثال: دخول موظف تنفيذ إلى موقع العمل).
class AppNotification {
  final String id;
  final String type; // مثل: site_checkin
  final String title;
  final String body;
  final String fromUid;
  final String fromName;
  final String? relatedId; // معرف الموقع/التقرير المرتبط
  final double? lat;
  final double? lng;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.fromUid = '',
    this.fromName = '',
    this.relatedId,
    this.lat,
    this.lng,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      type: (m['type'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      fromUid: (m['fromUid'] ?? '') as String,
      fromName: (m['fromName'] ?? '') as String,
      relatedId: m['relatedId'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      read: (m['read'] ?? false) as bool,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'body': body,
        'fromUid': fromUid,
        'fromName': fromName,
        'relatedId': relatedId,
        'lat': lat,
        'lng': lng,
        'read': read,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
