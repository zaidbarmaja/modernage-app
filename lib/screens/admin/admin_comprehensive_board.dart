import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../../models/design_project.dart';
import '../../models/receipt.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import 'admin_reports.dart';

enum _Section { reports, attendance, finance }

/// لوحة التقارير الشاملة (T-4.6): تجمع التقارير + الحضور + المالية في مكان
/// واحد مرتّب وقابل للفلترة، عبر مبدّل علوي.
class AdminComprehensiveBoard extends StatefulWidget {
  const AdminComprehensiveBoard({super.key});

  @override
  State<AdminComprehensiveBoard> createState() =>
      _AdminComprehensiveBoardState();
}

class _AdminComprehensiveBoardState extends State<AdminComprehensiveBoard> {
  _Section _section = _Section.reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: SegmentedButton<_Section>(
            segments: const [
              ButtonSegment(
                  value: _Section.reports,
                  label: Text('التقارير'),
                  icon: Icon(Icons.event_note)),
              ButtonSegment(
                  value: _Section.attendance,
                  label: Text('الحضور'),
                  icon: Icon(Icons.fingerprint)),
              ButtonSegment(
                  value: _Section.finance,
                  label: Text('المالية'),
                  icon: Icon(Icons.account_balance_wallet)),
            ],
            selected: {_section},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _section = s.first),
          ),
        ),
        Expanded(
          child: switch (_section) {
            _Section.reports => const AdminReportsView(),
            _Section.attendance => const _AttendanceBoard(),
            _Section.finance => const _FinanceBoard(),
          },
        ),
      ],
    );
  }
}

/// ===================== الحضور =====================
class _AttendanceBoard extends StatefulWidget {
  const _AttendanceBoard();

  @override
  State<_AttendanceBoard> createState() => _AttendanceBoardState();
}

class _AttendanceBoardState extends State<_AttendanceBoard> {
  final _fs = FirestoreService();
  String? _uidFilter; // null = كل الموظفين
  DateTime? _dateFilter; // null = كل التواريخ

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _dateFilter = picked);
  }

  bool _matches(AttendanceRecord r) {
    if (_uidFilter != null && r.uid != _uidFilter) return false;
    if (_dateFilter != null &&
        r.dayKey != AttendanceRecord.dayKeyOf(_dateFilter!)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _fs.allAttendance(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل سجلات الحضور.',
              icon: Icons.error_outline);
        }
        final all = snap.data ?? const <AttendanceRecord>[];
        final employees = <String, String>{};
        for (final r in all) {
          if (r.uid.isNotEmpty) employees[r.uid] = r.userName;
        }
        if (_uidFilter != null && !employees.containsKey(_uidFilter)) {
          _uidFilter = null;
        }
        final filtered = all.where(_matches).toList();
        final summary = AttendanceSummary.fromRecords(filtered);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _filters(employees),
            const SizedBox(height: 12),
            SectionCard(
              title: 'ملخّص الحضور',
              icon: Icons.insights,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  StatTile(
                      value: '${summary.workDays}',
                      label: 'أيام مكتملة',
                      icon: Icons.event_available),
                  StatTile(
                      value: Fmt.hours(summary.totalWorkedMinutes),
                      label: 'إجمالي ساعات العمل',
                      icon: Icons.timelapse),
                  StatTile(
                      value: Fmt.hours(summary.totalOvertimeMinutes),
                      label: 'الساعات الإضافية',
                      icon: Icons.add_alarm,
                      color: AppColors.success),
                  StatTile(
                      value: Fmt.hours(summary.totalChangeMinutes),
                      label: 'التأخير/الانصراف المبكر',
                      icon: Icons.swap_vert,
                      color: AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('عدد السجلات: ${filtered.length}',
                style: const TextStyle(
                    color: AppColors.creamDim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const EmptyState(
                  message: 'لا توجد سجلات حضور مطابقة.', icon: Icons.event_busy)
            else
              ...filtered.map(_tile),
          ],
        );
      },
    );
  }

  Widget _filters(Map<String, String> employees) {
    final entries = employees.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return SectionCard(
      title: 'التصفية',
      icon: Icons.filter_list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _uidFilter,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            decoration: const InputDecoration(
              labelText: 'الموظف',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('كل الموظفين')),
              ...entries.map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value.isEmpty ? 'موظف' : e.value,
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _uidFilter = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                      _dateFilter == null ? 'كل التواريخ' : Fmt.date(_dateFilter)),
                ),
              ),
              if (_dateFilter != null)
                IconButton(
                  tooltip: 'إلغاء فلتر التاريخ',
                  onPressed: () => setState(() => _dateFilter = null),
                  icon: const Icon(Icons.close, color: AppColors.creamDim),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(AttendanceRecord r) => Card(
        child: ListTile(
          leading: const Icon(Icons.fingerprint, color: AppColors.oliveBright),
          title: Text(
            '${r.userName.isEmpty ? 'موظف' : r.userName} • ${Fmt.date(r.checkIn)}',
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'دخول ${Fmt.time(r.checkIn)}  •  خروج ${r.checkOut == null ? '—' : Fmt.time(r.checkOut)}'
            '${r.checkOut != null ? '\nعمل: ${Fmt.duration(r.workedMinutes)}  •  إضافي: ${Fmt.duration(r.overtimeMinutes)}' : ''}',
            style: const TextStyle(color: AppColors.creamDim, height: 1.5),
          ),
          isThreeLine: r.checkOut != null,
        ),
      );
}

