import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../models/receipt.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/notifications_view.dart';
import '../../widgets/ui.dart';
import '../execution/receipt_detail_screen.dart';
import 'customer_overview.dart';

/// بوابة الزبون (المرحلة 4): نظرة عامة على مشاريعه (تصميم/تنفيذ) + الوصولات
/// والمدفوعات + التقارير ذات الصلة — كلها قراءة فقط ولبياناته هو فقط.
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
    'الوصولات',
    'التقارير',
    'الإشعارات',
    'الإعدادات',
  ];

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final fs = FirestoreService();
    // بناء كسول: يُبنى التبويب النشط فقط (لا تبقى مستمعات Firestore لتبويبات مخفية).
    final Widget body = switch (_index) {
      0 => CustomerOverview(
          customerUid: u.uid, customerName: u.name, viewer: u),
      1 => _CustomerReceiptsTab(customerUid: u.uid),
      2 => _CustomerReportsTab(customerUid: u.uid),
      3 => NotificationsView(stream: fs.notificationsForUser(u.uid)),
      _ => _CustomerSettingsTab(user: u),
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
              icon: Icon(Icons.receipt_long), label: 'الوصولات'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'الإشعارات'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

/// تبويب الوصولات والمدفوعات للزبون (T-4.3): إجمالي + قائمة كل وصولاته.
class _CustomerReceiptsTab extends StatelessWidget {
  final String customerUid;
  const _CustomerReceiptsTab({required this.customerUid});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<Receipt>>(
      stream: fs.receiptsByCustomer(customerUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل الوصولات.', icon: Icons.error_outline);
        }
        final receipts = snap.data ?? const <Receipt>[];
        num total = 0;
        for (final r in receipts) {
          total += r.amount;
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PageHeader(
              title: 'الوصولات والمدفوعات',
              subtitle: 'كل المبالغ المدفوعة في مشاريعك',
              icon: Icons.receipt_long,
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الإجمالي',
              icon: Icons.summarize,
              child: Column(
                children: [
                  InfoRow(label: 'عدد الوصولات', value: '${receipts.length}'),
                  InfoRow(
                      label: 'إجمالي المدفوعات',
                      value: Fmt.money(total),
                      valueColor: AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (receipts.isEmpty)
              const EmptyState(
                  message: 'لا توجد وصولات بعد.', icon: Icons.receipt_long)
            else
              ...receipts.map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long,
                          color: AppColors.success),
                      title: Text(Fmt.money(r.amount),
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${r.description.isEmpty ? 'وصل' : r.description}\n'
                        'رقم ${r.shortNo} • ${Fmt.date(r.date)}',
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.4),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_left,
                          color: AppColors.creamDim),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReceiptDetailScreen(receipt: r)),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

/// تبويب التقارير ذات الصلة للزبون (T-4.4): يجمع معرّفات مشاريع/مواقع الزبون
/// ثم يعرض التقارير المرتبطة بها فقط (لا تظهر بيانات مشاريع أخرى).
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

/// تبويب إعدادات الزبون: معلومات حسابه + تغيير رمز الدخول (٤ أرقام).
class _CustomerSettingsTab extends StatefulWidget {
  final AppUser user;
  const _CustomerSettingsTab({required this.user});

  @override
  State<_CustomerSettingsTab> createState() => _CustomerSettingsTabState();
}

class _CustomerSettingsTabState extends State<_CustomerSettingsTab> {
  final _fs = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changeCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final c = AuthService.makeCredential(widget.user.uid, _code.text.trim());
      await _fs.setUserPassword(widget.user.uid, c['salt']!, c['hash']!);
      if (mounted) {
        _code.clear();
        _confirm.clear();
        FocusScope.of(context).unfocus();
        showSnack(context, 'تم تغيير رمز الدخول ✓ — استخدمه في الدخول القادم.');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تغيير الرمز.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const PageHeader(
          title: 'الإعدادات',
          subtitle: 'حسابي ورمز الدخول',
          icon: Icons.settings,
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'معلومات الحساب',
          icon: Icons.person,
          child: Column(
            children: [
              InfoRow(label: 'الاسم', value: u.name.isEmpty ? '—' : u.name),
              InfoRow(
                  label: 'رقم الهاتف', value: u.phone.isEmpty ? '—' : u.phone),
              if (u.contact.isNotEmpty)
                InfoRow(label: 'بيانات التواصل', value: u.contact),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'تغيير رمز الدخول',
          icon: Icons.lock_reset,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('رمز جديد من 4 أرقام تدخل به في المرة القادمة.',
                    style: TextStyle(color: AppColors.creamDim, height: 1.5)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'الرمز الجديد (4 أرقام)',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length != 4 || int.tryParse(t) == null) {
                      return 'الرمز 4 أرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد الرمز',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  validator: (v) => (v ?? '').trim() != _code.text.trim()
                      ? 'الرمز غير متطابق'
                      : null,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _changeCode,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.save),
                  label: const Text('حفظ الرمز الجديد'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
