import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/company_settings.dart';
import '../../models/work_site.dart';
import '../../services/biometric_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/ui.dart';

/// نطاق حضور معتمد (geofence): إحداثيات + نصف قطر (متر) + اسم للعرض.
/// موظف التصميم: نطاق واحد = مقر الشركة. موظف التنفيذ: نطاقات = مواقع مشاريعه.
class AttendanceFence {
  final double lat;
  final double lng;
  final int radius;
  final String name;
  const AttendanceFence(this.lat, this.lng, this.radius, this.name);
}

/// واجهة البصمة: تسجيل دخول/خروج **يدوي** بالموقع + ملخّص الساعات والسجل.
/// تُستخدم تفاعلياً للموظف، أو للعرض فقط في لوحة المحاسبة.
///
/// الموقع يُطلب **لحظة الضغط على زر البصمة فقط** («أثناء الاستخدام») — لا يوجد
/// أي تتبّع في الخلفية.
class AttendanceView extends StatefulWidget {
  final AppUser user;
  final bool interactive; // true = يمكن تسجيل بصمة، false = عرض فقط

  /// إعدادات الشركة (وقت الدوام الموحّد + موقع الشركة). يُحسب الدوام من أوقاتها.
  final CompanySettings company;

  /// النطاقات المسموح تسجيل الحضور من داخلها. فارغة = لا تحقّق من النطاق
  /// (يُسجَّل الموقع فقط دون منع).
  final List<AttendanceFence> fences;

