import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import 'project_form.dart';

class FingerprintScreen extends StatefulWidget {
  /// عند true: صلاحية إدارية (تعديل/حذف سجلات الحضور). تُستخدم من لوحة التحكم
  /// والمحاسبين. أمّا الموظف الذي يسجّل بصمته فلا يملكها (قراءة فقط).
  final bool canManage;
  const FingerprintScreen({this.canManage = false, super.key});
  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {
  EmployeeSession? _emp;
  Set<String> _holidays = {};
  List<AttendanceLocation> _locations = [];
  // مشاريع التنفيذ — موقع كل مشروع يصلح كموقع بصمة للموظفين المكلّفين به.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _execDocs = [];
  bool _locsLoaded = false;
  String _deptId = '';
  bool _deptLoaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emp = Session.get(Session.fingerprintKey);
    if (_emp != null) _loadDept(_emp!.id);
    Db.holidays.snapshots().listen((s) {
      if (!mounted) return;
      setState(() => _holidays = s.docs.map((d) => d.id).toSet());
    });
    Db.attendanceLocations.snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        _locations = s.docs
            .map((d) => AttendanceLocation.fromDoc(d.id, d.data()))
            .whereType<AttendanceLocation>()
            .toList();
        _locsLoaded = true;
      });
    });
    Db.executionProjects.snapshots().listen((s) {
      if (!mounted) return;
      setState(() => _execDocs = s.docs);
    });
  }

  /// مواقع بصمة مبنيّة من مشاريع التنفيذ المكلّف بها الموظف (لها إحداثيات).
  List<AttendanceLocation> get _projectLocations {
    final emp = _emp;
    if (emp == null) return const [];
    final out = <AttendanceLocation>[];
    for (final doc in _execDocs) {
      final d = doc.data();
      if (!projectAssignedTo(d, emp.id)) continue;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final radius = (d['radius'] is num) ? (d['radius'] as num).toInt() : 200;
      final nm = (d['location'] ?? '').toString().trim();
      out.add(AttendanceLocation(
        id: 'proj_${doc.id}',
        name: nm.isEmpty
            ? 'موقع مشروع ${(d['ownerName'] ?? '').toString()}'.trim()
            : nm,
        lat: lat,
        lng: lng,
        radius: radius,
        departmentId: _deptId,
        workStart: 8 * 60,
        workEnd: 16 * 60,
        // الموقع نفسه هو الشرط — يُسمح بالبصمة فيه أي يوم (عدا العطل الرسمية).
        workDays: const [1, 2, 3, 4, 5, 6, 7],
      ));
    }
    return out;
  }

  /// كل مواقع البصمة المتاحة للموظف: مواقع قسمه + مواقع مشاريع التنفيذ.
  List<AttendanceLocation> get _allLocations =>
      [..._myLocations, ..._projectLocations];

  Future<void> _loadDept(String empId) async {
    try {
      final doc = await Db.employees.doc(empId).get();
      final dept = (doc.data()?['departmentId'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _deptId = dept;
        _deptLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _deptLoaded = true);
    }
  }

  Future<void> _onLogin(EmployeeSession s) async {
    await Session.set(Session.fingerprintKey, s);
    setState(() {
      _emp = s;
      _deptLoaded = false;
    });
    _loadDept(s.id);
  }

  Future<void> _logout() async {
    await Session.clear(Session.fingerprintKey);
    setState(() {
      _emp = null;
      _deptId = '';
      _deptLoaded = false;
    });
  }

  List<AttendanceLocation> get _myLocations =>
      _locations.where((l) => l.departmentId == _deptId).toList();

  /// تسجيل دخول/خروج بالبصمة ضمن أحد مواقع قسم الموظف فقط.
  /// الخطوات: التأكد من الموقع ضمن النطاق → التحقق ببصمة الإصبع → تسجيل الوقت تلقائيًا.
  Future<void> _attendanceAction({
    required bool checkIn,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> recs,
  }) async {
    if (_busy) return;
    final todayKey = WorkTime.dateKey(DateTime.now());

    if (checkIn) {
      if (_holidays.contains(todayKey)) {
        _toast('اليوم عطلة رسمية حدّدها المدير، لا يمكن تسجيل الدخول.');
        return;
      }
      if (recs.any((r) => r.data()['checkOut'] == null)) {
        _toast('لديك تسجيل دخول مفتوح بالفعل.');
        return;
      }
    } else {
      if (!recs.any((r) => r.data()['checkOut'] == null)) {
        _toast('لا يوجد تسجيل دخول مفتوح.');
        return;
      }
    }

    // (1) يجب أن يتوفّر موقع بصمة: موقع قسم الموظف أو موقع أحد مشاريعه.
    final locs = _allLocations;
    if (locs.isEmpty) {
      _toast('لا يوجد موقع بصمة لك بعد (موقع قسم أو موقع مشروع). تواصل مع الإدارة.');
      return;
    }

    setState(() => _busy = true);
    try {
      // (2) فحص الموقع: ضمن نطاق أحد مواقع القسم؟
      final pos = await LocationService.currentPosition();
      final tolerance = (pos.accuracy.isFinite ? pos.accuracy : 0).clamp(0, 75);

      final todayWd = DateTime.now().weekday;
      AttendanceLocation? matched;
      double nearest = double.infinity;
      bool inRangeOffDay = false;
      for (final l in locs) {
        final d = LocationService.distanceMeters(
            l.lat, l.lng, pos.latitude, pos.longitude);
        if (d < nearest) nearest = d;
        if (d <= l.radius + tolerance) {
          if (l.workDays.contains(todayWd)) {
            matched = l;
            break;
          } else {
            inRangeOffDay = true;
          }
        }
      }
      if (matched == null) {
        if (inRangeOffDay) {
          _toast('اليوم (${arWeekday(todayWd)}) ليس من أيام الدوام في موقعك.');
        } else {
          _toast(
              'أنت خارج نطاق موقع العمل (أقرب موقع يبعُد ${nearest.round()} م). إن كنت في الموقع فعلًا فزِد النطاق من لوحة التحكم.');
        }
        return;
      }

      // (3) التحقق ببصمة الإصبع على الجهاز.
      final bio = await BiometricService.authenticate(checkIn
          ? 'ضع بصمتك لتسجيل الدخول'
          : 'ضع بصمتك لتسجيل الخروج');
      if (bio == BioResult.notEnrolled) {
        _toast('لا توجد بصمة مسجّلة على هذا الجهاز. أضِف بصمتك من إعدادات الهاتف.');
        return;
      }
      if (bio == BioResult.failed) {
        _toast('تعذّر التحقق من البصمة. حاول مجددًا.');
        return;
      }
      final noSensor = bio == BioResult.unavailable;

      // (4) تسجيل الوقت والتاريخ تلقائيًا، مع حفظ مواعيد دوام الموقع بالسجل.
      if (checkIn) {
        await Db.attendance.add({
          'name': _emp!.name,
          'employeeId': _emp!.id,
          'checkIn': DateTime.now().toIso8601String(),
          'checkOut': null,
          'note': '',
          'lat': pos.latitude,
          'lng': pos.longitude,
          'method': 'fingerprint',
          'locationId': matched.id,
          'locationName': matched.name,
          'workStart': matched.workStart,
          'workEnd': matched.workEnd,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _toast(noSensor
            ? 'تم تسجيل الدخول (هذا الجهاز لا يدعم البصمة).'
            : 'تم تسجيل دخولك بالبصمة ✅');
      } else {
        final open = recs.where((r) => r.data()['checkOut'] == null).toList();
        await open.first.reference
            .update({'checkOut': DateTime.now().toIso8601String()});
        _toast(noSensor
            ? 'تم تسجيل الخروج (هذا الجهاز لا يدعم البصمة).'
            : 'تم تسجيل خروجك بالبصمة ✅');
      }
    } on LocationException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر إتمام العملية. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    if (_emp == null) {
      return EmployeeLogin(
        onSuccess: _onLogin,
        subtitle: 'أدخل اسمك ورمزك السري لعرض سجلّك وتسجيل حضورك.',
      );
    }
    final emp = _emp!;
    final stream =
        Db.attendance.where('employeeId', isEqualTo: emp.id).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final hasError = snap.hasError;
        final loading = !snap.hasData && !hasError;
        final recs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) {
            final ca = DateTime.tryParse('${a.data()['checkIn']}');
            final cb = DateTime.tryParse('${b.data()['checkIn']}');
            return (cb ?? DateTime(0)).compareTo(ca ?? DateTime(0));
          });

        int worked = 0, overtime = 0, late = 0;
        bool hasOpen = false;
        for (final r in recs) {
          final st = WorkTime.stats(r.data());
          final isHol = _holidays.contains(WorkTime.attendanceDateKey(r.data()));
          if (st.open) {
            hasOpen = true;
          } else if (!isHol) {
            worked += st.worked;
            overtime += st.overtime;
            late += st.late;
          }
        }

        return PagePadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('نظام البصمة',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  EmployeeBar(
                    name: emp.name,
                    onLogout: _logout,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            hasOpen ? AppColors.green100 : AppColors.cream200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(hasOpen ? 'داخل الآن' : 'خارج',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fingerprint,
                            size: 20, color: AppColors.green700),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('تسجيل الحضور والانصراف بالبصمة',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasOpen
                              ? AppColors.green100
                              : AppColors.cream100,
                          border: Border.all(
                              color: hasOpen
                                  ? AppColors.green400
                                  : AppColors.line,
                              width: 2),
                        ),
                        child: Icon(Icons.fingerprint,
                            size: 60,
                            color: hasOpen
                                ? AppColors.green600
                                : AppColors.green700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                          hasOpen
                              ? 'أنت داخل الآن — اضغط «بصمة الخروج» عند الانصراف'
                              : 'ضع بصمتك واضغط «بصمة الدخول» للبدء',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_busy || hasOpen)
                                ? null
                                : () => _attendanceAction(
                                    checkIn: true, recs: recs),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login, size: 20),
                            label: const Text('بصمة الدخول'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_busy || !hasOpen)
                                ? null
                                : () => _attendanceAction(
                                    checkIn: false, recs: recs),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('بصمة الخروج'),
                          ),
                        ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 10),
                      const Text('جارٍ التحقق من الموقع والبصمة…',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _locationStatusCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: KpiCard('إجمالي ساعات العمل',
                          WorkTime.minutesToText(worked))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: KpiCard('إجمالي الساعات الإضافية',
                          WorkTime.minutesToText(overtime))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: KpiCard(
                          'إجمالي التأخير', WorkTime.minutesToText(late))),
                ],
              ),
              const SizedBox(height: 22),
              const SectionHeader('سجل البصمة'),
              if (widget.canManage) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _recordDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة سجل يدوي'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: LoadingView(text: 'جارٍ تحميل سجلّك…'),
                )
              else if (hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: MessageView(
                    icon: Icons.cloud_off,
                    title: 'تعذّر تحميل السجل',
                    subtitle: 'تأكّد من اتصال الإنترنت ثم حاول مجددًا.',
                    color: AppColors.danger,
                  ),
                )
              else
                _recordsTable(recs),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// بطاقة تُظهر للموظف مواقع البصمة المسموحة لقسمه ومواعيد الدوام فيها.
  Widget _locationStatusCard() {
    if (!_locsLoaded || !_deptLoaded) return const SizedBox.shrink();

    final locs = _allLocations;
    if (locs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'لم يحدّد المدير موقع بصمة لقسمك بعد. لا يمكن تسجيل الحضور حتى يُحدَّد من لوحة التحكم.',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in locs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.green700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name.isEmpty ? 'موقع البصمة' : l.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          'الدوام: ${ArDate.clockLabel(l.workStart)} — ${ArDate.clockLabel(l.workEnd)}',
                          style: const TextStyle(
                              color: AppColors.textSoft, fontSize: 12)),
                      Text('الأيام: ${arWeekdaysLabel(l.workDays)}',
                          style: const TextStyle(
                              color: AppColors.textSoft, fontSize: 12)),
                      Text('يجب أن تكون ضمن ${l.radius} متر من الموقع',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recordsTable(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> recs) {
    if (recs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('لا توجد سجلات بعد. اضغط «بصمة الدخول» للبدء.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.cream100),
        columns: [
          const DataColumn(label: Text('التاريخ')),
          const DataColumn(label: Text('الدخول')),
          const DataColumn(label: Text('الخروج')),
          const DataColumn(label: Text('ساعات العمل')),
          const DataColumn(label: Text('الإضافي')),
          const DataColumn(label: Text('التأخير')),
          const DataColumn(label: Text('ملاحظة')),
          if (widget.canManage) const DataColumn(label: Text('تعديل')),
        ],
        rows: [
          for (final r in recs) _row(r),
        ],
      ),
    );
  }

  DataRow _row(QueryDocumentSnapshot<Map<String, dynamic>> r) {
    final data = r.data();
    final st = WorkTime.stats(data);
    final isHol = _holidays.contains(WorkTime.attendanceDateKey(data));
    final dash = (st.open || isHol);
    final note = (data['note'] ?? '').toString();
    return DataRow(cells: [
      DataCell(Text(isHol
          ? '${ArDate.dateOnly(data['checkIn'])} (عطلة)'
          : ArDate.dateOnly(data['checkIn']))),
      DataCell(Text(ArDate.timeOnly(data['checkIn']))),
      DataCell(st.open
          ? const Text('داخل الآن', style: TextStyle(color: AppColors.green600))
          : Text(ArDate.timeOnly(data['checkOut']))),
      DataCell(Text(dash ? '—' : WorkTime.minutesToText(st.worked))),
      DataCell(Text(dash ? '—' : WorkTime.minutesToText(st.overtime))),
      DataCell(Text(dash ? '—' : WorkTime.minutesToText(st.late))),
      DataCell(Text(note.isEmpty ? '—' : note)),
      if (widget.canManage)
        DataCell(IconButton(
          icon: const Icon(Icons.edit, size: 18, color: AppColors.green700),
          tooltip: 'تعديل السجل',
          onPressed: () => _recordDialog(r),
        )),
    ]);
  }

  /// إدارة سجل حضور: إضافة سجل يدوي جديد (r == null) أو تعديل/حذف سجل قائم.
  /// متاحة في وضع الإدارة فقط (لوحة التحكم/المحاسبين).
  Future<void> _recordDialog(
      [QueryDocumentSnapshot<Map<String, dynamic>>? r]) async {
    final data = r?.data() ?? {};
    final isNew = r == null;
    DateTime? ci = isNew
        ? DateTime.now()
        : DateTime.tryParse('${data['checkIn']}');
    DateTime? co =
        data['checkOut'] == null ? null : DateTime.tryParse('${data['checkOut']}');
    final noteC = TextEditingController(text: data['note']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> pick(bool isIn) async {
          final base = (isIn ? ci : co) ?? DateTime.now();
          final d = await showDatePicker(
            context: ctx,
            initialDate: base,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (d == null) return;
          if (!ctx.mounted) return;
          final t = await showTimePicker(
              context: ctx, initialTime: TimeOfDay.fromDateTime(base));
          if (t == null) return;
          final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
          setLocal(() {
            if (isIn) {
              ci = dt;
            } else {
              co = dt;
            }
          });
        }

        String fmt(DateTime? dt) => dt == null
            ? '—'
            : '${ArDate.dateOnly(dt)} · ${ArDate.timeOnly(dt)}';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isNew ? 'إضافة سجل حضور' : 'تعديل سجل الحضور'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('وقت الدخول', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pick(true),
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(fmt(ci)),
                  ),
                  const SizedBox(height: 12),
                  const Text('وقت الخروج', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.logout, size: 16),
                    label: Text(co == null ? 'لا يوجد (داخل الآن)' : fmt(co)),
                  ),
                  if (co != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setLocal(() => co = null),
                        child: const Text('مسح وقت الخروج'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(labelText: 'ملاحظة'),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () async {
                    await r.reference.delete();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('حذف',
                      style: TextStyle(color: AppColors.danger)),
                ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: ci == null
                    ? null
                    : () async {
                        if (isNew) {
                          final loc = _allLocations.isNotEmpty
                              ? _allLocations.first
                              : null;
                          await Db.attendance.add({
                            'name': _emp!.name,
                            'employeeId': _emp!.id,
                            'checkIn': ci!.toIso8601String(),
                            'checkOut': co?.toIso8601String(),
                            'note': noteC.text.trim(),
                            'method': 'manual',
                            'workStart': loc?.workStart ?? WorkTime.workStartMin,
                            'workEnd': loc?.workEnd ?? WorkTime.workEndMin,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await Db.updateAttendanceRecord(
                            r.id,
                            checkInIso: ci!.toIso8601String(),
                            checkOutIso: co?.toIso8601String(),
                            note: noteC.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text(isNew ? 'إضافة' : 'حفظ'),
              ),
            ],
          ),
        );
      }),
    );
  }
}
