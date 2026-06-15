import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/project_photos.dart';
import '../widgets/project_tasks.dart';
import 'project_attendance.dart';
import 'project_form.dart';
import 'receipt.dart';

int _remainingOf(Map<String, dynamic> d) {
  final v = d['remainingDays'] ?? d['days'] ?? 0;
  final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  return n < 0 ? 0 : n;
}

/// صفحة تفاصيل مشروع تنفيذ: نسبة الإنجاز + المهام/الملاحظات + الحالة + التفاصيل.
class ExecutionProjectDetailScreen extends StatelessWidget {
  final EmployeeSession employee;
  final DocumentReference<Map<String, dynamic>> reference;
  final bool canManage;
  const ExecutionProjectDetailScreen({
    required this.employee,
    required this.reference,
    this.canManage = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل مشروع التنفيذ')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const MessageView(
                icon: Icons.cloud_off,
                title: 'تعذّر تحميل التفاصيل',
                color: AppColors.danger);
          }
          if (!snap.hasData) return const LoadingView();
          final doc = snap.data!;
          if (!doc.exists) {
            return const MessageView(
                icon: Icons.delete_outline, title: 'تم حذف هذا المشروع');
          }
          final d = doc.data()!;
          final status = (d['status'] ?? 'قيد التنفيذ').toString();
          final suspended = status.contains('معلّق') || status.contains('معلق');
          final remaining = _remainingOf(d);
          final done = remaining == 0;
          final tasks = (d['tasks'] as List?) ?? [];
          final currency = (d['currency'] ?? 'IQD').toString();
          final total =
              (d['totalAmount'] is num) ? (d['totalAmount'] as num).toInt() : 0;
          final received = (d['receivedAmount'] is num)
              ? (d['receivedAmount'] as num).toInt()
              : 0;
          // المتبقّي قد يكون بالسالب (مثلاً إذا كان كامل المبلغ صفرًا).
          final due = total - received;
          final documents = (d['documents'] as List?) ?? [];
          final photos = (d['photos'] as List?) ?? [];
          final expenses = (d['expenses'] as List?) ?? [];
          final totalExp = expenses.fold<int>(0, (s, e) {
            final a = (e is Map) ? e['amount'] : 0;
            return s + ((a is num) ? a.toInt() : 0);
          });

