import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/work_site.dart';
import '../../services/biometric_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/ui.dart';

/// واجهة البصمة: تسجيل دخول/خروج بالموقع + ملخّص الساعات والسجل.
/// تُستخدم تفاعلياً للموظف، أو للعرض فقط في لوحة المحاسبة.
class AttendanceView extends StatefulWidget {
  final AppUser user;
  final bool interactive; // true = يمكن تسجيل بصمة، false = عرض فقط

  /// مواقع العمل المسندة (لموظف التنفيذ) — تُستخدم لفحص النطاق الجغرافي.
  final List<WorkSite> geofenceSites;

  /// هل يُفرض النطاق الجغرافي؟ يُفعَّل لموظف التنفيذ (T-3.1). عند تفعيله مع
  /// عدم وجود مواقع مسندة، يُمنع تسجيل الدخول مع رسالة واضحة (لا يُتجاوز الفحص).
  final bool enforceGeofence;

  const AttendanceView({
    super.key,
    required this.user,
    this.interactive = true,
    this.geofenceSites = const [],
    this.enforceGeofence = false,
  });

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final _fs = FirestoreService();
  bool _busy = false;

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

  /// يتحقّق أن الإحداثيات الحالية داخل نطاق أحد مواقع العمل المسندة.
  /// يُستخدم لتسجيل الدخول فقط (لا يُقيَّد الخروج حتى لا يُحبس من غادر الموقع).
  /// يعيد null إن كان ضمن النطاق أو لا فرض، وإلا رسالة رفض عربية واضحة.
  String? _geofenceReject(double lat, double lng) {
    if (!widget.enforceGeofence) return null; // موظف بلا فرض (تصميم/محاسبة)
    if (widget.geofenceSites.isEmpty) {
      return 'لا توجد مواقع عمل مسندة إليك — راجع الإدارة لإسناد موقع.';
    }
    final located = widget.geofenceSites
        .where((s) => s.lat != null && s.lng != null)
        .toList();
    if (located.isEmpty) {
      return 'لم تُحدَّد إحداثيات موقع العمل بعد. راجع الإدارة لضبط الموقع.';
    }
    WorkSite? nearest;
    var best = double.infinity;
    for (final s in located) {
      final d = LocationService.distanceMeters(lat, lng, s.lat!, s.lng!);
      if (d <= s.radius + _gpsToleranceM) return null; // داخل النطاق المسموح
      if (d < best) {
        best = d;
        nearest = s;
      }
    }
    final name = (nearest!.siteName.trim().isNotEmpty)
        ? nearest.siteName.trim()
        : (nearest.ownerName.trim().isEmpty ? 'الموقع' : nearest.ownerName.trim());
    return 'أنت خارج نطاق موقع العمل. أقرب موقع «$name» يبعد ${best.round()} م '
        '(المسموح ${nearest.radius} م). اقترب من الموقع ثم حاول مجدداً.';
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
        workStartMin: widget.user.workStartMin,
        workEndMin: widget.user.workEndMin,
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
        final summary = AttendanceSummary.fromRecords(records);
        final todayKey = AttendanceRecord.dayKeyOf(DateTime.now());
        AttendanceRecord? today;
        for (final r in records) {
          if (r.dayKey == todayKey) {
            today = r;
            break;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _scheduleCard(),
            const SizedBox(height: 12),
            if (widget.interactive) ...[
              _punchCard(today),
              const SizedBox(height: 12),
            ],
            _summaryCard(summary),
            const SizedBox(height: 12),
            Text('سجل البصمة',
                style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const EmptyState(
                  message: 'لا توجد سجلات بصمة بعد.',
                  icon: Icons.fingerprint),
            ...records.map(_historyTile),
          ],
        );
      },
    );
  }

  static String _fmtMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Widget _scheduleCard() {
    final u = widget.user;
    final hours = ((u.workEndMin - u.workStartMin) / 60).toStringAsFixed(1);
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
                  'من ${_fmtMin(u.workStartMin)} إلى ${_fmtMin(u.workEndMin)}'),
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
          if (widget.enforceGeofence) ...[
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
                        'تسجيل الدخول مسموح فقط من داخل نطاق موقع العمل المسند إليك.',
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
