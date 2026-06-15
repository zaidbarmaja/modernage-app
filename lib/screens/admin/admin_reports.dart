import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/daily_report.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';

/// لوحة الإدارة: عرض كل التقارير اليومية مع تصفية حسب الموظف/المشروع/التاريخ.
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final _fs = FirestoreService();
  String? _uidFilter; // فلتر الموظف (uid) أو null = الكل
  String? _projectFilter; // فلتر معرّف المشروع/الموقع (projectId) أو null = الكل
  DateTime? _dateFilter; // فلتر يوم محدّد أو null = الكل

  bool _matches(DailyReport r) {
    if (_uidFilter != null && r.uid != _uidFilter) return false;
    if (_projectFilter != null && r.projectId != _projectFilter) return false;
    if (_dateFilter != null &&
        r.dayKey != DailyReport.dayKeyOf(_dateFilter!)) {
      return false;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailyReport>>(
      stream: _fs.allDailyReports(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final all = snap.data ?? const <DailyReport>[];

        // خيارات الموظفين (uid → اسم) والمشاريع (projectId → اسم العرض) من التقارير.
        final employees = <String, String>{};
        final projects = <String, String>{};
        for (final r in all) {
          if (r.uid.isNotEmpty) employees[r.uid] = r.userName;
          final pid = r.projectId;
          if (pid != null && pid.isNotEmpty) {
            projects[pid] = r.projectName.isNotEmpty ? r.projectName : pid;
          }
        }
        // إن اختفى الفلتر المحدّد من البيانات نُعيد ضبطه.
        if (_uidFilter != null && !employees.containsKey(_uidFilter)) {
          _uidFilter = null;
        }
        if (_projectFilter != null && !projects.containsKey(_projectFilter)) {
          _projectFilter = null;
        }

        final filtered = all.where(_matches).toList();

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PageHeader(
              title: 'التقارير اليومية',
              subtitle: 'عرض وتصفية تقارير كل الموظفين',
              icon: Icons.event_note,
            ),
            const SizedBox(height: 12),
            _filtersCard(employees, projects),
            const SizedBox(height: 12),
            Text(
              'عدد التقارير: ${filtered.length}'
              '${filtered.length != all.length ? ' من ${all.length}' : ''}',
              style: const TextStyle(
                  color: AppColors.creamDim, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const EmptyState(
                  message: 'لا توجد تقارير مطابقة.', icon: Icons.event_busy)
            else
              ...filtered.map(_reportTile),
          ],
        );
      },
    );
  }

  Widget _filtersCard(Map<String, String> employees, Map<String, String> projects) {
    final projectEntries = projects.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final empEntries = employees.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final hasFilter =
        _uidFilter != null || _projectFilter != null || _dateFilter != null;

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
              ...empEntries.map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value.isEmpty ? 'موظف' : e.value,
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _uidFilter = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _projectFilter,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            decoration: const InputDecoration(
              labelText: 'المشروع/الموقع',
              prefixIcon: Icon(Icons.link),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('كل المشاريع')),
              ...projectEntries.map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _projectFilter = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _dateFilter == null
                        ? 'كل التواريخ'
                        : Fmt.date(_dateFilter),
                  ),
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
          if (hasFilter) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _uidFilter = null;
                  _projectFilter = null;
                  _dateFilter = null;
                }),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('مسح كل الفلاتر'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportTile(DailyReport r) {
    return Card(
      child: ExpansionTile(
        leading:
            const Icon(Icons.event_note, color: AppColors.oliveBright),
        title: Text(
          r.userName.isEmpty ? 'موظف' : r.userName,
          style: const TextStyle(
              color: AppColors.cream, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${Fmt.date(r.date)}'
          '${r.projectName.isNotEmpty ? ' • 🔗 ${r.projectName}' : ''}',
          style: const TextStyle(color: AppColors.creamDim, fontSize: 12),
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.content,
              style: const TextStyle(color: AppColors.cream, height: 1.6)),
        ],
      ),
    );
  }
}
