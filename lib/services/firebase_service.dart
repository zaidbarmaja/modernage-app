import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/time_utils.dart';

/// طبقة الوصول إلى Firestore و Storage — تستخدم نفس أسماء المجموعات
/// والحقول الموجودة في الموقع الأصلي.
class Db {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ===== مراجع المجموعات =====
  static CollectionReference<Map<String, dynamic>> get departments =>
      _fs.collection('departments');
  static CollectionReference<Map<String, dynamic>> get employees =>
      _fs.collection('employees');
  static CollectionReference<Map<String, dynamic>> get designProjects =>
      _fs.collection('design_projects');
  static CollectionReference<Map<String, dynamic>> get executionProjects =>
      _fs.collection('execution_projects');
  static CollectionReference<Map<String, dynamic>> get attendance =>
      _fs.collection('attendance');
  static CollectionReference<Map<String, dynamic>> get holidays =>
      _fs.collection('holidays');
  static CollectionReference<Map<String, dynamic>> get customers =>
      _fs.collection('customers');
  static CollectionReference<Map<String, dynamic>> get consultations =>
      _fs.collection('consultations');

  /// مواقع البصمة المعتمدة (كل موقع مرتبط بقسم وله نطاق ومواعيد دوام).
  static CollectionReference<Map<String, dynamic>> get attendanceLocations =>
      _fs.collection('attendance_locations');

  // ===== التقارير اليومية للموظفين =====
  static CollectionReference<Map<String, dynamic>> get dailyReports =>
      _fs.collection('daily_reports');

