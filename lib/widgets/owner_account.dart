import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/work_site.dart';
import '../services/firebase_service.dart';
import '../services/firestore_service.dart';
import 'ui.dart';

/// أدوات حساب رصيد صاحب المشروع من حسابات المحاسبة المشتركة (customerTransactions).
/// نستعلم بالاسم (where) بدل قراءة المجموعة كاملة — لتقليل تكلفة Firestore بشدّة.
num _num(dynamic v) =>
    v is num ? v : num.tryParse('$v'.replaceAll(',', '').trim()) ?? 0;

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

class _Bal {
  num received = 0;
  num spent = 0;
  int count = 0;
  num get balance => received - spent;
}

/// يجمع أرصدة الأسماء (المطبّعة) من حركات الحسابات (يتجاهل المحذوف).
Map<String, _Bal> _balancesByOwner(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final map = <String, _Bal>{};
  for (final d in docs) {
    final m = d.data();
    if (m['deleted'] == true) continue;
    final name = _norm('${m['customerName'] ?? ''}');
    if (name.isEmpty) continue;
    final b = map.putIfAbsent(name, () => _Bal());
    b.received += _num(m['receipt']);
    b.spent += _num(m['expense']);
    b.count++;
  }
  return map;
}

/// بطاقة حساب صاحب مشروع واحد: المدفوع (المستلَم) + المصروف + الرصيد + عدد
/// الحركات — من قاعدة بيانات المحاسبة (نفس أرقام صفحة «الحسابات»).
/// تقرأ حركات هذا الصاحب فقط عبر where('customerName').
class OwnerAccountCard extends StatelessWidget {
  final String ownerName;
  const OwnerAccountCard({super.key, required this.ownerName});

  @override
  Widget build(BuildContext context) {
    final key = _norm(ownerName);
    if (key.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.customerTransactions
          .where('customerName', isEqualTo: key)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        num received = 0, spent = 0;
        var count = 0;
        for (final d in snap.data?.docs ?? const []) {
          final m = d.data();
          if (m['deleted'] == true) continue;
          received += _num(m['receipt']);
          spent += _num(m['expense']);
          count++;
        }
        final balance = received - spent;
        return SectionCard(
          title: 'حساب صاحب المشروع: $ownerName',
          icon: Icons.account_balance_wallet,
          child: Column(
            children: [
              InfoRow(
                  label: 'المدفوع (المستلَم)',
                  value: Fmt.money(received),
                  valueColor: AppColors.success),
              InfoRow(
                  label: 'المصروف',
                  value: Fmt.money(spent),
                  valueColor: AppColors.danger),
              InfoRow(
                  label: 'الرصيد',
                  value: Fmt.money(balance),
                  valueColor:
                      balance >= 0 ? AppColors.success : AppColors.danger),
              InfoRow(label: 'عدد الحركات', value: '$count'),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('جارٍ التحديث…',
                      style: TextStyle(color: AppColors.creamDim, fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// بطاقة تجمع حسابات أصحاب مشاريع الموظف المُسندة إليه (لصفحته الرئيسية):
/// لكل صاحب مشروع اسمه ورصيده. تستعلم بأسماء أصحاب مشاريعه فقط (whereIn).
class MySitesAccountsCard extends StatelessWidget {
  final String uid;
  const MySitesAccountsCard({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<WorkSite>>(
      stream: fs.sitesByExecutor(uid),
      builder: (context, siteSnap) {
        final sites = siteSnap.data ?? const <WorkSite>[];
        // أصحاب المشاريع الفريدون (مطبّع → اسم للعرض).
        final owners = <String, String>{};
        for (final s in sites) {
          final n = _norm(s.ownerName);
          if (n.isNotEmpty) owners[n] = s.ownerName.trim();
        }
        if (owners.isEmpty) return const SizedBox.shrink();
        // whereIn يقبل حتى 30 قيمة — كافٍ لموظف تنفيذ (نأخذ أول 30 احتياطًا).
        final keys = owners.keys.take(30).toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Db.customerTransactions
              .where('customerName', whereIn: keys)
              .snapshots(),
          builder: (context, txSnap) {
            final bals = _balancesByOwner(txSnap.data?.docs ?? const []);
            return SectionCard(
              title: 'حسابات أصحاب مشاريعي',
              icon: Icons.account_balance,
              child: Column(
                children: [
                  for (final e in owners.entries)
                    _ownerRow(e.value, bals[e.key] ?? _Bal()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _ownerRow(String name, _Bal b) {
    final color = b.balance >= 0 ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.person, size: 18, color: AppColors.oliveBright),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name.isEmpty ? 'بدون اسم' : name,
                style: const TextStyle(
                    color: AppColors.cream, fontWeight: FontWeight.bold)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(b.balance),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              Text('دفع ${Fmt.money(b.received)}',
                  style: const TextStyle(
                      color: AppColors.creamDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
