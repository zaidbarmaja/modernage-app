import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/attendance.dart';
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

  /// تغيير دور المستخدم وقسمه (ترقية زبون إلى موظف مثلاً).
  Future<void> updateUserRole(
          String uid, UserRole role, Department department) =>
      _col(FsCollections.users)
          .doc(uid)
          .update({'role': role.id, 'department': department.id});

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

  /// تسجيل دخول (بصمة دخول).
  Future<void> checkIn(AttendanceRecord record) {
    final id = _attDocId(record.uid, record.checkIn);
    return _col(FsCollections.attendance).doc(id).set(record.toMap());
  }

  /// تسجيل خروج (تحديث سجل اليوم).
  Future<void> checkOut(
    String uid, {
    required DateTime checkOutTime,
    double? lat,
    double? lng,
  }) {
    final id = _attDocId(uid, checkOutTime);
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
          .map((s) {
        final list = s.docs.map(AttendanceRecord.fromDoc).toList();
        list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        return list;
      });

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

  Stream<List<WorkSite>> sitesByExecutor(String uid) => _col(FsCollections.sites)
      .where('executorUid', isEqualTo: uid)
      .snapshots()
      .map(_mapSites);

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

  Future<void> addReceipt(Receipt r) =>
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

  List<Receipt> _mapReceipts(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(Receipt.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ------------------------------ الإشعارات ------------------------------

  Future<void> addNotification(AppNotification n) =>
      _col(FsCollections.notifications).add(n.toMap());

  Stream<List<AppNotification>> notificationsStream() =>
      _col(FsCollections.notifications).snapshots().map((s) {
        final list = s.docs.map(AppNotification.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });

  Future<void> markNotificationRead(String id) =>
      _col(FsCollections.notifications).doc(id).update({'read': true});
}