  /// يحفظ/يحدّث تقرير الموظف اليومي (تقرير واحد لكل موظف في اليوم).
  static Future<void> saveDailyReport({
    required String employeeId,
    required String employeeName,
    required String kind, // design | execution
    required String dateKey, // YYYY-MM-DD
    required String text,
    List<dynamic> photos = const [],
  }) async {
    final id = '${employeeId}_$dateKey';
    await dailyReports.doc(id).set({
      'employeeId': employeeId,
      'employeeName': employeeName,
      'kind': kind,
      'date': dateKey,
      'text': text,
      'photos': photos,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// يضيف موقع بصمة جديدًا.
  static Future<void> addAttendanceLocation({
    required String name,
    required double lat,
    required double lng,
    required int radius,
    required String departmentId,
    required int workStart,
    required int workEnd,
    required List<int> workDays,
  }) async {
    await attendanceLocations.add({
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'departmentId': departmentId,
      'workStart': workStart,
      'workEnd': workEnd,
      'workDays': workDays,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// يحدّث موقع بصمة قائمًا.
  static Future<void> updateAttendanceLocation(
    String id, {
    required String name,
    required double lat,
    required double lng,
    required int radius,
    required String departmentId,
    required int workStart,
    required int workEnd,
    required List<int> workDays,
  }) async {
    await attendanceLocations.doc(id).update({
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'departmentId': departmentId,
      'workStart': workStart,
      'workEnd': workEnd,
      'workDays': workDays,
    });
  }

  /// يحذف موقع بصمة.
  static Future<void> deleteAttendanceLocation(String id) async {
    await attendanceLocations.doc(id).delete();
  }

  // ===== الوصولات الإلكترونية =====
  static CollectionReference<Map<String, dynamic>> get receipts =>
      _fs.collection('receipts');

  /// رقم تسلسلي متزايد (أرقام فقط) عبر مستند عدّاد.
  static Future<int> _nextSeq(String key) async {
    final ref = _fs.collection('counters').doc(key);
    return _fs.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final cur = snap.data()?['value'];
      final next = ((cur is num) ? cur.toInt() : 0) + 1;
      tx.set(ref, {'value': next}, SetOptions(merge: true));
      return next;
    });
  }

  /// يضيف وصل دفع إلكتروني (برقم تسلسلي) ويزيد المبلغ المنصرف في المشروع.
  static Future<void> addReceipt({
    required String projectId,
    required String projectCollection,
    required String employeeId,
    required String ownerName,
    required int amount,
    required String currency,
    required String payer,
    required String note,
    required String dateIso,
    String ownerPhone = '',
  }) async {
    var number = 0;
    try {
      number = await _nextSeq('receipts');
    } catch (_) {}
    await receipts.add({
      'number': number,
      'projectId': projectId,
      'projectCollection': projectCollection,
      'employeeId': employeeId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'amount': amount,
      'currency': currency,
      'payer': payer,
      'note': note,
      'date': dateIso,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await _fs
          .collection(projectCollection)
          .doc(projectId)
          .update({'receivedAmount': FieldValue.increment(amount)});
    } catch (_) {}
  }

  /// تعديل وصل قائم (مع تعديل المبلغ المنصرف بفارق المبلغ).
  static Future<void> updateReceipt(
    String receiptId,
    String projectCollection,
    String projectId, {
    required int oldAmount,
    required int newAmount,
    required String payer,
    required String note,
    required String dateIso,
  }) async {
    await receipts.doc(receiptId).update({
      'amount': newAmount,
      'payer': payer,
      'note': note,
      'date': dateIso,
    });
    final delta = newAmount - oldAmount;
    if (delta != 0) {
      try {
        await _fs
            .collection(projectCollection)
            .doc(projectId)
            .update({'receivedAmount': FieldValue.increment(delta)});
      } catch (_) {}
    }
  }

  /// حذف وصل (مع خصم مبلغه من «المستلَم» إن أمكن).
  static Future<void> deleteReceipt(
      String receiptId, String projectCollection, String projectId,
      int amount) async {
    await receipts.doc(receiptId).delete();
    try {
      await _fs
          .collection(projectCollection)
          .doc(projectId)
          .update({'receivedAmount': FieldValue.increment(-amount)});
    } catch (_) {}
  }

  /// تصحيح إداري لسجل حضور (وقت الدخول/الخروج والملاحظة).
  static Future<void> updateAttendanceRecord(
    String recordId, {
    required String checkInIso,
    String? checkOutIso,
    String? note,
  }) async {
    await attendance.doc(recordId).update({
      'checkIn': checkInIso,
      'checkOut': checkOutIso,
      'note': ?note,
    });
  }

  static const List<String> defaultDepartments = ['التصميم', 'التنفيذ', 'المحاسبة'];
  static const Map<String, int> deptOrder = {
    'التصميم': 0,
    'التنفيذ': 1,
    'المحاسبة': 2,
  };

  // ===== تهيئة الأقسام الافتراضية مرة واحدة =====
  static Future<void> seedDefaultDepartments() async {
    final metaRef = _fs.collection('dashboard_meta').doc('seed');
    final metaSnap = await metaRef.get();
    if (metaSnap.exists) return;
    for (var i = 0; i < defaultDepartments.length; i++) {
      await departments.add({
        'name': defaultDepartments[i],
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await metaRef.set({'seeded': true});
  }

  // ===== الموظفون =====
  static Future<void> addEmployee(
      String deptId, String name, String code) async {
    await employees.add({
      'name': name,
      'code': code,
      'departmentId': deptId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteEmployee(String empId) async {
    await employees.doc(empId).delete();
  }

  static Future<void> addDepartment(String name) async {
    final count = (await departments.get()).size;
    await departments.add({
      'name': name,
      'order': count,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== تسجيل الدخول: مطابقة الاسم + الرمز =====
  static Future<LoginResult> attemptLogin(String name, String code) async {
    final n = name.trim();
    final c = code.trim();
    try {
      final snap = await employees.get();
      final matches = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['name'] ?? '').toString().trim() == n &&
            (d['code'] ?? '').toString().trim() == c) {
          matches.add({'id': doc.id, 'name': (d['name'] ?? '').toString().trim()});
        }
      }
      if (matches.isEmpty) return LoginResult.invalid();
      if (matches.length > 1) return LoginResult.duplicate();
      return LoginResult.ok(matches.first['id'], matches.first['name']);
    } catch (_) {
      return LoginResult.offline();
    }
  }

  // ===== العطل الرسمية =====
  static Future<void> addHoliday(String dateStr) async {
    await holidays.doc(dateStr).set({
      'date': dateStr,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeHoliday(String dateStr) async {
    await holidays.doc(dateStr).delete();
  }

  // ===== الخصم اليومي للأيام المتبقية (نقل أمين من applyDailyTick) =====
  static Future<void> applyDailyTick(
      String projectsCollection, String metaCollection, String employeeId) async {
    if (employeeId.isEmpty) return;
    final today = WorkTime.dateKey(DateTime.now());
    final metaRef = _fs.collection(metaCollection).doc(employeeId);
    final metaSnap = await metaRef.get();

    if (!metaSnap.exists) {
      await metaRef.set({'lastTick': today});
      return;
    }

    final lastTick = (metaSnap.data()?['lastTick'] ?? today).toString();
    final daysPassed = WorkTime.daysBetween(lastTick, today);
    if (daysPassed <= 0) return;

    final snap = await _fs
        .collection(projectsCollection)
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final docs = snap.docs.toList()
      ..sort((a, b) => _createdMs(a.data()).compareTo(_createdMs(b.data())));

    final batch = _fs.batch();
    var toDeduct = daysPassed;
    for (final docSnap in docs) {
      if (toDeduct <= 0) break;
      final data = docSnap.data();
      // المشاريع المعلّقة تُجمّد أيامها: لا يُخصم منها شيء.
      final status = (data['status'] ?? '').toString();
      if (status.contains('معلّق') || status.contains('معلق')) continue;
      final remaining = _remainingOf(data);
      if (remaining <= 0) continue;
      final deduct = toDeduct < remaining ? toDeduct : remaining;
      final newRemaining = remaining - deduct;
      toDeduct -= deduct;
      batch.update(docSnap.reference, {
        'remainingDays': newRemaining,
        'status': newRemaining == 0 ? 'منجز' : 'قيد التنفيذ',
      });
    }
    batch.update(metaRef, {'lastTick': today});
    await batch.commit();
  }

  // ===== رفع الملفات إلى Storage =====
  static Future<List<Map<String, String>>> uploadFiles(
      List<UploadFile> files, String folder, String collection) async {
    final out = <Map<String, String>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_${i}_${file.name}'
          .replaceAll(RegExp(r'[^\w.\-\u0621-\u064A ]'), '_');
      final ref = _storage.ref('$collection/$folder/$safeName');
      await ref.putData(file.bytes);
      final url = await ref.getDownloadURL();
      out.add({'name': file.name, 'url': url});
    }
    return out;
  }

  static int _createdMs(Map<String, dynamic> data) {
    final t = data['createdAt'];
    if (t is Timestamp) return t.millisecondsSinceEpoch;
    return 0;
  }

  static int _remainingOf(Map<String, dynamic> data) {
    final v = data['remainingDays'] ?? data['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }
}

class UploadFile {
  final String name;
  final Uint8List bytes;
  UploadFile(this.name, this.bytes);
}

class LoginResult {
  final bool ok;
  final String reason; // invalid / duplicate / offline / ''
  final String? id;
  final String? name;
  LoginResult._(this.ok, this.reason, this.id, this.name);

  factory LoginResult.ok(String id, String name) =>
      LoginResult._(true, '', id, name);
  factory LoginResult.invalid() => LoginResult._(false, 'invalid', null, null);
  factory LoginResult.duplicate() =>
      LoginResult._(false, 'duplicate', null, null);
  factory LoginResult.offline() => LoginResult._(false, 'offline', null, null);

  String get message {
    switch (reason) {
      case 'offline':
        return 'تعذّر الاتصال بقاعدة البيانات. تأكد من الإنترنت.';
      case 'duplicate':
        return 'يوجد أكثر من موظف بنفس الاسم والرمز. راجع المسؤول.';
      default:
        return 'الاسم أو الرمز غير صحيح.';
    }
  }
}
