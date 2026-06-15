import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/project_tasks.dart';
import 'daily_report.dart';
import 'design_project_detail.dart';
import 'fingerprint_screen.dart';
import 'project_form.dart';

class DesignScreen extends StatefulWidget {
  /// صلاحية إدارية عند فتح صفحة الموظف من لوحة التحكم (تعديل/حذف المشاريع).
  final bool canManage;
  const DesignScreen({this.canManage = false, super.key});
  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  EmployeeSession? _emp;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = Session.get(Session.designKey);
    if (saved == null) {
      setState(() => _emp = null);
      return;
    }
    setState(() => _emp = saved);
    Db.applyDailyTick('design_projects', 'design_meta', saved.id)
        .catchError((_) {});
  }

  Future<void> _onLogin(EmployeeSession s) async {
    await Session.set(Session.designKey, s);
    setState(() => _emp = s);
    Db.applyDailyTick('design_projects', 'design_meta', s.id).catchError((_) {});
  }

  Future<void> _logout() async {
    await Session.clear(Session.designKey);
    setState(() => _emp = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_emp == null) {
      return EmployeeLogin(onSuccess: _onLogin);
    }
    final emp = _emp!;
    // تُحمَّل كل المشاريع وتُرشَّح حسب عضوية الفريق (تدعم البيانات القديمة).
    final stream = Db.designProjects.snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final hasError = snap.hasError;
        final loading = !snap.hasData && !hasError;
        final docs = (snap.data?.docs ?? [])
            .where((d) => projectAssignedTo(d.data(), emp.id))
            .toList()
          ..sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return mb.compareTo(ma);
          });
        final totalRemaining =
            docs.fold<int>(0, (s, d) => s + _remaining(d.data()));

        return PagePadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('موظفي التصميم',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  EmployeeBar(name: emp.name, onLogout: _logout),
                ],
              ),
              const SizedBox(height: 16),
              _countdownBanner(totalRemaining),
              const SizedBox(height: 16),
              _fingerprintLinkCard(),
              const SizedBox(height: 16),
              DailyReportCard(
                  employeeId: emp.id,
                  employeeName: emp.name,
                  kind: 'design'),
              const SizedBox(height: 16),
              const Text('مشاريع التصميم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingView(text: 'جارٍ تحميل مشاريعك…'),
                )
              else if (hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: MessageView(
                    icon: Icons.cloud_off,
                    title: 'تعذّر تحميل المشاريع',
                    subtitle: 'تأكّد من اتصال الإنترنت ثم حاول مجددًا.',
                    color: AppColors.danger,
                  ),
                )
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: MessageView(
                    icon: Icons.folder_open,
                    title: 'لا توجد مشاريع بعد',
                    subtitle:
                        'ستظهر هنا المشاريع التي يسندها إليك المدير من لوحة التحكم.',
                  ),
                )
              else
                AutoGrid(
                  minTileWidth: 300,
                  gap: 14,
                  children: [for (final d in docs) _projectCard(d)],
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  Widget _countdownBanner(int totalRemaining) {
    return Row(
      children: [
        Expanded(
          child: _bannerCard('تاريخ اليوم',
              ArDate.fullArabicDate(DateTime.now()), AppColors.green600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _bannerCard('إجمالي الأيام المتبقية', '$totalRemaining يوم',
              AppColors.green800,
              hint: 'يتناقص يومًا واحدًا تلقائيًا كل يوم'),
        ),
      ],
    );
  }

  Widget _bannerCard(String label, String value, Color bg, {String? hint}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.cream200)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint,
                style: const TextStyle(color: AppColors.cream300, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _fingerprintLinkCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // الدخول إلى البصمة بنفس هوية الموظف الحالي.
        if (_emp != null) {
          Session.set(Session.fingerprintKey, _emp!);
        }
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('نظام البصمة')),
            body: const FingerprintScreen(),
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          children: [
            Text('🔒', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نظام البصمة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('تسجيل الحضور والانصراف ومتابعة ساعات العمل',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_back),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = (data['status'] ?? 'قيد التنفيذ').toString();
    final suspended = status.contains('معلّق') || status.contains('معلق');
    final remaining = _remaining(data);
    final done = remaining == 0;
    final owner = (data['ownerName'] ?? '').toString();
    final currency = (data['currency'] ?? 'IQD').toString();
    final total = _amount(data['totalAmount']);
    final received = _amount(data['receivedAmount'] ?? data['paidAmount']);
    final due = (total - received) < 0 ? 0 : total - received;
    final tasks = (data['tasks'] as List?) ?? [];
    final pct = taskProgressPercent(tasks);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetail(doc),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? AppColors.cream100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(data['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                StatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            if (tasks.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.cream200,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.green600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$pct٪',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
                suspended
                    ? '⏸️ معلّق — الأيام مجمّدة'
                    : (done ? 'مكتمل' : '$remaining يوم متبقٍ'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: suspended
                        ? const Color(0xFF9A6700)
                        : AppColors.textSoft)),
            const SizedBox(height: 8),
            // اسم صاحب المشروع — قابل للضغط لفتح صفحة التفاصيل.
            InkWell(
              onTap: () => _openDetail(doc),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.green700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(owner.isEmpty ? 'بدون صاحب مشروع' : owner,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.green700)),
                    ),
                    const Icon(Icons.chevron_left,
                        size: 18, color: AppColors.green700),
                  ],
                ),
              ),
            ),
            if ((data['details'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(data['details'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSoft)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('المتبقّي: ${moneyLabel(due, currency)}',
                    color: due > 0 ? AppColors.dangerSoft : AppColors.green100),
                _chip('العرض: ${(data['offerType'] ?? '—').toString()}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _amount(dynamic v) =>
      (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  Widget _chip(String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color ?? AppColors.cream100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  void _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DesignProjectDetailScreen(
        employee: _emp!,
        reference: doc.reference,
        canManage: widget.canManage,
      ),
    ));
  }
}

// تمّ نقل نموذج إضافة/تعديل مشروع التصميم إلى DesignProjectForm في
// design_project_detail.dart (مع الحقول المالية والملفات وصفحة التفاصيل).
