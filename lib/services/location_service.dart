import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// نتيجة تحديد الموقع: إحداثيات + عنوان نصّي.
class LocationResult {
  final double lat;
  final double lng;
  final String address;
  const LocationResult(this.lat, this.lng, this.address);
}

/// موقع بصمة معتمد (يحدّده المدير من لوحة التحكم) — مرتبط بقسم، وله نطاق
/// ومواعيد دوام خاصة به.
class AttendanceLocation {
  final String id;
  final String name; // اسم الموقع (مثل: مكتب التصميم)
  final double lat;
  final double lng;
  final int radius; // بالأمتار
  final String departmentId; // القسم المرتبط بهذا الموقع
  final int workStart; // بداية الدوام (دقائق من منتصف الليل) — افتراضي 8:00
  final int workEnd; // نهاية الدوام (دقائق من منتصف الليل) — افتراضي 4:00 م
  final List<int> workDays; // أيام الدوام بترقيم DateTime.weekday (الإثنين=1..الأحد=7)
  const AttendanceLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.departmentId,
    required this.workStart,
    required this.workEnd,
    required this.workDays,
  });

  /// أيام الدوام الافتراضية: الأحد→الخميس.
  static const List<int> defaultWorkDays = [7, 1, 2, 3, 4];

  /// يبني الموقع من مستند Firestore، أو null إن كانت الإحداثيات ناقصة.
  static AttendanceLocation? fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) return null;
    final lat = (d['lat'] as num?)?.toDouble();
    final lng = (d['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    int asInt(dynamic v, int fallback) =>
        (v is num) ? v.toInt() : int.tryParse('$v') ?? fallback;
    final rawDays = d['workDays'];
    final days = (rawDays is List)
        ? rawDays
            .map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 0)
            .where((e) => e >= 1 && e <= 7)
            .toList()
        : <int>[];
    return AttendanceLocation(
      id: id,
      name: (d['name'] ?? '').toString(),
      lat: lat,
      lng: lng,
      radius: asInt(d['radius'], 100),
      departmentId: (d['departmentId'] ?? '').toString(),
      workStart: asInt(d['workStart'], 8 * 60),
      workEnd: asInt(d['workEnd'], 16 * 60),
      workDays: days.isEmpty ? defaultWorkDays : days,
    );
  }
}

/// خدمة الموقع: التحقق من الصلاحيات وجلب الموقع الحالي وتحويله إلى عنوان.
class LocationService {
  /// يطلب الصلاحيات ويعيد الموقع الحالي مع محاولة جلب العنوان.
  /// يرمي [LocationException] عند الفشل برسالة عربية واضحة.
  static Future<LocationResult> getCurrentLocation() async {
    final position = await currentPosition();
    final address = await _reverseGeocode(position.latitude, position.longitude);
    return LocationResult(position.latitude, position.longitude, address);
  }

  /// يجلب الموقع الحالي فقط (بدون عنوان نصّي) — أسرع لفحص النطاق.
  /// يرمي [LocationException] عند تعذّر تحديد الموقع.
  static Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('خدمة الموقع (GPS) غير مفعّلة على الجهاز.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('تم رفض إذن الوصول إلى الموقع.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'إذن الموقع مرفوض بشكل دائم. فعّله من إعدادات الجهاز.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      // تعذّر الحصول على إشارة GPS خلال المهلة — نجرّب آخر موقع معروف.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationException(
          'تعذّر تحديد موقعك. تأكّد من تفعيل GPS وكن في مكان مكشوف ثم حاول مجددًا.');
    }
  }

  /// المسافة بالأمتار بين نقطتين.
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final parts = <String>[
        if ((p.street ?? '').isNotEmpty) p.street!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
        if ((p.country ?? '').isNotEmpty) p.country!,
      ];
      return parts.join('، ');
    } catch (_) {
      // قد يفشل التحويل بدون إنترنت — نكتفي بالإحداثيات.
      return '';
    }
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}