  const AttendanceView({
    super.key,
    required this.user,
    this.interactive = true,
    this.company = const CompanySettings(),
    this.fences = const [],
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final _fs = FirestoreService();

  /// مجرى سجلات الحضور — يُنشأ مرّة واحدة كي لا تومض الشاشة بـ«جارٍ التحميل»
  /// عند كل ضغطة أو تغيير فلتر (لو أُنشئ في build لأعاد الاشتراك في كل مرّة).
  late final Stream<List<AttendanceRecord>> _attStream =
      _fs.attendanceForUser(widget.user.uid);

  /// الشهر المختار لفلترة الملخّص والسجل (null = كل الأشهر). الافتراضي: هذا الشهر.
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// جارٍ تسجيل بصمة الآن (يمنع الضغط المزدوج).
  bool _busy = false;

  bool get _isFriday => DateTime.now().weekday == weekendDay;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _attStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final records = snapshot.data ?? [];
        // سجل اليوم (للحالة المكتملة) + أي سجل مفتوح (لم يُسجَّل خروجه بعد) — حتى لو
        // كان دخوله بالأمس (تسجيل خروج بعد منتصف الليل).
        final now = DateTime.now();
        AttendanceRecord? today;
        AttendanceRecord? openRec;
        for (final r in records) {
          if (openRec == null && r.isOpen) openRec = r;
          if (today == null &&
              r.checkIn.year == now.year &&
              r.checkIn.month == now.month &&
              r.checkIn.day == now.day) {
            today = r;
          }
        }
        // فلترة بالشهر المختار (تطبَّق على الملخّص والسجل).
        final months = _availableMonths(records);
        final sel = _month;
        final filtered = sel == null
            ? records
            : records
                .where((r) =>
                    r.checkIn.year == sel.year && r.checkIn.month == sel.month)
                .toList();
        final summary = AttendanceSummary.fromRecords(filtered);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _scheduleCard(),
            const SizedBox(height: 12),
            if (widget.interactive) ...[
              _manualCard(today, openRec),
              const SizedBox(height: 12),
            ],
            _monthFilterCard(months),
            const SizedBox(height: 12),
            _summaryCard(summary),
            const SizedBox(height: 12),
            Text('سجل البصمة',
                style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const EmptyState(
                  message: 'لا توجد سجلات بصمة لهذه الفترة.',
                  icon: Icons.fingerprint),
            ...filtered.map(_historyTile),
          ],
        );
      },
    );
  }

  static String _fmtMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// الأشهر المتاحة للفلترة (الأحدث أولاً) — أشهر السجلات + الشهر الحالي دائماً.
  List<DateTime> _availableMonths(List<AttendanceRecord> records) {
    final byKey = <String, DateTime>{};
    final now = DateTime.now();
    final cur = DateTime(now.year, now.month);
    byKey['${cur.year}-${cur.month}'] = cur;
    for (final r in records) {
      final m = DateTime(r.checkIn.year, r.checkIn.month);
      byKey['${m.year}-${m.month}'] = m;
    }
    final list = byKey.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  static String _monthLabel(DateTime m) =>
      DateFormat('MMMM yyyy', 'ar').format(m);

  Widget _monthFilterCard(List<DateTime> months) {
    return SectionCard(
      title: 'فلترة الملخّص بالشهر',
      icon: Icons.filter_alt,
      child: DropdownButtonFormField<DateTime?>(
        initialValue: _month,
        isExpanded: true,
        dropdownColor: AppColors.surfaceAlt,
        decoration: const InputDecoration(
          labelText: 'الشهر',
          prefixIcon: Icon(Icons.calendar_month),
        ),
        items: [
          const DropdownMenuItem<DateTime?>(
              value: null, child: Text('كل الأشهر')),
          ...months.map((m) => DropdownMenuItem<DateTime?>(
                value: m,
                child: Text(_monthLabel(m)),
              )),
        ],
        onChanged: (v) => setState(() => _month = v),
      ),
    );
  }

  Widget _scheduleCard() {
    final u = widget.user;
    final c = widget.company;
    final hours =
        ((c.workEndMin - c.workStartMin) / 60).toStringAsFixed(1);
    return SectionCard(
      title: 'دوام اليوم',
      icon: Icons.schedule,
      child: Column(
        children: [
          if (u.department != Department.none)
            InfoRow(label: 'القسم', value: u.department.labelAr),
          InfoRow(
              label: 'الدوام الرسمي',
              value:
                  'من ${_fmtMin(c.workStartMin)} إلى ${_fmtMin(c.workEndMin)}'),
          InfoRow(label: 'ساعات الدوام', value: '$hours ساعة'),
          InfoRow(label: 'التاريخ', value: Fmt.date(DateTime.now())),
          if (_isFriday)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.weekend, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('اليوم عطلة (الجمعة) — لا يوجد دوام',
                        style: TextStyle(color: AppColors.warning)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// بطاقة البصمة اليدوية: زر «تسجيل الحضور»/«تسجيل الانصراف» يطلب الموقع لحظة
  /// الضغط فقط. عطلة الجمعة تُعطّل الزر.
  Widget _manualCard(AttendanceRecord? today, AttendanceRecord? openRec) {
    Widget statusRow(IconData icon, Color color, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.cream, height: 1.6)),
            ),
          ],
        );

    final children = <Widget>[];
    final now = DateTime.now();

    if (_isFriday && openRec == null) {
      children.add(statusRow(Icons.weekend, AppColors.warning,
          'اليوم عطلة (الجمعة) — لا حاجة لتسجيل الحضور.'));
    } else if (openRec != null) {
      // يوجد دوام مفتوح (اليوم أو من يوم سابق) — زر الانصراف.
      final rec = openRec;
      final sameDay = rec.checkIn.year == now.year &&
          rec.checkIn.month == now.month &&
          rec.checkIn.day == now.day;
      final when = sameDay
          ? 'الساعة ${Fmt.time(rec.checkIn)}'
          : 'بتاريخ ${Fmt.date(rec.checkIn)} الساعة ${Fmt.time(rec.checkIn)}';
      children.add(statusRow(Icons.login, AppColors.oliveBright,
          'سجّلت دخولك $when. اضغط للانصراف عند مغادرتك.'));
      children.add(const SizedBox(height: 12));
      children.add(SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : () => _checkOut(rec),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          icon: _busy
              ? const _Spinner()
              : const Icon(Icons.logout),
          label: const Text('تسجيل الانصراف',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ));
    } else if (today != null && !today.isOpen) {
      children.add(statusRow(
          Icons.verified,
          AppColors.success,
          'اكتمل دوام اليوم ✓\nدخول ${Fmt.time(today.checkIn)}  •  '
          'خروج ${Fmt.time(today.checkOut)}'));
    } else {
      children.add(statusRow(
          Icons.my_location,
          AppColors.oliveBright,
          widget.fences.isEmpty
              ? 'اضغط لتسجيل حضورك. سيُطلب إذن الموقع لحظة التسجيل فقط.'
              : 'اضغط لتسجيل حضورك من داخل نطاق موقع العمل. سيُطلب إذن الموقع '
                  'لحظة التسجيل فقط.'));
      children.add(const SizedBox(height: 12));
      children.add(SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _checkIn,
          icon: _busy ? const _Spinner() : const Icon(Icons.fingerprint),
          label: const Text('تسجيل الحضور',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ));
    }

    return SectionCard(
      title: 'تسجيل الحضور',
      icon: Icons.fingerprint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// يجلب الموقع الحالي (يطلب الإذن لحظتها)، ويتحقّق من النطاق إن وُجد، ثم يسجّل الدخول.
  Future<void> _checkIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // بصمة الإصبع للتحقّق من هوية الموظف قبل التسجيل.
      final bio = await BiometricService.verify('أكّد بصمة إصبعك لتسجيل الحضور');
      if (bio == BioResult.failed) {
        if (mounted) {
          showSnack(context, 'لم يتم التحقّق من بصمتك. حاول مجددًا.',
              error: true);
        }
        return;
      }

      final pos = await LocationService.currentPosition();

      // تحقّق النطاق (إن حُدِّد): يجب أن يكون داخل أحد نطاقات موقع العمل.
      final fences = widget.fences;
      if (fences.isNotEmpty) {
        double nearestEdge = double.infinity;
        AttendanceFence? nearest;
        for (final f in fences) {
          final d = LocationService.distanceMeters(
              pos.latitude, pos.longitude, f.lat, f.lng);
          final edge = d - f.radius; // سالب = بالداخل
          if (edge < nearestEdge) {
            nearestEdge = edge;
            nearest = f;
          }
        }
        final tol = (pos.accuracy.isFinite ? pos.accuracy : 0).clamp(0, 50);
        if (nearestEdge > tol) {
          if (mounted) {
            showSnack(
                context,
                'أنت خارج نطاق موقع العمل '
                '(تبعد ${nearestEdge.round()} م عن ${nearest?.name ?? 'الموقع'}). '
                'اقترب من الموقع وحاول مجددًا.',
                error: true);
          }
          return;
        }
      }

      final u = widget.user;
      final c = widget.company;
      await _fs.checkIn(AttendanceRecord(
        id: '',
        uid: u.uid,
        userName: u.name,
        department: u.department,
        workStartMin: u.workStartMin ?? c.workStartMin,
        workEndMin: u.workEndMin ?? c.workEndMin,
        checkIn: DateTime.now(),
        checkInLat: pos.latitude,
        checkInLng: pos.longitude,
      ));
      if (mounted) showSnack(context, 'تم تسجيل دخولك ✓');
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'تعذّر تسجيل الحضور. حاول مجددًا.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// يسجّل انصراف السجل المفتوح [rec]. لا يُمنع خارج النطاق (قد يغادر الموظف)،
  /// ولا يُمنع إن تعذّر تحديد الموقع (يُسجَّل بلا إحداثيات)، ويُغلَق سجل يوم الدخول
  /// نفسه (يعمل حتى لو تجاوز منتصف الليل).
  Future<void> _checkOut(AttendanceRecord rec) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // بصمة الإصبع للتحقّق من هوية الموظف قبل تسجيل الانصراف.
      final bio =
          await BiometricService.verify('أكّد بصمة إصبعك لتسجيل الانصراف');
      if (bio == BioResult.failed) {
        if (mounted) {
          showSnack(context, 'لم يتم التحقّق من بصمتك. حاول مجددًا.',
              error: true);
        }
        return;
      }

      // نحاول تحديد الموقع، لكن لا نمنع الانصراف إن تعذّر (GPS مطفأ عند المغادرة).
      double? lat, lng;
      try {
        final pos = await LocationService.currentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      await _fs.checkOut(widget.user.uid,
          recordDate: rec.checkIn,
          checkOutTime: DateTime.now(),
          lat: lat,
          lng: lng);
      if (mounted) showSnack(context, 'تم تسجيل انصرافك ✓');
    } catch (_) {
      if (mounted) {
        showSnack(context, 'تعذّر تسجيل الانصراف. حاول مجددًا.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _summaryCard(AttendanceSummary s) {
    return SectionCard(
      title: 'الملخّص',
      icon: Icons.insights,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          StatTile(
              value: '${s.workDays}',
              label: 'عدد أيام الدوام',
              icon: Icons.event_available),
          StatTile(
              value: Fmt.hours(s.totalWorkedMinutes),
              label: 'إجمالي ساعات العمل',
              icon: Icons.timelapse),
          StatTile(
              value: Fmt.hours(s.totalChangeMinutes),
              label: 'ساعات التغيّر (تأخير/انصراف مبكر)',
              icon: Icons.swap_vert,
              color: AppColors.warning),
          StatTile(
              value: Fmt.hours(s.totalOvertimeMinutes),
              label: 'الساعات الإضافية',
              icon: Icons.add_alarm,
              color: AppColors.success),
        ],
      ),
    );
  }

  Widget _historyTile(AttendanceRecord r) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: AppColors.oliveBright),
        title: Text(Fmt.date(r.checkIn),
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: Text(
          'دخول ${Fmt.time(r.checkIn)}  •  خروج ${r.checkOut == null ? '—' : Fmt.time(r.checkOut)}'
          '${r.checkOut != null ? '\nإضافي: ${Fmt.duration(r.overtimeMinutes)}  •  تغيّر: ${Fmt.duration(r.changeMinutes)}' : ''}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.5),
        ),
        isThreeLine: r.checkOut != null,
      ),
    );
  }
}

