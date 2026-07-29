import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import 'design_project_form.dart';

/// شاشة تفاصيل مشروع التصميم (T-2.2): عرض كامل للمتطلبات + الحالة + المالية
/// + قائمة المهام الحالية. تتحدّث لحظياً عبر Stream على مستند المشروع.
class DesignProjectDetail extends StatelessWidget {
  final String projectId;

  /// المصمم لفتح نموذج التعديل (فارغ = إدارة، فيظهر منتقي المصمم).
  final AppUser? editor;

  /// هل يملك المشاهد صلاحية التعديل؟ (الزبون = false).
  final bool canEdit;

  /// اسم كاتب الملاحظات (المستخدم الحالي).
  final String authorName;

  const DesignProjectDetail({
    super.key,
    required this.projectId,
    this.editor,
    this.canEdit = true,
    this.authorName = '',
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'منجز':
        return AppColors.success;
      case 'معلّق':
        return AppColors.warning;
      default:
        return AppColors.oliveBright;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشروع')),
      body: StreamBuilder<DesignProject?>(
        stream: fs.projectStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final p = snap.data;
          if (p == null) {
            return const EmptyState(
                message: 'تم حذف هذا المشروع.', icon: Icons.delete_outline);
          }
          final remDays = p.remainingDays;
          return ListView(
            // حافة سفلية تراعي شريط تنقّل النظام كي لا يختفي زرّ «تعديل المشروع».
            padding: EdgeInsets.fromLTRB(
                14, 14, 14, 14 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              PageHeader(
                title: p.ownerName.isEmpty ? 'مشروع تصميم' : p.ownerName,
                subtitle: p.designerName.isEmpty
                    ? 'مشروع تصميم'
                    : 'المصمّم: ${p.designerName}',
                icon: Icons.architecture,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _badge(p.status, _statusColor(p.status)),
                if (p.offerType.isNotEmpty)
                  _badge(p.offerType, AppColors.oliveBright),
                if (remDays != null)
                  _badge(
                    remDays < 0 ? 'متأخر ${-remDays} يوم' : '$remDays يوم متبقٍ',
                    remDays < 0
                        ? AppColors.danger
                        : (remDays <= 3
                            ? AppColors.warning
                            : AppColors.success),
                  ),
              ]),
              const SizedBox(height: 14),

              // المتطلبات / الملاحظات
              SectionCard(
                title: 'المتطلبات والملاحظات',
                icon: Icons.sticky_note_2_outlined,
                child: Text(
                  p.details.isEmpty ? 'لا توجد تفاصيل.' : p.details,
                  style: const TextStyle(color: AppColors.cream, height: 1.6),
                ),
              ),
              const SizedBox(height: 12),

              // العرض الموالي للزبون
              if (p.nextPresentation.isNotEmpty) ...[
                SectionCard(
                  title: 'العرض الموالي للزبون',
                  icon: Icons.upcoming_outlined,
                  child: Text(p.nextPresentation,
                      style: const TextStyle(
                          color: AppColors.cream, height: 1.6)),
                ),
                const SizedBox(height: 12),
              ],

              // القسم المالي
              SectionCard(
                title: 'القسم المالي',
                icon: Icons.account_balance_wallet,
                child: Column(
                  children: [
                    InfoRow(
                        label: 'المبلغ الكلي',
                        value: Fmt.money(p.totalAmount)),
                    InfoRow(
                        label: 'المدفوع',
                        value: Fmt.money(p.paidAmount),
                        valueColor: AppColors.success),
                    InfoRow(
                        label: 'المتبقي',
                        value: Fmt.money(p.remainingAmount),
                        valueColor: AppColors.warning),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // المهام الحالية (يضيفها/يبدّلها المصمم)
              SectionCard(
                title: 'المهام (${p.doneTasksCount}/${p.tasks.length})'
                    '${p.totalTaskDays > 0 ? ' • ${p.totalTaskDays} يوم' : ''}',
                icon: Icons.checklist,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('لا توجد مهام بعد.',
                            style: TextStyle(color: AppColors.creamDim)),
                      )
                    else ...[
                      _timeline(p),
                      for (var i = 0; i < p.tasks.length; i++)
                        _taskTile(context, p, i),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _addTask(context, p),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة مهمة'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // الملاحظات الحرة (سجلّ بختم زمني واسم الكاتب)
              SectionCard(
                title: 'الملاحظات (${p.notes.length})',
                icon: Icons.forum_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.notes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('لا توجد ملاحظات.',
                            style: TextStyle(color: AppColors.creamDim)),
                      )
                    else
                      for (final n in p.notes.reversed) _noteTile(n),
                    if (canEdit) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _addNote(context, p),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: const Text('إضافة ملاحظة'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (canEdit)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DesignProjectForm(designer: editor, existing: p),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('تعديل المشروع'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _taskTile(BuildContext context, DesignProject p, int i) {
    final t = p.tasks[i];
    final (remText, remColor) = _taskRemaining(p, i);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: t.done ? 'إرجاع لقيد العمل' : 'تعليم كمنجزة',
        icon: Icon(
          t.done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: t.done ? AppColors.success : AppColors.creamDim,
        ),
        onPressed: canEdit ? () => _toggleTask(p, i) : null,
      ),
      title: Text(
        t.title,
        style: TextStyle(
          color: AppColors.cream,
          decoration: t.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text('المدة: ${t.days} يوم',
              style: const TextStyle(color: AppColors.creamDim, fontSize: 12)),
          if (remText.isNotEmpty) ...[
            const Text('  •  ',
                style: TextStyle(color: AppColors.creamDim, fontSize: 12)),
            Text(remText,
                style: TextStyle(
                    color: remColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.creamDim, size: 19),
                  onPressed: () => _editTask(context, p, i),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.creamDim, size: 19),
                  onPressed: () => _deleteTask(context, p, i),
                ),
              ],
            )
          : null,
    );
  }

  /// المدة المتبقّية للمهمة محسوبةً من تاريخ بدء المشروع + تسلسل أيام المهام
  /// (المهام متتابعة). تعيد نصّاً ولوناً للعرض.
  (String, Color) _taskRemaining(DesignProject p, int i) {
    final t = p.tasks[i];
    if (t.done) return ('✓ منجزة', AppColors.success);
    if (p.createdAt == null) return ('', AppColors.creamDim);
    var cumulative = 0;
    for (var k = 0; k <= i; k++) {
      cumulative += p.tasks[k].days;
    }
    final start =
        DateTime(p.createdAt!.year, p.createdAt!.month, p.createdAt!.day);
    final due = start.add(Duration(days: cumulative));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final remaining = due.difference(today).inDays;
    if (remaining < 0) {
      return ('متأخّرة ${-remaining} يوم', AppColors.danger);
    }
    if (remaining == 0) return ('تنتهي اليوم', AppColors.warning);
    if (remaining <= 3) return ('متبقّي $remaining يوم', AppColors.warning);
    return ('متبقّي $remaining يوم', AppColors.oliveBright);
  }

  Future<void> _editTask(BuildContext context, DesignProject p, int i) async {
    final t = p.tasks[i];
    final titleC = TextEditingController(text: t.title);
    final daysC = TextEditingController(text: '${t.days}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true, // يمنع اقتصاص المحتوى مع الكيبورد على الشاشات الصغيرة
        backgroundColor: AppColors.surface,
        title:
            const Text('تعديل المهمة', style: TextStyle(color: AppColors.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              autofocus: true,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(labelText: 'عنوان المهمة'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysC,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(labelText: 'عدد الأيام'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && titleC.text.trim().isNotEmpty) {
      final tasks = [...p.tasks];
      tasks[i] = t.copyWith(
        title: titleC.text.trim(),
        days: int.tryParse(daysC.text.trim()) ?? 0,
      );
      await FirestoreService().updateProjectTasks(p.id, tasks);
    }
    titleC.dispose();
    daysC.dispose();
  }

  Future<void> _toggleTask(DesignProject p, int i) async {
    final tasks = [...p.tasks];
    tasks[i] = tasks[i].copyWith(done: !tasks[i].done);
    await FirestoreService().updateProjectTasks(p.id, tasks);
  }

  Future<void> _deleteTask(BuildContext context, DesignProject p, int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true, // يمنع اقتصاص المحتوى مع الكيبورد على الشاشات الصغيرة
        backgroundColor: AppColors.surface,
        content: Text('حذف المهمة «${p.tasks[i].title}»؟',
            style: const TextStyle(color: AppColors.cream)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      final tasks = [...p.tasks]..removeAt(i);
      await FirestoreService().updateProjectTasks(p.id, tasks);
    }
  }

  Future<void> _addTask(BuildContext context, DesignProject p) async {
    final titleC = TextEditingController();
    final daysC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true, // يمنع اقتصاص المحتوى مع الكيبورد على الشاشات الصغيرة
        backgroundColor: AppColors.surface,
        title:
            const Text('إضافة مهمة', style: TextStyle(color: AppColors.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              autofocus: true,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(
                labelText: 'عنوان المهمة',
                hintText: 'مثال: تصميم البوست الأول',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysC,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(labelText: 'عدد الأيام'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة')),
        ],
      ),
    );
    if (ok == true && titleC.text.trim().isNotEmpty) {
      final task = ProjectTask(
        title: titleC.text.trim(),
        days: int.tryParse(daysC.text.trim()) ?? 0,
      );
      await FirestoreService().updateProjectTasks(p.id, [...p.tasks, task]);
    }
    titleC.dispose();
    daysC.dispose();
  }

  /// شريط الجدول الزمني التلقائي: المدة الإجمالية + نسبة الأيام المنجزة.
  Widget _timeline(DesignProject p) {
    final ratio =
        p.totalTaskDays == 0 ? 0.0 : p.doneTaskDays / p.totalTaskDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المدة الإجمالية: ${p.totalTaskDays} يوم',
                  style: const TextStyle(
                      color: AppColors.cream, fontWeight: FontWeight.bold)),
              Text('${p.doneTaskDays}/${p.totalTaskDays} يوم منجز',
                  style:
                      const TextStyle(color: AppColors.creamDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المتبقّي: ${p.totalTaskDays - p.doneTaskDays} يوم عمل  '
            '(${(ratio * 100).round()}% مكتمل)',
            style: const TextStyle(color: AppColors.oliveBright, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _noteTile(ProjectNote n) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.text,
                style: const TextStyle(color: AppColors.cream, height: 1.5)),
            const SizedBox(height: 4),
            Text(
              '${n.author.isEmpty ? 'مستخدم' : n.author} • ${Fmt.dateTime(n.createdAt)}',
              style: const TextStyle(color: AppColors.creamDim, fontSize: 11),
            ),
          ],
        ),
      );

  Future<void> _addNote(BuildContext context, DesignProject p) async {
    final textC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true, // يمنع اقتصاص المحتوى مع الكيبورد على الشاشات الصغيرة
        backgroundColor: AppColors.surface,
        title: const Text('إضافة ملاحظة',
            style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: textC,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(hintText: 'اكتب ملاحظتك…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة')),
        ],
      ),
    );
    if (ok == true && textC.text.trim().isNotEmpty) {
      final note = ProjectNote(
        text: textC.text.trim(),
        author: authorName.isEmpty ? 'مستخدم' : authorName,
        createdAt: DateTime.now(),
      );
      await FirestoreService().updateProjectNotes(p.id, [...p.notes, note]);
    }
    textC.dispose();
  }

  Widget _badge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: TextStyle(color: c, fontSize: 12.5)),
      );
}
