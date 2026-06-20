import 'package:cloud_firestore/cloud_firestore.dart';

/// إعدادات الشركة (مستند مفرد settings/company): موقع الشركة المعتمد للبصمة
/// ووقت الدوام الموحّد لكل الموظفين. يحدّدها المدير من لوحة التحكم.
class CompanySettings {
  final String name;
  final double? lat;
  final double? lng;
  final int radius; // نطاق السماح بالبصمة حول موقع الشركة (متر)
  final int workStartMin; // بداية الدوام (دقائق من منتصف الليل)
  final int workEndMin; // نهاية الدوام

  const CompanySettings({
    this.name = '',
    this.lat,
    this.lng,
    this.radius = 150,
    this.workStartMin = 8 * 60,
    this.workEndMin = 16 * 60,
  });

  bool get hasLocation => lat != null && lng != null;

  factory CompanySettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return CompanySettings(
      name: (m['name'] ?? '') as String,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      radius: (m['radius'] as num?)?.toInt() ?? 150,
      workStartMin: (m['workStartMin'] as num?)?.toInt() ?? 8 * 60,
      workEndMin: (m['workEndMin'] as num?)?.toInt() ?? 16 * 60,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'workStartMin': workStartMin,
        'workEndMin': workEndMin,
      };

  CompanySettings copyWith({
    String? name,
    double? lat,
    double? lng,
    int? radius,
    int? workStartMin,
    int? workEndMin,
  }) =>
      CompanySettings(
        name: name ?? this.name,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radius: radius ?? this.radius,
        workStartMin: workStartMin ?? this.workStartMin,
        workEndMin: workEndMin ?? this.workEndMin,
      );
}