/// مؤشّر دوران صغير داخل زر البصمة أثناء تحديد الموقع.
class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
            color: AppColors.cream, strokeWidth: 2.4),
      );
}

/// تبويب البصمة للموظف: يجلب إعدادات الشركة (وقت الدوام) ونطاقات الحضور، ويمرّرها
/// لشاشة البصمة. التسجيل **يدوي** (زر يطلب الموقع لحظة الضغط).
///
/// • موظف **التنفيذ**: النطاقات = مواقع مشاريعه المُسندة.
/// • موظف **التصميم/غيره**: النطاق = مقر الشركة (إن حُدِّد).
class AttendanceTab extends StatelessWidget {
  final AppUser user;
  const AttendanceTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<CompanySettings>(
      stream: fs.companySettings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final company = snap.data ?? const CompanySettings();

        // موظف التنفيذ: النطاقات = مواقع مشاريعه (لكل موقع إحداثياته ونطاقه).
        if (user.role == UserRole.executionEmployee) {
          return StreamBuilder<List<WorkSite>>(
            stream: fs.sitesByExecutor(user.uid),
            builder: (context, s2) {
              final sites = s2.data ?? const <WorkSite>[];
              final fences = <AttendanceFence>[
                for (final st in sites)
                  if (st.lat != null && st.lng != null)
                    AttendanceFence(st.lat!, st.lng!, st.radius,
                        st.siteName.isEmpty ? st.ownerName : st.siteName),
              ];
              return AttendanceView(
                  user: user, company: company, fences: fences);
            },
          );
        }

        // موظف التصميم/غيره: نطاق مقر الشركة.
        final fences = company.hasLocation
            ? <AttendanceFence>[
                AttendanceFence(
                    company.lat!, company.lng!, company.radius, 'مقر الشركة'),
              ]
            : const <AttendanceFence>[];
        return AttendanceView(user: user, company: company, fences: fences);
      },
    );
  }
}
