import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/notifications_view.dart';
import '../../widgets/ui.dart';
import 'customer_overview.dart';

/// بوابة الزبون: نظرة عامة على مشاريعه (تصميم/تنفيذ) + الوصولات والمدفوعات +
/// التقارير ذات الصلة + الإشعارات — كلها قراءة فقط ولبياناته هو فقط (بلا إعدادات).
class CustomerHome extends StatefulWidget {
  final AppUser user;
  const CustomerHome({super.key, required this.user});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _index = 0;

  static const _titles = [
    'صفحتي',
    'الحسابات',
    'التقارير',
    'الإشعارات',
  ];

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final fs = FirestoreService();
    // بناء كسول: يُبنى التبويب النشط فقط (لا تبقى مستمعات Firestore للمخفية).
    final Widget body = switch (_index) {
      0 => CustomerOverview(
          customerUid: u.uid, customerName: u.name, viewer: u),
      1 => _CustomerAccountsTab(customerName: u.name),
      2 => _CustomerReportsTab(customerUid: u.uid),
      _ => NotificationsView(stream: fs.notificationsForUser(u.uid)),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [LogoutAction()],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'صفحتي'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'الحسابات'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'الإشعارات'),
        ],
      ),
    );
  }
}

/// تبويب «الحسابات» للزبون: كشف حساب مبسّط مناسب للهاتف (نسخة من نظام الحسابات)
/// — يعرض حسابات هذا الزبون فقط من قاعدة المحاسبة المشتركة (مطابقة بالاسم)،
/// متضمّناً وصولات الدفع الإلكتروني. استعلام محدود بالاسم لتقليل قراءات القاعدة
/// (لا يقرأ كامل المجموعة).
class _CustomerAccountsTab extends StatelessWidget {
  final String customerName;
  const _CustomerAccountsTab({required this.customerName});

  static num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v'.replaceAll(',', '').trim()) ?? 0;
  }

  static DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse('$v');
  }

  @override
  Widget build(BuildContext context) {
    final name = customerName.trim();
    if (name.isEmpty) {
      return const EmptyState(
          message: 'لا يوجد حساب مرتبط بهذا الزبون.',
          icon: Icons.account_balance_wallet);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // استعلام محدود بحركات هذا الزبون فقط — تقليل كبير لقراءات Firestore.
      stream: Db.customerTransactions
          .where('customerName', isEqualTo: name)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل الحسابات.', icon: Icons.error_outline);
        }
        final rows = (snap.data?.docs ?? [])
            .map((d) => d.data())
            .where((m) => m['deleted'] != true)
            .toList();
        if (rows.isEmpty) {
          return const EmptyState(
              message: 'لا توجد حركات في حسابك بعد.',
              icon: Icons.account_balance_wallet);
        }
        // قاعدة «المجموع اليدوي»: إن وُجد صف مجموع يدوي يُعتمد وحده.
        final hasManual = rows.any((t) => t['isManualTotal'] == true);
        num receipt = 0, expense = 0;
        for (final t in rows) {
          if ((t['isManualTotal'] == true) != hasManual) continue;
          receipt += _num(t['receipt']);
          expense += _num(t['expense']);
        }
        final balance = receipt - expense;
        final sorted = rows.toList()
          ..sort((a, b) => (_dt(b['datetime']) ?? DateTime(2000))
              .compareTo(_dt(a['datetime']) ?? DateTime(2000)));
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PageHeader(
              title: 'حساباتي',
              subtitle: 'كشف حساب مبسّط بكل حركاتك',
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                StatTile(
                    value: Fmt.money(receipt),
                    label: 'المدفوع',
                    icon: Icons.price_check,
                    color: AppColors.success),
                StatTile(
                    value: Fmt.money(expense),
                    label: 'المصروف',
                    icon: Icons.payments,
                    color: AppColors.danger),
                StatTile(
                    value: Fmt.money(balance),
                    label: 'الرصيد',
                    icon: Icons.account_balance,
                    color:
                        balance >= 0 ? AppColors.success : AppColors.danger),
              ],
            ),
            const SizedBox(height: 14),
            const Text('الحركات',
                style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...sorted.map((t) {
              final r = _num(t['receipt']);
              final e = _num(t['expense']);
              final isReceipt = r >= e;
              final amount = isReceipt ? r : e;
              final electronic = t['source'] == 'electronic';
              final desc = '${t['description'] ?? ''}'.trim();
              final d = _dt(t['datetime']);
              final color =
                  isReceipt ? AppColors.success : AppColors.danger;
              return Card(
                child: ListTile(
                  leading: Icon(
                      isReceipt ? Icons.south_west : Icons.north_east,
                      color: color),
                  title: Text('${isReceipt ? 'قبض' : 'صرف'}: ${Fmt.money(amount)}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${desc.isEmpty ? (isReceipt ? 'دفعة' : 'صرف') : desc}'
                    '${d != null ? '\n${Fmt.date(d)}' : ''}',
                    style: const TextStyle(
                        color: AppColors.creamDim, height: 1.4),
                  ),
                  isThreeLine: d != null,
                  trailing: electronic
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.oliveBright
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('إلكتروني',
                              style: TextStyle(
                                  color: AppColors.oliveBright,
                                  fontSize: 11)),
                        )
                      : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// تبويب التقارير ذات الصلة للزبون: يعرض التقارير المرتبطة بمشاريعه فقط.
class _CustomerReportsTab extends StatelessWidget {
  final String customerUid;
  const _CustomerReportsTab({required this.customerUid});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DailyReport>>(
      stream: fs.dailyReportsByCustomer(customerUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل التقارير.', icon: Icons.error_outline);
        }
        final reports = snap.data ?? const <DailyReport>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PageHeader(
              title: 'تقارير مشاريعك',
              subtitle: 'تقارير العمل المرتبطة بمشاريعك',
              icon: Icons.event_note,
            ),
            const SizedBox(height: 12),
            if (reports.isEmpty)
              const EmptyState(
                  message: 'لا توجد تقارير مرتبطة بمشاريعك بعد.',
                  icon: Icons.event_busy)
            else
              ...reports.map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_note,
                          color: AppColors.oliveBright),
                      title: Text(
                        r.projectName.isEmpty
                            ? Fmt.date(r.date)
                            : '${r.projectName} • ${Fmt.date(r.date)}',
                        style: const TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${r.userName.isEmpty ? '' : '${r.userName}\n'}${r.content}',
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.5),
                      ),
                      isThreeLine: true,
                    ),
                  )),
          ],
        );
      },
    );
  }
}
