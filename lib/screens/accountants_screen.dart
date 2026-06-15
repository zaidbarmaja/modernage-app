import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import 'design_screen.dart';
import 'execution_screen.dart';
import 'fingerprint_screen.dart';

class AccountantsScreen extends StatefulWidget {
  const AccountantsScreen({super.key});
  @override
  State<AccountantsScreen> createState() => _AccountantsScreenState();
}

class _AccountantsScreenState extends State<AccountantsScreen> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _depts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _emps = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _att = [];
  Set<String> _holidays = {};

  @override
  void initState() {
    super.initState();
    Db.departments.snapshots().listen((s) {
      if (mounted) setState(() => _depts = s.docs);
    });
    Db.employees.snapshots().listen((s) {
      if (mounted) setState(() => _emps = s.docs);
    });
    Db.attendance.snapshots().listen((s) {
      if (mounted) setState(() => _att = s.docs);
    });
    Db.holidays.snapshots().listen((s) {
      if (mounted) setState(() => _holidays = s.docs.map((d) => d.id).toSet());
    });
  }

  int _workedFor(String empId, String empName) {
    int total = 0;
    for (final a in _att) {
      final d = a.data();
      if (_holidays.contains(WorkTime.attendanceDateKey(d))) continue;
      final mins = WorkTime.workedMinutes(d);
      if (mins <= 0) continue;
      final match = d['employeeId'] != null
          ? d['employeeId'] == empId
          : (d['name'] ?? '').toString().trim() == empName.trim();
      if (match) total += mins;
    }
    return total;
  }

  IconData _deptIcon(String name) {
    if (name.contains('تصميم')) return Icons.brush_outlined;
    if (name.contains('تنفيذ')) return Icons.construction_outlined;
    if (name.contains('محاسب')) return Icons.calculate_outlined;
    return Icons.apartment_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final deptNameOf = {
      for (final d in _depts) d.id: (d.data()['name'] ?? '').toString()
    };

    // ترتيب الأقسام حسب الترتيب المعتمد، ثم تجميع الموظفين تحت كل قسم.
    final ordered = _depts.toList()
      ..sort((a, b) {
        final oa = Db.deptOrder[a.data()['name']] ?? 50;
        final ob = Db.deptOrder[b.data()['name']] ?? 50;
        return oa.compareTo(ob);
      });

    return PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المحاسبون',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'للمحاسب صلاحية كاملة على جميع الموظفين: اضغط «افتح صفحته» للدخول إلى صفحة الموظف وإنجاز مهامه نيابةً عنه، أو «البصمة» لمتابعة ساعات عمله.',
              style: TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 18),
          if (_emps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: MessageView(
                icon: Icons.people_outline,
                title: 'لا يوجد موظفون مسجّلون بعد',
                subtitle: 'أضِف الموظفين من «لوحة التحكم» ثم عُد إلى هنا.',
              ),
            )
          else
            for (final d in ordered)
              _departmentBlock(
                  d.id, (d.data()['name'] ?? '').toString(), deptNameOf),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _departmentBlock(
      String deptId, String deptName, Map<String, String> deptNameOf) {
    final emps =
        _emps.where((e) => e.data()['departmentId'] == deptId).toList();
    if (emps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('$deptName · ${emps.length} موظف'),
          AutoGrid(
            minTileWidth: 300,
            gap: 12,
            children: [
              for (final e in emps)
                _employeeCard(
                    e, (deptNameOf[e.data()['departmentId']] ?? deptName)),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _employeeCard(
      QueryDocumentSnapshot<Map<String, dynamic>> e, String dept) {
    final data = e.data();
    final name = (data['name'] ?? '').toString();
    final mins = _workedFor(e.id, name);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.cream100,
                child: Icon(_deptIcon(dept),
                    size: 20, color: AppColors.green700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(dept,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cream50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 15, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                    'ساعات العمل: ${mins > 0 ? WorkTime.minutesToText(mins) : '—'}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openEmployeeAs(e.id, name, dept),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('افتح صفحته'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFingerprintAs(e.id, name),
                  icon: const Icon(Icons.fingerprint, size: 16),
                  label: const Text('البصمة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEmployeeAs(String id, String name, String deptName) async {
    final isExec = deptName.contains('تنفيذ');
    final key = isExec ? Session.executionKey : Session.designKey;
    await Session.set(key, EmployeeSession(id, name));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('صفحة: $name')),
        body: isExec
            ? const ExecutionScreen(canManage: true)
            : const DesignScreen(canManage: true),
      ),
    ));
  }

  void _openFingerprintAs(String id, String name) async {
    await Session.set(Session.fingerprintKey, EmployeeSession(id, name));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('بصمة: $name')),
        body: const FingerprintScreen(canManage: true),
      ),
    ));
  }
}
