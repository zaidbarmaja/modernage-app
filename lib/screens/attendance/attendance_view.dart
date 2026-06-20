import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/company_settings.dart';
import '../../services/biometric_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/ui.dart';

/// واجهة البصمة: تسجيل دخول/خروج بالموقع + ملخّص الساعات والسجل.
/// تُستخدم تفاعلياً للموظف، أو للعرض فقط في لوحة المحاسبة.
class AttendanceView extends StatefulWidget {
  final AppUser user;
  final bool interactive; // true = يمكن تسجيل بصمة، false = عرض فقط

  /// إعدادات الشركة (موقع البصمة المعتمد + وقت الدوام الموحّد). تُفرض البصمة من
  /// داخل نطاق موقع الشركة إن حُدِّد، ويُحسب الدوام من أوقاتها.
  final CompanySettings company;

  const AttendanceView({
    super.key,
    required this.user,
    this.interactive = true,
    this.company = const CompanySettings(),
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final _fs = FirestoreService();
  bool _busy = false;

  /// الشهر المختار لفلترة الملخّص والسجل (null = كل الأشهر). الافتراضي: هذا الشهر.
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isFriday => DateTime.now().weekday == weekendDay;

  /// تحقّق ببصمة الإصبع قبل التسجيل. يُتجاوز على الأجهزة/المتصفّحات بلا مستشعر
  /// (مثل الويب)، ويُفرض على الهاتف الذي يدعم البصمة.
  Future<bool> _verifyBiometric() async {
    final available = await BiometricService.isAvailable();
    if (!available) return true;
    final res = await BiometricService.authenticate('أكّد بصمتك لتسجيل الحضور');
    if (res == BioResult.success || res == BioResult.unavailable) return true;
    if (mounted) {
      showSnack(
        context,
        res == BioResult.notEnrolled
            ? 'لا توجد بصمة مسجّلة على هذا الجهاز.'
            : 'تعذّر التحقق بالبصمة.',
        error: true,
      );
    }
    return false;
  }

  /// سماحية لخطأ دقّة GPS (متر) تُضاف للنطاق لتفادي الرفض الكاذب عند الحافة.
  static const int _gpsToleranceM = 25;

  /// يتحقّق أن الإحداثيات الحالية داخل نطاق موقع الشركة المعتمد.
  /// يُستخدم لتسجيل الدخول فقط (لا يُقيَّد الخروج حتى لا يُحبس من غادر الموقع).
  /// يعيد null إن كان ضمن النطاق أو لم يُحدَّد موقع الشركة، وإلا رسالة رفض.
  String? _geofenceReject(double lat, double lng) {
    final c = widget.company;
    if (!c.hasLocation) return null; // لم يُحدَّد موقع الشركة بعد → لا فرض
    final d = LocationService.distanceMeters(lat, lng, c.lat!, c.lng!);
    if (d <= c.radius + _gpsToleranceM) return null; // داخل النطاق المسموح
    return 'أنت خارج نطاق موقع الشركة (تبعد ${d.round()} م، والمسموح ${c.radius} م). '
        'اقترب من موقع الشركة ثم سجّل البصمة.';
  }

  Future<void> _punchIn() async {
    setState(() => _busy = true);
    try {
      if (!await _verifyBiometric()) return;
      final loc = await LocationService.getCurrentLocation();
      final reject = _geofenceReject(loc.lat, loc.lng);
      if (reject != null) {
        if (mounted) showSnack(context, reject, error: true);
        return;
      }
      final now = DateTime.now();
      await _fs.checkIn(AttendanceRecord(
        id: '',
        uid: widget.user.uid,
        userName: widget.user.name,
        department: widget.user.department,
        workStartMin: widget.company.workStartMin,
        workEndMin: widget.company.workEndMin,
        checkIn: now,
        checkInLat: loc.lat,
        checkInLng: loc.lng,
      ));
      if (mounted) {
        showSnack(context, 'تم تسجيل بصمة الدخول ✓ (${Fmt.time(now)})');
      }
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تسجيل الدخول.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _punchOut() async {
    setState(() => _busy = true);
    try {
      if (!await _verifyBiometric()) return;
      // لا يُقيَّد الخروج بالنطاق: الموظف قد يكون غادر الموقع، ومنعُه يحبس
      // سجلّ اليوم مفتوحاً. نسجّل موقع الخروج فقط للمراجعة.
      final loc = await LocationService.getCurrentLocation();
      final now = DateTime.now();
      await _fs.checkOut(widget.user.uid,
          checkOutTime: now, lat: loc.lat, lng: loc.lng);
      if (mounted) {
        showSnack(context, 'تم تسجيل بصمة الخروج ✓ (${Fmt.time(now)})');
      }
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تسجيل الخروج.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _fs.attendanceForUser(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final records = snapshot.data ?? [];
        final todayKey = AttendanceRecord.dayKeyOf(DateTime.now());
        AttendanceRecord? today;
        for (final r in records) {
          if (r.dayKey == todayKey) {
            today = r;
            break;
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
              _punchCard(today),
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

  Widget _punchCard(AttendanceRecord? today) {
    final canCheckIn = today == null && !_isFriday;
    final canCheckOut = today != null && today.isOpen;

    return SectionCard(
      title: 'بصمة اليوم',
      icon: Icons.fingerprint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.company.hasLocation) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.oliveBright.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.oliveBright, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'تسجيل الدخول مسموح فقط من داخل نطاق موقع الشركة المعتمد.',
                        style: TextStyle(color: AppColors.cream, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (today != null) ...[
            InfoRow(
                label: 'الدخول',
                value: Fmt.time(today.checkIn),
                icon: Icons.login,
                valueColor: AppColors.success),
            InfoRow(
                label: 'الخروج',
                value: today.checkOut == null
                    ? 'لم يُسجّل بعد'
                    : Fmt.time(today.checkOut),
                icon: Icons.logout,
                valueColor:
                    today.checkOut == null ? AppColors.warning : AppColors.cream),
            if (today.checkOut != null) ...[
              InfoRow(
                  label: 'مدة العمل',
                  value: Fmt.duration(today.workedMinutes)),
              InfoRow(
                  label: 'إضافي',
                  value: Fmt.duration(today.overtimeMinutes),
                  valueColor: AppColors.success),
            ],
            const SizedBox(height: 8),
          ],
          if (canCheckIn)
            ElevatedButton.icon(
              onPressed: _busy ? null : _punchIn,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.cream, strokeWidth: 2.2))
                  : const Icon(Icons.login),
              label: const Text('تسجيل دخول (بصمة بالموقع)'),
            )
          else if (canCheckOut)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.oliveDark),
              onPressed: _busy ? null : _punchOut,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.cream, strokeWidth: 2.2))
                  : const Icon(Icons.logout),
              label: const Text('تسجيل خروج (بصمة بالموقع)'),
            )
          else if (today != null && today.checkOut != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('اكتمل دوام اليوم ✓',
                    style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
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

/// تبويب البصمة للموظف: يجلب إعدادات الشركة (موقع البصمة + وقت الدوام) ويمرّرها
/// لشاشة البصمة، ويُجدول تذكيرات الدخول/الخروج المحلية على وقت دوام الشركة.
class AttendanceTab extends StatefulWidget {
  final AppUser user;
  const AttendanceTab({super.key, required this.user});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final _fs = FirestoreService();
  String _scheduledSig = ''; // توقيع آخر أوقات جُدوِلت (لتفادي التكرار)

  void _maybeSchedule(CompanySettings c) {
    final sig = '${c.workStartMin}-${c.workEndMin}';
    if (sig == _scheduledSig) return;
    _scheduledSig = sig;
    ReminderService.instance.scheduleWorkReminders(
      workStartMin: c.workStartMin,
      workEndMin: c.workEndMin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompanySettings>(
      stream: _fs.companySettings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final company = snap.data ?? const CompanySettings();
        _maybeSchedule(company);
        return AttendanceView(user: widget.user, company: company);
      },
    );
  }
}
