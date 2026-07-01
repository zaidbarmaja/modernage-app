import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/firebase_service.dart';
import '../../utils/time_utils.dart';
import '../../widgets/period_filter.dart';
import '../../widgets/ui.dart';

/// صفحة «الحسابات» المستقلّة (تُفتح من الإعدادات): قائمة الزبائن الحاليين
/// وأرصدتهم من قاعدة بيانات المحاسبة المشتركة.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن والحسابات')),
      body: const CustomerAccountsView(),
    );
  }
}

/// عرض حسابات الزبائن (بدون Scaffold) — اسم كل زبون، كم دفع (المستلَم)، ورصيده
/// (المستلَم − المصروف) مع قاعدة «المجموع اليدوي»، مع اختيار الفترة: كل الفترات
/// أو هذا الشهر أو شهر محدّد. البيانات من customers و customerTransactions.
class CustomerAccountsView extends StatefulWidget {
  const CustomerAccountsView({super.key});

  @override
  State<CustomerAccountsView> createState() => _CustomerAccountsViewState();
}

class _CustomerAccountsViewState extends State<CustomerAccountsView> {
  String _search = '';
  String? _month; // null = كل الفترات، وإلا 'YYYY-MM'

  // حركات الحسابات تُقرأ **مرّة واحدة** (get) وتُخزَّن — بدل بثّ حيّ يعيد قراءة
  // كل الحركات (قد تكون بالآلاف) عند كل تغيير — لتقليل تكلفة Firestore. زر
  // «تحديث» يعيد الجلب عند الحاجة.
  List<Map<String, dynamic>>? _txs;
  Object? _txErr;
  bool _loadingTx = true;

  @override
  void initState() {
    super.initState();
    _loadTxs();
  }

  Future<void> _loadTxs() async {
    setState(() {
      _loadingTx = true;
      _txErr = null;
    });
    try {
      final snap = await Db.customerTransactions.get();
      if (!mounted) return;
      setState(() {
        _txs = snap.docs
            .map((d) => d.data())
            .where((m) => m['deleted'] != true)
            .toList();
        _loadingTx = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _txErr = e;
        _loadingTx = false;
      });
    }
  }

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.customers.snapshots(),
      builder: (context, custSnap) {
        if (custSnap.hasError || _txErr != null) {
          return const EmptyState(
              message: 'تعذّر تحميل الحسابات.', icon: Icons.error_outline);
        }
        if (!custSnap.hasData || _loadingTx) return const LoadingView();

        {
          {
            final allTxs = _txs ?? const <Map<String, dynamic>>[];

            // تطبيق فلتر الفترة المختارة.
            final txs = allTxs
                .where((t) => PeriodFilter.inMonth(_dt(t['datetime']), _month))
                .toList();

            // قاعدة «المجموع اليدوي».
            final manual = <String>{};
            for (final t in txs) {
              if (t['isManualTotal'] == true) {
                manual.add(_norm('${t['customerName'] ?? ''}'));
              }
            }
            final receiptByName = <String, num>{};
            final expenseByName = <String, num>{};
            for (final t in txs) {
              final name = _norm('${t['customerName'] ?? ''}');
              if (name.isEmpty) continue;
              if (manual.contains(name) != (t['isManualTotal'] == true)) {
                continue;
              }
              receiptByName[name] =
                  (receiptByName[name] ?? 0) + _num(t['receipt']);
              expenseByName[name] =
                  (expenseByName[name] ?? 0) + _num(t['expense']);
            }

            num totalBudget = 0;
            for (final c in custSnap.data!.docs) {
              final key = _norm('${c.data()['name'] ?? ''}');
              totalBudget +=
                  (receiptByName[key] ?? 0) - (expenseByName[key] ?? 0);
            }

            var customers = custSnap.data!.docs.map((d) {
              final name = '${d.data()['name'] ?? ''}'.trim();
              final key = _norm(name);
              return _Account(
                name: name,
                receipt: receiptByName[key] ?? 0,
                expense: expenseByName[key] ?? 0,
              );
            }).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            final q = _search.trim();
            if (q.isNotEmpty) {
              customers = customers.where((c) => c.name.contains(q)).toList();
            }

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _loadTxs,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('تحديث الأرصدة'),
                  ),
                ),
                const SizedBox(height: 8),
                // اختيار الفترة: كل الفترات / هذا الشهر / شهر محدّد.
                PeriodFilter(
                  dates: allTxs.map((t) => _dt(t['datetime'])),
                  value: _month,
                  onChanged: (v) => setState(() => _month = v),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    StatTile(
                        value: '${custSnap.data!.docs.length}',
                        label: 'عدد الزبائن',
                        icon: Icons.people),
                    StatTile(
                        value: '${arNumber(totalBudget)} د.ع',
                        label: 'إجمالي الأرصدة',
                        icon: Icons.account_balance,
                        color: totalBudget >= 0
                            ? AppColors.success
                            : AppColors.danger),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن زبون',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 12),
                if (customers.isEmpty)
                  const EmptyState(
                      message: 'لا يوجد زبائن.', icon: Icons.people_outline)
                else
                  ...customers.map((c) {
                    final budget = c.receipt - c.expense;
                    final color =
                        budget >= 0 ? AppColors.success : AppColors.danger;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.oliveDark,
                          child: Text(c.name.isNotEmpty ? c.name[0] : '؟',
                              style: const TextStyle(color: AppColors.cream)),
                        ),
                        title: Text(c.name.isEmpty ? 'بدون اسم' : c.name,
                            style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'دفع: ${arNumber(c.receipt)}  •  مصروف: ${arNumber(c.expense)}',
                            style:
                                const TextStyle(color: AppColors.creamDim)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${arNumber(budget)} د.ع',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800)),
                            const Text('الرصيد',
                                style: TextStyle(
                                    color: AppColors.creamDim, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          }
        }
      }
    );
  }
}

class _Account {
  final String name;
  final num receipt;
  final num expense;
  _Account({required this.name, required this.receipt, required this.expense});
}
