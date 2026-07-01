import 'package:cloud_firestore/cloud_firestore.dart';

/// تسجيل دخول موظف التنفيذ إلى موقع العمل (مع إحداثيات الموقع).
class SiteCheckin {
  final String id;
  final String siteId;
  final String siteName;
  final String ownerName;
  final String executorUid;
  final String executorName;
  final double lat;
  final double lng;
  final String address;
  final DateTime time;

  const SiteCheckin({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.ownerName,
    required this.executorUid,
    required this.executorName,
    required this.lat,
    required this.lng,
    this.address = '',
    required this.time,
  });

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory SiteCheckin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return SiteCheckin(
      id: doc.id,
      siteId: (m['siteId'] ?? '') as String,
      siteName: (m['siteName'] ?? '') as String,
      ownerName: (m['ownerName'] ?? '') as String,
      executorUid: (m['executorUid'] ?? '') as String,
      executorName: (m['executorName'] ?? '') as String,
      lat: ((m['lat'] as num?) ?? 0).toDouble(),
      lng: ((m['lng'] as num?) ?? 0).toDouble(),
      address: (m['address'] ?? '') as String,
      time: _toDate(m['time']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'siteId': siteId,
        'siteName': siteName,
        'ownerName': ownerName,
        'executorUid': executorUid,
        'executorName': executorName,
        'lat': lat,
        'lng': lng,
        'address': address,
        'time': Timestamp.fromDate(time),
      };
}