          return PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== رأس =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['name'] ?? '—').toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('صاحب المشروع: ${(d['ownerName'] ?? '—')}',
                          style: const TextStyle(color: AppColors.cream200)),
                      if ((d['ownerPhone'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.phone,
                              size: 14, color: AppColors.cream300),
                          const SizedBox(width: 6),
                          Text('${d['ownerPhone']}',
                              style:
                                  const TextStyle(color: AppColors.cream200)),
                        ]),
                      ],
                      if ((d['location'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('الموقع: ${d['location']}',
                            style: const TextStyle(color: AppColors.cream200)),
                      ],
                      if (assignedNamesLabel(d).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.groups_outlined,
                              size: 14, color: AppColors.cream300),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('الفريق: ${assignedNamesLabel(d)}',
                                style: const TextStyle(
                                    color: AppColors.cream200)),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        StatusBadge(status),
                        _tag(suspended
                            ? 'الأيام مجمّدة'
                            : (done ? 'مكتمل' : '$remaining يوم متبقٍ')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ===== بصمة الحضور من داخل الموقع (للموظف فقط) =====
                if (!canManage && employee.id.isNotEmpty) ...[
                  ProjectAttendanceCard(
                    employee: employee,
                    projectId: reference.id,
                    projectName:
                        (d['location'] ?? d['ownerName'] ?? 'المشروع').toString(),
                    lat: (d['lat'] is num) ? (d['lat'] as num).toDouble() : null,
                    lng: (d['lng'] is num) ? (d['lng'] as num).toDouble() : null,
                    radius:
                        (d['radius'] is num) ? (d['radius'] as num).toInt() : 200,
                  ),
                  const SizedBox(height: 18),
                ],

                // ===== المهام ونسبة الإنجاز =====
                const SectionHeader('المهام ونسبة الإنجاز'),
                _card([
                  ProjectTasks(
                      reference: reference, tasks: tasks, showDays: true),
                ]),
                const SizedBox(height: 18),

                // ===== الحالة =====
                const SectionHeader('حالة المشروع'),
                _card([
                  StatusSelector(
                    current: status,
                    onChanged: (s) => reference.update({'status': s}),
                  ),
                  if (suspended) ...[
                    const SizedBox(height: 8),
                    const Text('⏸️ المشروع معلّق — توقف احتساب الأيام المتبقية.',
                        style: TextStyle(
                            color: Color(0xFF9A6700),
                            fontWeight: FontWeight.w700)),
                  ],
                ]),
                const SizedBox(height: 18),

                // ===== التفاصيل =====
                const SectionHeader('تفاصيل المشروع'),
                _card([
                  if ((d['details'] ?? '').toString().isNotEmpty)
                    _kv('التفاصيل', d['details'].toString()),
                  if ((d['futurePlan'] ?? '').toString().isNotEmpty)
                    _kv('خطة الأيام القادمة', d['futurePlan'].toString()),
                  if ((d['notes'] ?? '').toString().isNotEmpty)
                    _kv('ملاحظات', d['notes'].toString()),
                  _kv('إجمالي المصروف', '${arNumber(totalExp)} د.ع'),
                ]),
                const SizedBox(height: 18),

                // ===== ميزانية المشروع =====
                SectionHeader('ميزانية المشروع · ${currencyName(currency)}'),
                _card([
                  _budgetRow('كامل المبلغ', moneyLabel(total, currency)),
                  _budgetRow('المصروفات', moneyLabel(received, currency)),
                  const Divider(),
                  _budgetRow('المتبقّي', moneyLabel(due, currency),
                      highlight: true),
                ]),
                const SizedBox(height: 18),

                // ===== الوصولات الإلكترونية =====
                const SectionHeader('الوصولات الإلكترونية'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => receiptDialog(
                      context,
                      projectId: reference.id,
                      projectCollection: reference.parent.id,
                      employeeId: employee.id,
                      employeeName: employee.name,
                      ownerName: (d['ownerName'] ?? '').toString(),
                      ownerPhone: (d['ownerPhone'] ?? '').toString(),
                      currency: currency,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('إضافة وصل إلكتروني'),
                  ),
                ),
                const SizedBox(height: 10),
                ReceiptsList(
                  projectId: reference.id,
                  projectCollection: reference.parent.id,
                  projectName: (d['name'] ?? '').toString(),
                  canManage: canManage,
                ),
                const SizedBox(height: 18),

                // ===== صور المشروع (يستطيع الموظف إرفاق صور) =====
                const SectionHeader('صور المشروع'),
                _card([
                  ProjectPhotos(
                    reference: reference,
                    photos: photos,
                    collection: 'execution_projects',
                    canManage: canManage,
                  ),
                ]),
                const SizedBox(height: 18),

                // ===== المستندات =====
                if (documents.isNotEmpty) ...[
                  const SectionHeader('المستندات'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in documents)
                        Chip(
                            avatar: const Text('📄'),
                            label: Text('${(f as Map)['name'] ?? 'مستند'}'),
                            backgroundColor: AppColors.cream100),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],

                // ===== أزرار الإدارة =====
                if (canManage)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openEdit(context, doc),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('تعديل المشروع'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                content:
                                    const Text('حذف هذا المشروع نهائيًا؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('حذف',
                                          style: TextStyle(
                                              color: AppColors.danger))),
                                ],
                              ),
                            ),
                          );
                          if (ok == true) {
                            await reference.delete();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        label: const Text('حذف'),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEdit(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) {
    showProjectForm(context, kind: 'execution', existing: doc);
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.green600,
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _budgetRow(String k, String v, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color: highlight ? AppColors.green900 : AppColors.textSoft,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w500)),
            Text(v,
                style: TextStyle(
                    fontSize: highlight ? 18 : 15,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppColors.green700 : AppColors.text)),
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(v),
          ],
        ),
      );
}
