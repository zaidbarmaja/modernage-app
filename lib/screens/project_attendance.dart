import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import 'project_form.dart';

/// بطاقة بصمة الحضور من داخل صفحة المشروع (لموظف التنفيذ).
/// يسجّل الموظف دخوله/خروجه فقط إن كان داخل نطاق موقع المشروع الذي حدّده المدير.
class ProjectAttendanceCard extends StatefulWidget {
  final EmployeeSession employee;
  final String projectId;
  final String projectName;
  final double? lat;
  final double? lng;
  final int radius;
  const ProjectAttendanceCard({
    required this.employee,
    required this.projectId,
    required this.projectName,
    required this.lat,
    required this.lng,
    required this.radius,
    super.key,
  });

  @override
  State<ProjectAttendanceCard> createState() => _ProjectAttendanceCardState();
}

class _ProjectAttendanceCardState extends State<ProjectAttendanceCard> {
  bool _busy = false;
  Set<String> _holidays = {};

  @override
  void initState() {
    super.initState();
    Db.holidays.get().then((s) {
      if (mounted) setState(() => _holidays = s.docs.map((d) => d.id).toSet());
    }).catchError((_) {});
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool get _hasLocation => widget.lat != null && widget.lng != null;

  Future<void> _action({
    required bool checkIn,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> open,
  }) async {
    if (_busy) return;
    final todayKey = WorkTime.dateKey(DateTime.now());

    if (checkIn) {
      if (_holidays.contains(todayKey)) {
        _toast('اليوم عطلة رسمية، لا يمكن تسجيل الدخول.');
        return;
      }
      if (open.isNotEmpty) {
        _toast('لديك تسجيل دخول مفتوح بالفعل.');
        return;
      }
    } else if (open.isEmpty) {
      _toast('لا يوجد تسجيل دخول مفتوح.');
      return;
    }

    if (!_hasLocation) {
      _toast('لم يحدّد المدير موقعًا لهذا المشروع بعد.');
      return;
    }

    setState(() => _busy = true);
    try {
      // (1) فحص الموقع: ضمن نطاق موقع المشروع؟
      final pos = await LocationService.currentPosition();
      final tolerance = (pos.accuracy.isFinite ? pos.accuracy : 0).clamp(0, 75);
      final dist = LocationService.distanceMeters(
          widget.lat!, widget.lng!, pos.latitude, pos.longitude);
      if (dist > widget.radius + tolerance) {
        _toast(
            'أنت خارج موقع المشروع (تبعُد ${dist.round()} م). يجب أن تكون داخل الموقع لتسجيل البصمة.');
        return;
      }

      // (2) التحقق ببصمة الإصبع.
      final bio = await BiometricService.authenticate(checkIn
          ? 'ضع بصمتك لتسجيل الدخول في المشروع'
          : 'ضع بصمتك لتسجيل الخروج');
      if (bio == BioResult.notEnrolled) {
        _toast('لا توجد بصمة مسجّلة على هذا الجهاز. أضِفها من إعدادات الهاتف.');
        return;
      }
      if (bio == BioResult.failed) {
        _toast('تعذّر التحقق من البصمة. حاول مجددًا.');
        return;
      }
      final noSensor = bio == BioResult.unavailable;

      // (3) تسجيل الوقت تلقائيًا.
      if (checkIn) {
        await Db.attendance.add({
          'name': widget.employee.name,
          'employeeId': widget.employee.id,
          'checkIn': DateTime.now().toIso8601String(),
          'checkOut': null,
          'note': '',
          'lat': pos.latitude,
          'lng': pos.longitude,
          'method': 'fingerprint',
          'locationId': 'proj_${widget.projectId}',
          'locationName': widget.projectName,
          'projectId': widget.projectId,
          'workStart': WorkTime.workStartMin,
          'workEnd': WorkTime.workEndMin,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _toast(noSensor
            ? 'تم تسجيل الدخول (الجهاز لا يدعم البصمة).'
            : 'تم تسجيل دخولك من المشروع ✅');
      } else {
        await open.first.reference
            .update({'checkOut': DateTime.now().toIso8601String()});
        _toast(noSensor
            ? 'تم تسجيل الخروج (الجهاز لا يدعم البصمة).'
            : 'تم تسجيل خروجك ✅');
      }
    } on LocationException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر إتمام العملية. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.attendance
          .where('employeeId', isEqualTo: widget.employee.id)
          .snapshots(),
      builder: (context, snap) {
        // ساعة حضور واحدة للموظف: أي سجل مفتوح يعني أنه «داخل الآن».
        // نرتّب تنازليًا حسب وقت الدخول حتى يُغلق الأحدث بشكل حتمي عند الخروج.
        final open = (snap.data?.docs ?? [])
            .where((r) => r.data()['checkOut'] == null)
            .toList()
          ..sort((a, b) {
            final ca =
                DateTime.tryParse('${a.data()['checkIn']}') ?? DateTime(0);
            final cb =
                DateTime.tryParse('${b.data()['checkIn']}') ?? DateTime(0);
            return cb.compareTo(ca);
          });
        final hasOpen = open.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasOpen ? AppColors.green100 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: hasOpen ? AppColors.green400 : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint,
                      color: AppColors.green700, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('بصمة الحضور من داخل الموقع',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          hasOpen ? AppColors.green600 : AppColors.cream200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(hasOpen ? 'داخل الآن' : 'خارج',
                        style: TextStyle(
                            fontSize: 11,
                            color: hasOpen ? Colors.white : AppColors.textSoft)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_hasLocation)
                const Text(
                    'لم يحدّد المدير موقع هذا المشروع بعد — لا يمكن تسجيل البصمة.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12))
              else
                Text(
                    'سجّل دخولك/خروجك بالبصمة وأنت داخل موقع المشروع (${widget.radius} م).',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_busy || hasOpen || !_hasLocation)
                          ? null
                          : () => _action(checkIn: true, open: open),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login, size: 18),
                      label: const Text('بصمة الدخول'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || !hasOpen)
                          ? null
                          : () => _action(checkIn: false, open: open),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('بصمة الخروج'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// بطاقة بصمة عامة في صفحة الموظف: يسجّل دخوله/خروجه إن كان داخل نطاق أحد
/// مواقعه المعتمدة (موقع قسمه أو أي من مواقع مشاريعه).
class AttendanceCheckCard extends StatefulWidget {
  final EmployeeSession employee;
  const AttendanceCheckCard({required this.employee, super.key});
  @override
  State<AttendanceCheckCard> createState() => _AttendanceCheckCardState();
}

class _AttendanceCheckCardState extends State<AttendanceCheckCard> {
  bool _busy = false;
  String _deptId = '';
  Set<String> _holidays = {};
  List<AttendanceLocation> _deptLocations = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _execDocs = [];
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _loadDept();
    _subs.add(Db.holidays.snapshots().listen((s) {
      if (mounted) setState(() => _holidays = s.docs.map((d) => d.id).toSet());
    }));
    _subs.add(Db.attendanceLocations.snapshots().listen((s) {
      if (!mounted) return;
      setState(() => _deptLocations = s.docs
          .map((d) => AttendanceLocation.fromDoc(d.id, d.data()))
          .whereType<AttendanceLocation>()
          .toList());
    }));
    _subs.add(Db.executionProjects.snapshots().listen((s) {
      if (mounted) setState(() => _execDocs = s.docs);
    }));
  }

  Future<void> _loadDept() async {
    try {
      final doc = await Db.employees.doc(widget.employee.id).get();
      if (mounted) {
        setState(
            () => _deptId = (doc.data()?['departmentId'] ?? '').toString());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// مواقع البصمة المتاحة: موقع القسم + مواقع مشاريع التنفيذ المكلّف بها.
  List<AttendanceLocation> get _geofences {
    final out = <AttendanceLocation>[];
    out.addAll(_deptLocations.where((l) => l.departmentId == _deptId));
    for (final doc in _execDocs) {
      final d = doc.data();
      if (!projectAssignedTo(d, widget.employee.id)) continue;
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
        workDays: const [1, 2, 3, 4, 5, 6, 7],
      ));
    }
    return out;
  }

  Future<void> _action({
    required bool checkIn,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> open,
  }) async {
    if (_busy) return;
    final todayKey = WorkTime.dateKey(DateTime.now());
    if (checkIn) {
      if (_holidays.contains(todayKey)) {
        _toast('اليوم عطلة رسمية، لا يمكن تسجيل الدخول.');
        return;
      }
      if (open.isNotEmpty) {
        _toast('لديك تسجيل دخول مفتوح بالفعل.');
        return;
      }
    } else if (open.isEmpty) {
      _toast('لا يوجد تسجيل دخول مفتوح.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (checkIn) {
        final locs = _geofences;
        if (locs.isEmpty) {
          _toast('لا يوجد موقع بصمة لك بعد (موقع قسم أو موقع مشروع).');
          return;
        }
        final pos = await LocationService.currentPosition();
        final tolerance =
            (pos.accuracy.isFinite ? pos.accuracy : 0).clamp(0, 75);
        final todayWd = DateTime.now().weekday;
        AttendanceLocation? matched;
        double nearest = double.infinity;
        var inRangeOffDay = false;
        for (final l in locs) {
          final dd = LocationService.distanceMeters(
              l.lat, l.lng, pos.latitude, pos.longitude);
          if (dd < nearest) nearest = dd;
          if (dd <= l.radius + tolerance) {
            if (l.workDays.contains(todayWd)) {
              matched = l;
              break;
            } else {
              inRangeOffDay = true;
            }
          }
        }
        if (matched == null) {
          _toast(inRangeOffDay
              ? 'اليوم (${arWeekday(todayWd)}) ليس من أيام الدوام في موقعك.'
              : 'أنت خارج نطاق موقع العمل (أقرب موقع يبعُد ${nearest.round()} م).');
          return;
        }
        final bio =
            await BiometricService.authenticate('ضع بصمتك لتسجيل الدخول');
        if (bio == BioResult.notEnrolled) {
          _toast('لا توجد بصمة مسجّلة على هذا الجهاز.');
          return;
        }
        if (bio == BioResult.failed) {
          _toast('تعذّر التحقق من البصمة. حاول مجددًا.');
          return;
        }
        final noSensor = bio == BioResult.unavailable;
        await Db.attendance.add({
          'name': widget.employee.name,
          'employeeId': widget.employee.id,
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
            ? 'تم تسجيل الدخول (الجهاز لا يدعم البصمة).'
            : 'تم تسجيل دخولك بالبصمة ✅');
      } else {
        final bio =
            await BiometricService.authenticate('ضع بصمتك لتسجيل الخروج');
        if (bio == BioResult.failed) {
          _toast('تعذّر التحقق من البصمة. حاول مجددًا.');
          return;
        }
        await open.first.reference
            .update({'checkOut': DateTime.now().toIso8601String()});
        _toast('تم تسجيل خروجك ✅');
      }
    } on LocationException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر إتمام العملية. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.attendance
          .where('employeeId', isEqualTo: widget.employee.id)
          .snapshots(),
      builder: (context, snap) {
        // ساعة حضور واحدة: يُغلق الأحدث حتميًا عند الخروج (ترتيب تنازلي بالدخول).
        final open = (snap.data?.docs ?? [])
            .where((r) => r.data()['checkOut'] == null)
            .toList()
          ..sort((a, b) {
            final ca =
                DateTime.tryParse('${a.data()['checkIn']}') ?? DateTime(0);
            final cb =
                DateTime.tryParse('${b.data()['checkIn']}') ?? DateTime(0);
            return cb.compareTo(ca);
          });
        final hasOpen = open.isNotEmpty;
        final hasGeofence = _geofences.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasOpen ? AppColors.green100 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: hasOpen ? AppColors.green400 : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint,
                      color: AppColors.green700, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('بصمة الحضور',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          hasOpen ? AppColors.green600 : AppColors.cream200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(hasOpen ? 'داخل الآن' : 'خارج',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                hasOpen ? Colors.white : AppColors.textSoft)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  hasGeofence
                      ? 'سجّل دخولك/خروجك بالبصمة وأنت داخل موقع عملك.'
                      : 'لم يُحدّد لك موقع بصمة بعد (موقع قسم أو مشروع).',
                  style: TextStyle(
                      color: hasGeofence ? AppColors.muted : AppColors.danger,
                      fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_busy || hasOpen)
                          ? null
                          : () => _action(checkIn: true, open: open),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login, size: 18),
                      label: const Text('بصمة الدخول'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || !hasOpen)
                          ? null
                          : () => _action(checkIn: false, open: open),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('بصمة الخروج'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
