import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/company_settings.dart';
import '../models/daily_report.dart';
import '../models/design_project.dart';
import '../models/execution_report.dart';
import '../models/expense.dart';
import '../models/receipt.dart';
import '../models/site_checkin.dart';
import '../models/work_site.dart';

/// طبقة الوصول الموحّدة لقاعدة بيانات Firestore.
/// كل القراءة/الكتابة تمرّ من هنا لتسهيل الصيانة.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  // ----------------------------- المستخدمون -----------------------------

  Future<void> createUser(AppUser user) =>
      _col(FsCollections.users).doc(user.uid).set(user.toMap());

  /// هل يوجد أي مستخدم في النظام؟ (لجعل أول حساب إدارةً تلقائياً).
  Future<bool> hasAnyUser() async {
    final snap = await _col(FsCollections.users).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// يبحث عن بريد المصادقة لمستخدم عبر مُعرّف دخول (اسم/هاتف) — لدعم الدخول
  /// بالاسم أو الهاتف، ويطابق أيضاً الحسابات القديمة عبر حقلَي phone/username.
  /// يقرأ قبل المصادقة (مسموح في الوضع التجريبي).
  Future<String?> findAuthEmailByLogin(String identifier) async {
    final raw = identifier.trim();
    final norm = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final col = _col(FsCollections.users);
    // 1) مفاتيح الدخول (الحسابات الحديثة).
    var snap =
        await col.where('loginNames', arrayContains: norm).limit(1).get();
    // 2) مطابقة الهاتف (الحسابات القديمة المسجّلة بالهاتف).
    if (snap.docs.isEmpty) {
      snap = await col.where('phone', isEqualTo: raw).limit(1).get();
    }
    // 3) مطابقة اسم المستخدم.
    if (snap.docs.isEmpty) {
      snap = await col.where('username', isEqualTo: raw).limit(1).get();
    }
    if (snap.docs.isEmpty) return null;
    final email = snap.docs.first.data()['email'];
    return (email is String && email.isNotEmpty) ? email : null;
  }

  /// يجد ملف المستخدم كاملاً عبر مُعرّف دخول (اسم/هاتف) — لتحديد مسار الدخول
  /// (Firestore أم Firebase Auth) قبل المصادقة. يرفض التطابق المتعدّد (يُرجع null)
  /// كي لا يُحلّ مُعرّف ملتبس إلى حساب خاطئ.
  Future<AppUser?> findUserByLogin(String identifier) async {
    final raw = identifier.trim();
    final norm = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final col = _col(FsCollections.users);
    // نطلب حتى مستندين لكشف الالتباس؛ إن تطابق أكثر من حساب نرفض (null).
    var snap =
        await col.where('loginNames', arrayContains: norm).limit(2).get();
    if (snap.docs.isEmpty) {
      snap = await col.where('phone', isEqualTo: raw).limit(2).get();
    }
    if (snap.docs.isEmpty) {
      snap = await col.where('username', isEqualTo: raw).limit(2).get();
    }
    if (snap.docs.isEmpty || snap.docs.length > 1) return null;
    return AppUser.fromDoc(snap.docs.first);
  }

  // -------------------- بيانات اعتماد كلمة المرور (منفصلة) --------------------

  /// يخزّن بيانات اعتماد كلمة المرور (ملح + تجزئة) في مجموعة منفصلة لا يقرأها
  /// الطاقم — تُستخدم عند الإنشاء وعند إعادة الضبط.
  Future<void> setCredential(String uid, String salt, String hash) =>
      _col(FsCollections.credentials)
          .doc(uid)
          .set({'salt': salt, 'hash': hash});

  /// يقرأ بيانات الاعتماد لمستخدم (للتحقّق من كلمة المرور عند الدخول).
  Future<Map<String, String>?> getCredential(String uid) async {
    final doc = await _col(FsCollections.credentials).doc(uid).get();
    final m = doc.data();
    if (m == null) return null;
    final salt = m['salt'];
    final hash = m['hash'];
    if (salt is String && hash is String) {
      return {'salt': salt, 'hash': hash};
    }
    return null;
  }

  /// إعادة المدير تعيين كلمة مرور حساب: يخزّن الاعتماد الجديد ويُفعّل مسار
  /// كلمة مرور Firestore لهذا الحساب.
  Future<void> setUserPassword(String uid, String salt, String hash) async {
    await setCredential(uid, salt, hash);
    await _col(FsCollections.users)
        .doc(uid)
        .update({'useFirestorePassword': true});
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _col(FsCollections.users).doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Stream<AppUser?> userStream(String uid) => _col(FsCollections.users)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  /// كل المستخدمين بدور معيّن (مرتبة بالاسم محلياً).
  Stream<List<AppUser>> usersByRole(UserRole role) => _col(FsCollections.users)
      .where('role', isEqualTo: role.id)
      .snapshots()
      .map((s) {
        final list = s.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  /// كل الموظفين (تصميم + تنفيذ) لعرض البصمة في المحاسبة.
  Stream<List<AppUser>> employeesStream() =>
      _col(FsCollections.users).snapshots().map((s) {
        final list = s.docs
            .map(AppUser.fromDoc)
            .where((u) => u.isEmployee)
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  /// كل المستخدمين (لإدارة الأدوار من لوحة الإدارة).
  Stream<List<AppUser>> allUsers() =>
      _col(FsCollections.users).snapshots().map((s) {
        final list = s.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  /// تغيير دور المستخدم وقسمه وتصنيف تنفيذه (ترقية زبون إلى موظف مثلاً).
  /// يُطبّع التصنيف: لغير موظف التنفيذ يُضبط دائماً على "تنفيذ عام".
  Future<void> updateUserRole(
          String uid, UserRole role, Department department,
          {WorkCategory workCategory = WorkCategory.general}) =>
      _col(FsCollections.users).doc(uid).update({
        'role': role.id,
        'department': department.id,
        'workCategory': (role == UserRole.executionEmployee
                ? workCategory
                : WorkCategory.general)
            .id,
      });

  /// تحديث اسم ورقم هاتف المستخدم.
  Future<void> updateUserInfo(String uid, String name, String phone) =>
      _col(FsCollections.users).doc(uid).update({'name': name, 'phone': phone});

  /// تفعيل/تعطيل حساب — التعطيل يمنع الدخول فوراً عبر AuthGate.
  Future<void> setUserActive(String uid, bool active) =>
      _col(FsCollections.users).doc(uid).update({'active': active});

  /// تحديث حقول عامة لمستخدم (الاسم/الدور/القسم/وقت الدوام...).
  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _col(FsCollections.users).doc(uid).update(data);

  /// حذف ملف مستخدم/موظف.
  Future<void> deleteUser(String uid) =>
      _col(FsCollections.users).doc(uid).delete();

  /// حذف نهائي لهوية الحساب: ملف المستخدم + بيانات الاعتماد (كلمة المرور).
  /// يحرّر اسم/رقم الدخول لإعادة الاستخدام (الإنشاء لاحقاً يولّد بريد مصادقة
  /// فريداً تلقائياً إن بقي حساب Auth قديم لا يمكن حذفه من جهة العميل).
  Future<void> deleteUserPermanently(String uid) async {
    final batch = _db.batch();
    batch.delete(_col(FsCollections.users).doc(uid));
    batch.delete(_col(FsCollections.credentials).doc(uid));
    await batch.commit();
  }

  // ------------------------------- البصمة -------------------------------

  String _attDocId(String uid, DateTime day) =>
      '${uid}_${AttendanceRecord.dayKeyOf(day)}';

  /// سجل بصمة اليوم للمستخدم (إن وجد).
  Stream<AttendanceRecord?> todayAttendance(String uid) {
    final id = _attDocId(uid, DateTime.now());
    return _col(FsCollections.attendance)
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? AttendanceRecord.fromDoc(d) : null);
  }

  /// قراءة سجل بصمة اليوم مرّة واحدة (تُستخدم من خدمة البصمة التلقائية بالخلفية).
  Future<AttendanceRecord?> todayAttendanceOnce(String uid) async {
    final id = _attDocId(uid, DateTime.now());
    final doc = await _col(FsCollections.attendance).doc(id).get();
    return doc.exists ? AttendanceRecord.fromDoc(doc) : null;
  }

  /// تسجيل دخول (بصمة دخول).
  Future<void> checkIn(AttendanceRecord record) {
    final id = _attDocId(record.uid, record.checkIn);
    return _col(FsCollections.attendance).doc(id).set(record.toMap());
  }

  /// تسجيل خروج: يُغلق سجل يوم **الدخول** [recordDate] (لا يوم الخروج) كي يعمل
  /// حتى لو تجاوز الانصراف منتصف الليل.
  Future<void> checkOut(
    String uid, {
    required DateTime recordDate,
    required DateTime checkOutTime,
    double? lat,
    double? lng,
  }) {
    final id = _attDocId(uid, recordDate);
    return _col(FsCollections.attendance).doc(id).update({
      'checkOut': Timestamp.fromDate(checkOutTime),
      'checkOutLat': lat,
      'checkOutLng': lng,
    });
  }

  /// كل سجلات بصمة موظف (الأحدث أولاً).
  Stream<List<AttendanceRecord>> attendanceForUser(String uid) =>
      _col(FsCollections.attendance)
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map(_mapAttendance);

  /// كل سجلات الحضور (للوحة التقارير الشاملة — T-4.6).
  Stream<List<AttendanceRecord>> allAttendance() =>
      _col(FsCollections.attendance).snapshots().map(_mapAttendance);

  /// حذف سجل بصمة (للمدير من إدارة البيانات).
  Future<void> deleteAttendance(String id) =>
      _col(FsCollections.attendance).doc(id).delete();

  List<AttendanceRecord> _mapAttendance(
      QuerySnapshot<Map<String, dynamic>> s) {
    // نتخطّى أي سجل لا يمكن تحويله (بيانات قديمة/تالفة) بدل إفشال القائمة.
    final list = <AttendanceRecord>[];
    for (final d in s.docs) {
      try {
        list.add(AttendanceRecord.fromDoc(d));
      } catch (_) {}
    }
    list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return list;
  }

  // --------------------------- مشاريع التصميم ---------------------------

  Future<void> addProject(DesignProject p) =>
      _col(FsCollections.projects).add(p.toMap());

  Future<void> updateProject(String id, Map<String, dynamic> data) =>
      _col(FsCollections.projects).doc(id).update(data);

  /// تحديث قائمة مهام المشروع (إضافة/تبديل حالة/حذف من شاشة التفاصيل).
  Future<void> updateProjectTasks(String id, List<ProjectTask> tasks) =>
      _col(FsCollections.projects)
          .doc(id)
          .update({'tasks': tasks.map((t) => t.toMap()).toList()});

  /// تحديث ملاحظات المشروع الحرة (سجلّ بختم زمني واسم الكاتب).
  Future<void> updateProjectNotes(String id, List<ProjectNote> notes) =>
      _col(FsCollections.projects)
          .doc(id)
          .update({'notes': notes.map((n) => n.toMap()).toList()});

  Future<void> deleteProject(String id) =>
      _col(FsCollections.projects).doc(id).delete();

  Stream<List<DesignProject>> allProjects() =>
      _col(FsCollections.projects).snapshots().map(_mapProjects);

  /// متابعة مشروع واحد لحظياً (لشاشة التفاصيل).
  Stream<DesignProject?> projectStream(String id) => _col(FsCollections.projects)
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? DesignProject.fromDoc(d) : null);

  Stream<List<DesignProject>> projectsByDesigner(String uid) =>
      _col(FsCollections.projects)
          .where('designerUid', isEqualTo: uid)
          .snapshots()
          .map(_mapProjects);

  Stream<List<DesignProject>> projectsByCustomer(String uid) =>
      _col(FsCollections.projects)
          .where('customerUid', isEqualTo: uid)
          .snapshots()
          .map(_mapProjects);

  List<DesignProject> _mapProjects(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(DesignProject.fromDoc).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  // ---------------------------- مواقع العمل ----------------------------

  Future<void> addSite(WorkSite s) => _col(FsCollections.sites).add(s.toMap());

  Future<void> updateSite(String id, Map<String, dynamic> data) =>
      _col(FsCollections.sites).doc(id).update(data);

  Future<void> deleteSite(String id) =>
      _col(FsCollections.sites).doc(id).delete();

  Stream<List<WorkSite>> allSites() =>
      _col(FsCollections.sites).snapshots().map(_mapSites);

  /// مواقع منفّذ معيّن — تدعم الإسناد لأكثر من موظف عبر `executorUids`، وتدمج
  /// المواقع القديمة (التي تحوي `executorUid` مفرداً فقط) للتوافق الرجعي.
  Stream<List<WorkSite>> sitesByExecutor(String uid) {
    final byArray = _col(FsCollections.sites)
        .where('executorUids', arrayContains: uid)
        .snapshots();
    final bySingle = _col(FsCollections.sites)
        .where('executorUid', isEqualTo: uid)
        .snapshots();
    final controller = StreamController<List<WorkSite>>();
    var a = <WorkSite>[];
    var b = <WorkSite>[];
    Object? errA, errB;
    void emit() {
      // مرّر الخطأ فقط إذا أخفق الفرعان معاً (وإلا تظهر بيانات الفرع السليم
      // بدل التذبذب بين خطأ وبيانات عند فشل استعلام واحد فقط).
      if (errA != null && errB != null) {
        if (!controller.isClosed) controller.addError(errA!);
        return;
      }
      final byId = <String, WorkSite>{};
      for (final s in [...a, ...b]) {
        byId[s.id] = s;
      }
      final list = byId.values.toList()
        ..sort((x, y) => (y.createdAt ?? DateTime(2000))
            .compareTo(x.createdAt ?? DateTime(2000)));
      if (!controller.isClosed) controller.add(list);
    }

    final s1 = byArray.listen(
        (snap) {
          a = snap.docs.map(WorkSite.fromDoc).toList();
          errA = null;
          emit();
        },
        onError: (Object e, StackTrace st) {
          errA = e;
          emit();
        });
    final s2 = bySingle.listen(
        (snap) {
          b = snap.docs.map(WorkSite.fromDoc).toList();
          errB = null;
          emit();
        },
        onError: (Object e, StackTrace st) {
          errB = e;
          emit();
        });
    controller.onCancel = () async {
      await s1.cancel();
      await s2.cancel();
    };
    return controller.stream;
  }

  Stream<List<WorkSite>> sitesByCustomer(String uid) => _col(FsCollections.sites)
      .where('customerUid', isEqualTo: uid)
      .snapshots()
      .map(_mapSites);

  List<WorkSite> _mapSites(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(WorkSite.fromDoc).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  // -------------------------- تقارير التنفيذ --------------------------

  Future<void> addReport(ExecutionReport r) =>
      _col(FsCollections.executionReports).add(r.toMap());

  Stream<List<ExecutionReport>> reportsBySite(String siteId) =>
      _col(FsCollections.executionReports)
          .where('siteId', isEqualTo: siteId)
          .snapshots()
          .map(_mapReports);

  Stream<List<ExecutionReport>> reportsByExecutor(String uid) =>
      _col(FsCollections.executionReports)
          .where('executorUid', isEqualTo: uid)
          .snapshots()
          .map(_mapReports);

  /// تقارير التنفيذ التي يملكها زبون (استعلام مُقيَّد بـ customerUid حتى تسمح به
  /// قواعد الأمان). الفلترة حسب الموقع تتم في الشاشة (لا فهرس مركّب مطلوب).
  Stream<List<ExecutionReport>> reportsByCustomer(String customerUid) =>
      _col(FsCollections.executionReports)
          .where('customerUid', isEqualTo: customerUid)
          .snapshots()
          .map(_mapReports);

  /// كل تقارير التنفيذ (للوحة الإدارة — الأحدث أولاً).
  Stream<List<ExecutionReport>> allReports() =>
      _col(FsCollections.executionReports).snapshots().map(_mapReports);

  List<ExecutionReport> _mapReports(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(ExecutionReport.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // --------------------------- التقارير اليومية ---------------------------

  String _dailyId(String uid, DateTime date) =>
      '${uid}_${DailyReport.dayKeyOf(date)}';

  /// حفظ/تحديث تقرير اليوم (تقرير واحد لكل يوم عمل، معرّف حتمي).
  Future<void> setDailyReport(DailyReport r) => _col(FsCollections.dailyReports)
      .doc(_dailyId(r.uid, r.date))
      .set(r.toMap());

  /// تقرير اليوم للموظف (إن وُجد).
  Stream<DailyReport?> todayDailyReport(String uid) =>
      _col(FsCollections.dailyReports)
          .doc(_dailyId(uid, DateTime.now()))
          .snapshots()
          .map((d) => d.exists ? DailyReport.fromDoc(d) : null);

  /// كل تقارير موظف (الأحدث أولاً).
  Stream<List<DailyReport>> dailyReportsByUser(String uid) =>
      _col(FsCollections.dailyReports)
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map(_mapDailyReports);

  /// تقارير مرتبطة بمشروع معيّن (الأحدث أولاً).
  Stream<List<DailyReport>> dailyReportsByProject(String projectId) =>
      _col(FsCollections.dailyReports)
          .where('projectId', isEqualTo: projectId)
          .snapshots()
          .map(_mapDailyReports);

  /// كل التقارير اليومية (للوحة الإدارة).
  Stream<List<DailyReport>> allDailyReports() =>
      _col(FsCollections.dailyReports).snapshots().map(_mapDailyReports);

  /// حذف تقرير يومي (للمدير من إدارة البيانات).
  Future<void> deleteDailyReport(String id) =>
      _col(FsCollections.dailyReports).doc(id).delete();

  /// تقارير مشاريع زبون معيّن (لبوابة الزبون — T-4.4)؛ يُرشّح بـ customerUid
  /// مباشرةً فيعمل تحت قواعد الأمان ولا يقرأ تقارير غيره.
  Stream<List<DailyReport>> dailyReportsByCustomer(String customerUid) =>
      _col(FsCollections.dailyReports)
          .where('customerUid', isEqualTo: customerUid)
          .snapshots()
          .map(_mapDailyReports);

  List<DailyReport> _mapDailyReports(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(DailyReport.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // -------------------------- تسجيل دخول الموقع --------------------------

  Future<void> addSiteCheckin(SiteCheckin c) =>
      _col(FsCollections.siteCheckins).add(c.toMap());

  Stream<List<SiteCheckin>> checkinsBySite(String siteId) =>
      _col(FsCollections.siteCheckins)
          .where('siteId', isEqualTo: siteId)
          .snapshots()
          .map(_mapCheckins);

  Stream<List<SiteCheckin>> checkinsByExecutor(String uid) =>
      _col(FsCollections.siteCheckins)
          .where('executorUid', isEqualTo: uid)
          .snapshots()
          .map(_mapCheckins);

  List<SiteCheckin> _mapCheckins(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(SiteCheckin.fromDoc).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  // -------------------------- السلف والصرفيات --------------------------

  Future<void> addExpense(Expense e) =>
      _col(FsCollections.expenses).add(e.toMap());

  Stream<List<Expense>> expensesByExecutor(String uid) =>
      _col(FsCollections.expenses)
          .where('executorUid', isEqualTo: uid)
          .snapshots()
          .map(_mapExpenses);

  Stream<List<Expense>> expensesBySite(String siteId) =>
      _col(FsCollections.expenses)
          .where('siteId', isEqualTo: siteId)
          .snapshots()
          .map(_mapExpenses);

  Stream<List<Expense>> allExpenses() =>
      _col(FsCollections.expenses).snapshots().map(_mapExpenses);

  List<Expense> _mapExpenses(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(Expense.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ------------------------- الوصولات الإلكترونية -------------------------

  /// يضيف وصلاً ويُرجع مرجعه (لربط نسخته المرآة في الحسابات عبر receiptId).
  Future<DocumentReference<Map<String, dynamic>>> addReceipt(Receipt r) =>
      _col(FsCollections.receipts).add(r.toMap());

  Stream<List<Receipt>> receiptsBySite(String siteId) =>
      _col(FsCollections.receipts)
          .where('siteId', isEqualTo: siteId)
          .snapshots()
          .map(_mapReceipts);

  Stream<List<Receipt>> receiptsByExecutor(String uid) =>
      _col(FsCollections.receipts)
          .where('createdByUid', isEqualTo: uid)
          .snapshots()
          .map(_mapReceipts);

  Stream<List<Receipt>> receiptsByCustomer(String customerUid) =>
      _col(FsCollections.receipts)
          .where('customerUid', isEqualTo: customerUid)
          .snapshots()
          .map(_mapReceipts);

  Stream<List<Receipt>> allReceipts() =>
      _col(FsCollections.receipts).snapshots().map(_mapReceipts);

  /// حذف وصل + نسخته المرآة في حسابات المحاسبة (customerTransactions) معًا،
  /// كي يختفي من كل مكان عند الحذف من التطبيق أو اللوحة.
  Future<void> deleteReceipt(String id) async {
    final batch = _db.batch();
    batch.delete(_col(FsCollections.receipts).doc(id));
    await _addMirrorDeletes(batch, id);
    await batch.commit();
  }

  /// يضيف حذف نسخ الوصل المرآة (customerTransactions حيث receiptId == id) للدفعة.
  Future<void> _addMirrorDeletes(WriteBatch batch, String receiptId) async {
    if (receiptId.isEmpty) return;
    final mirror = await _db
        .collection('customerTransactions')
        .where('receiptId', isEqualTo: receiptId)
        .get();
    for (final m in mirror.docs) {
      batch.delete(m.reference);
    }
  }

  /// حذف موقع تنفيذ مع كل ما يتبعه (وصولات/تقارير/صرفيات/تسجيلات دخول) دفعةً
  /// واحدة كي لا تبقى سجلّات يتيمة تشوّه الإجماليات.
  Future<void> deleteSiteCascade(String siteId) async {
    final batch = _db.batch();
    batch.delete(_col(FsCollections.sites).doc(siteId));
    for (final c in [
      FsCollections.receipts,
      FsCollections.executionReports,
      FsCollections.expenses,
      FsCollections.siteCheckins,
    ]) {
      final snap = await _col(c).where('siteId', isEqualTo: siteId).get();
      for (final d in snap.docs) {
        batch.delete(d.reference);
        // حذف نسخ الوصولات المرآة أيضًا عند حذف الموقع.
        if (c == FsCollections.receipts) await _addMirrorDeletes(batch, d.id);
      }
    }
    await batch.commit();
  }

  /// حذف مشروع تصميم مع وصولاته وتقاريره اليومية، وفكّ ربط مواقع التنفيذ
  /// المرتبطة به (دون حذف المواقع نفسها).
  Future<void> deleteProjectCascade(String projectId) async {
    final batch = _db.batch();
    batch.delete(_col(FsCollections.projects).doc(projectId));
    for (final c in [FsCollections.receipts, FsCollections.dailyReports]) {
      final snap = await _col(c).where('projectId', isEqualTo: projectId).get();
      for (final d in snap.docs) {
        batch.delete(d.reference);
        if (c == FsCollections.receipts) await _addMirrorDeletes(batch, d.id);
      }
    }
    final sites =
        await _col(FsCollections.sites).where('projectId', isEqualTo: projectId).get();
    for (final d in sites.docs) {
      batch.update(d.reference, {'projectId': null});
    }
    await batch.commit();
  }

  List<Receipt> _mapReceipts(QuerySnapshot<Map<String, dynamic>> s) {
    // نتخطّى أي مستند لا يمكن تحويله (بيانات قديمة/تالفة) بدل إفشال القائمة كلها.
    final list = <Receipt>[];
    for (final d in s.docs) {
      try {
        list.add(Receipt.fromDoc(d));
      } catch (_) {}
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ------------------------------ الإشعارات ------------------------------
  //  كل ما يخصّ الإشعارات (إرسال/بثّ/جدولة/قراءة + رموز الأجهزة FCM) انتقل إلى
  //  ملف واحد: services/notifications.dart — لا تُضِف إشعارات هنا.

  // --------------------------- إعدادات الشركة ---------------------------

  /// إعدادات الشركة (موقع البصمة + أوقات الدوام الموحّدة) — مستند مفرد.
  Stream<CompanySettings> companySettings() => _col(FsCollections.settings)
      .doc('company')
      .snapshots()
      .map((d) => d.exists ? CompanySettings.fromDoc(d) : const CompanySettings());

  Future<void> setCompanySettings(CompanySettings s) =>
      _col(FsCollections.settings)
          .doc('company')
          .set(s.toMap(), SetOptions(merge: true));

  // رموز الأجهزة (FCM) والتنبيهات اليومية المجدولة → services/notifications.dart
}
