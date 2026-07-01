import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// سجل بصمة ليوم واحد: دخول وخروج مع الموقع، وحساب الساعات.
class AttendanceRecord {
  final String id;
  final String uid;
  final String userName;
  final Department department;
  final int workStartMin; // جدول الدوام لحظة التسجيل (دقائق من منتصف الليل)
  final int workEndMin;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;

  const AttendanceRecord({
    required this.id,
    required this.uid,
    required this.userName,
    required this.department,
    this.workStartMin = 8 * 60,
    this.workEndMin = 16 * 60,
    required this.checkIn,
    this.checkOut,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
  });

  /// يحوّل قيمة تاريخ سواء كانت Timestamp أو نصًا ISO أو DateTime (للتوافق مع
  /// سجلات البصمة القديمة التي خُزِّن تاريخها كنصّ).
  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory AttendanceRecord.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AttendanceRecord(
      id: doc.id,
      uid: (m['uid'] ?? m['employeeId'] ?? '') as String,
      userName: (m['userName'] ?? m['name'] ?? '') as String,
      department: DepartmentX.fromId(m['department'] as String?),
      workStartMin:
          (m['workStartMin'] as num?)?.toInt() ?? (m['workStart'] as num?)?.toInt() ?? 8 * 60,
      workEndMin:
          (m['workEndMin'] as num?)?.toInt() ?? (m['workEnd'] as num?)?.toInt() ?? 16 * 60,
      checkIn: _toDate(m['checkIn']) ?? _toDate(m['createdAt']) ?? DateTime.now(),
      checkOut: _toDate(m['checkOut']),
      checkInLat: (m['checkInLat'] as num?)?.toDouble(),
      checkInLng: (m['checkInLng'] as num?)?.toDouble(),
      checkOutLat: (m['checkOutLat'] as num?)?.toDouble(),
      checkOutLng: (m['checkOutLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'department': department.id,
        'workStartMin': workStartMin,
        'workEndMin': workEndMin,
        'checkIn': Timestamp.fromDate(checkIn),
        'checkOut': checkOut == null ? null : Timestamp.fromDate(checkOut!),
        'checkInLat': checkInLat,
        'checkInLng': checkInLng,
        'checkOutLat': checkOutLat,
        'checkOutLng': checkOutLng,
        'dayKey': dayKey, // لتسهيل البحث عن سجل اليوم
      };

  /// مفتاح اليوم (yyyy-mm-dd) لإيجاد بصمة اليوم بسهولة.
  String get dayKey =>
      '${checkIn.year}-${checkIn.month.toString().padLeft(2, '0')}-${checkIn.day.toString().padLeft(2, '0')}';

  static String dayKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get _scheduledStart =>
      DateTime(checkIn.year, checkIn.month, checkIn.day)
          .add(Duration(minutes: workStartMin));

  DateTime get _scheduledEnd =>
      DateTime(checkIn.year, checkIn.month, checkIn.day)
          .add(Duration(minutes: workEndMin));

  bool get isOpen => checkOut == null;

  /// مدة العمل الفعلية بالدقائق.
  int get workedMinutes =>
      checkOut == null ? 0 : checkOut!.difference(checkIn).inMinutes;

  /// دقائق التأخير عن موعد الدخول.
  int get lateMinutes =>
      math.max(0, checkIn.difference(_scheduledStart).inMinutes);

  /// دقائق الانصراف المبكر قبل موعد الخروج.
  int get earlyLeaveMinutes => checkOut == null
      ? 0
      : math.max(0, _scheduledEnd.difference(checkOut!).inMinutes);

  /// الساعات الإضافية: ما بعد موعد انتهاء الدوام.
  int get overtimeMinutes => checkOut == null
      ? 0
      : math.max(0, checkOut!.difference(_scheduledEnd).inMinutes);

  /// ساعات التغيّر = مجموع التأخير + الانصراف المبكر (انحراف عن الجدول).
  int get changeMinutes => lateMinutes + earlyLeaveMinutes;
}

/// ملخّص بصمة لموظف خلال فترة (للوحة المحاسبة).
class AttendanceSummary {
  final int workDays; // عدد أيام الدوام
  final int totalWorkedMinutes;
  final int totalChangeMinutes; // عدد ساعات التغيّر
  final int totalOvertimeMinutes; // عدد الساعات الإضافية

  const AttendanceSummary({
    this.workDays = 0,
    this.totalWorkedMinutes = 0,
    this.totalChangeMinutes = 0,
    this.totalOvertimeMinutes = 0,
  });

  factory AttendanceSummary.fromRecords(List<AttendanceRecord> records) {
    int days = 0, worked = 0, change = 0, overtime = 0;
    for (final r in records) {
      if (r.checkOut == null) continue; // يحسب فقط الأيام المكتملة
      days++;
      worked += r.workedMinutes;
      change += r.changeMinutes;
      overtime += r.overtimeMinutes;
    }
    return AttendanceSummary(
      workDays: days,
      totalWorkedMinutes: worked,
      totalChangeMinutes: change,
      totalOvertimeMinutes: overtime,
    );
  }
}