/// ===================== المالية =====================
class _FinanceBoard extends StatefulWidget {
  const _FinanceBoard();

  @override
  State<_FinanceBoard> createState() => _FinanceBoardState();
}

class _FinanceBoardState extends State<_FinanceBoard> {
  DateTime? _from;
  DateTime? _to;

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => from ? _from = picked : _to = picked);
    }
  }

  bool _inRange(DateTime d) {
    if (_from != null &&
        d.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) {
      return false;
    }
    if (_to != null &&
        d.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  static String _fmtD(DateTime? d) => d == null
      ? 'الكل'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final filtered = _from != null || _to != null;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const PageHeader(
          title: 'الملخّص المالي الشامل',
          subtitle: 'عقود المشاريع + المدفوعات',
          icon: Icons.account_balance_wallet,
        ),
        const SizedBox(height: 12),
        // ---- عقود التصميم (إجمالي عام) ----
        StreamBuilder<List<DesignProject>>(
          stream: fs.allProjects(),
          builder: (context, snap) {
            final projects = snap.data ?? const <DesignProject>[];
            num total = 0, paid = 0, remaining = 0;
            var active = 0;
            for (final p in projects) {
              total += p.totalAmount;
              paid += p.paidAmount;
              remaining += p.remainingAmount; // مقصور على ≥0 لكل مشروع
              if (p.remainingAmount > 0) active++;
            }
            return SectionCard(
              title: 'عقود المشاريع',
              icon: Icons.summarize,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  StatTile(
                      value: '$active',
                      label: 'مشاريع نشطة',
                      icon: Icons.pending_actions,
                      color: AppColors.warning),
                  StatTile(
                      value: Fmt.money(total),
                      label: 'إجمالي العقود',
                      icon: Icons.summarize),
                  StatTile(
                      value: Fmt.money(paid),
                      label: 'المحصّل',
                      icon: Icons.price_check,
                      color: AppColors.success),
                  StatTile(
                      value: Fmt.money(remaining),
                      label: 'المتبقي',
                      icon: Icons.account_balance,
                      color: AppColors.warning),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // ---- فلترة المدفوعات بالتاريخ ----
        SectionCard(
          title: 'فلترة المدفوعات بالتاريخ',
          icon: Icons.filter_alt,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.event, size: 18),
                  label: Text('من: ${_fmtD(_from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event, size: 18),
                  label: Text('إلى: ${_fmtD(_to)}'),
                ),
              ),
              if (filtered)
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.creamDim),
                  tooltip: 'مسح الفلتر',
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ---- المدفوعات (الوصولات) — مفلترة بالتاريخ ----
        StreamBuilder<List<Receipt>>(
          stream: fs.allReceipts(),
          builder: (context, snap) {
            final all = snap.data ?? const <Receipt>[];
            final receipts = all.where((r) => _inRange(r.date)).toList();
            num total = 0;
            for (final r in receipts) {
              total += r.amount;
            }
            return SectionCard(
              title: 'المدفوعات (الوصولات الإلكترونية)',
              icon: Icons.receipt_long,
              child: Column(
                children: [
                  InfoRow(
                      label: 'عدد الوصولات',
                      value: '${receipts.length}${filtered ? ' (مفلتر)' : ''}'),
                  InfoRow(
                      label: 'إجمالي المدفوعات',
                      value: Fmt.money(total),
                      valueColor: AppColors.success),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
