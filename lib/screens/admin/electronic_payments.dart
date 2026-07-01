import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/firebase_service.dart';
import '../../utils/time_utils.dart';
import '../../widgets/ui.dart';

/// «الدفع الإلكتروني»: الوصولات (قبض/صرف) التي أصدرها موظفو التنفيذ آلياً من
/// الميدان. تُعرض بعلامة «تلقائي» بلون مميّز ليعرف المحاسب أنها أُضيفت تلقائياً،
/// مع فلتر حسب الزبون. مصدرها مجموعة customerTransactions (source='electronic').
class ElectronicPaymentsScreen extends StatefulWidget {
  const ElectronicPaymentsScreen({super.key});

  @override
  State<ElectronicPaymentsScreen> createState() =>
      _ElectronicPaymentsScreenState();
}

class _ElectronicPaymentsScreenState extends State<ElectronicPaymentsScreen> {
  String? _customer; // null = كل الزبائن

  static num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v'.replaceAll(',', '').trim()) ?? 0;
  }

  static DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse('$v');
  }

  static bool _isExpense(Map<String, dynamic> m) =>
      m['kind'] == 'expense' ||
      (_num(m['expense']) > 0 && _num(m['receipt']) == 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع الإلكتروني')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.customerTransactions
            .where('source', isEqualTo: 'electronic')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                message: 'تعذّر تحميل الدفع الإلكتروني.',
                icon: Icons.error_outline);
          }
          if (!snap.hasData) return const LoadingView();

          final all = snap.data!.docs
              .map((d) => d.data())
              .where((m) => m['deleted'] != true)
              .toList();

          final names = <String>{};
          for (final m in all) {
            final n = '${m['customerName'] ?? ''}'.trim();
            if (n.isNotEmpty) names.add(n);
          }
          final nameList = names.toList()..sort();
          if (_customer != null && !names.contains(_customer)) _customer = null;

          var rows = all
              .where((m) =>
                  _customer == null ||
                  '${m['customerName'] ?? ''}'.trim() == _customer)
              .toList()
            ..sort((a, b) {
              final da = _dt(a['datetime']) ?? DateTime(0);
              final db = _dt(b['datetime']) ?? DateTime(0);
              return db.compareTo(da);
            });

          num received = 0, spent = 0;
          for (final m in rows) {
            received += _num(m['receipt']);
            spent += _num(m['expense']);
          }

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _customer,
                isExpanded: true,
                dropdownColor: AppColors.surfaceAlt,
                decoration: const InputDecoration(
                  labelText: 'الزبون',
                  prefixIcon: Icon(Icons.person_search),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('كل الزبائن')),
                  ...nameList.map((n) => DropdownMenuItem<String?>(
                      value: n,
                      child: Text(n, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _customer = v),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  StatTile(
                      value: '${arNumber(received)} د.ع',
                      label: 'إجمالي القبض',
                      icon: Icons.south_west,
                      color: AppColors.success),
                  StatTile(
                      value: '${arNumber(spent)} د.ع',
                      label: 'إجمالي الصرف',
                      icon: Icons.north_east,
                      color: AppColors.danger),
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const EmptyState(
                    message: 'لا توجد وصولات إلكترونية.',
                    icon: Icons.receipt_long)
              else
                ...rows.map(_card),
            ],
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final expense = _isExpense(m);
    final amount = expense ? _num(m['expense']) : _num(m['receipt']);
    final color = expense ? AppColors.danger : AppColors.success;
    final who = '${m['customerName'] ?? ''}'.trim();
    final date = _dt(m['datetime']);
    final desc = '${m['description'] ?? ''}'.trim();

    return Card(
      child: Container(
        // شريط جانبي بلون مميّز (كهرماني) للدلالة على أنه أُضيف تلقائياً.
        decoration: const BoxDecoration(
          border: Border(
              right: BorderSide(color: AppColors.warning, width: 4)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.warning.withValues(alpha: 0.18),
            child: Icon(expense ? Icons.north_east : Icons.south_west,
                color: color),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(who.isEmpty ? 'بدون اسم' : who,
                    style: const TextStyle(
                        color: AppColors.cream, fontWeight: FontWeight.bold)),
              ),
              Text('${arNumber(amount)} د.ع',
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          subtitle: Text(
            '${expense ? 'صرف' : 'قبض'} • تلقائي'
            '${date == null ? '' : ' • ${ArDate.dateOnly(date)}'}'
            '${desc.isEmpty ? '' : '\n$desc'}',
            style: const TextStyle(color: AppColors.creamDim, height: 1.5),
          ),
          isThreeLine: desc.isNotEmpty,
        ),
      ),
    );
  }
}
