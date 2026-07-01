import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/receipt.dart';
import '../../services/firestore_service.dart';
import '../../widgets/receipt_tile.dart';
import '../../widgets/ui.dart';
import '../execution/receipt_form.dart';

/// صفحة الحسابات (Scaffold): كل الوصولات الإلكترونية + إصدار وصل + مشاركة.
class AccountsReceiptsScreen extends StatelessWidget {
  final AppUser user;
  const AccountsReceiptsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات — الوصولات الإلكترونية')),
      body: AccountsReceiptsView(user: user),
    );
  }
}

/// عرض الحسابات (بدون Scaffold): يعرض **الوصولات الإلكترونية فقط** (قبض/صرف،
/// الصادرة من الموظفين أو المدير) — بلا أسماء زبائن. مع زر إصدار وصل جديد،
/// ومشاركة (PDF) وحذف لكل وصل، وفلتر بالنوع وبحث. يُستخدم كتبويب رئيسي للإدارة
/// وداخل صفحة الحسابات المستقلّة.
class AccountsReceiptsView extends StatefulWidget {
  final AppUser user; // المدير المُصدِر للوصولات المستقلة
  const AccountsReceiptsView({super.key, required this.user});

  @override
  State<AccountsReceiptsView> createState() => _AccountsReceiptsViewState();
}

class _AccountsReceiptsViewState extends State<AccountsReceiptsView> {
  final _fs = FirestoreService();
  int _filter = 0; // 0 = الكل، 1 = قبض، 2 = صرف
  String _q = '';

  void _issue() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptForm(executor: widget.user)),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Receipt>>(
      stream: _fs.allReceipts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل الوصولات.', icon: Icons.error_outline);
        }
        final all = snap.data ?? const <Receipt>[];
        final q = _q.trim().toLowerCase();
        final filtered = all.where((r) {
          if (_filter == 1 && r.expense) return false;
          if (_filter == 2 && !r.expense) return false;
          if (q.isNotEmpty) {
            final hay =
                '${r.ownerName} ${r.recipient} ${r.description} ${r.siteName}'
                    .toLowerCase();
            if (!hay.contains(q)) return false;
          }
          return true;
        }).toList();

        num totalIn = 0, totalOut = 0;
        for (final r in filtered) {
          if (r.expense) {
            totalOut += r.amount;
          } else {
            totalIn += r.amount;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _issue,
                icon: const Icon(Icons.receipt_long),
                label: const Text('إصدار وصل إلكتروني جديد'),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                StatTile(
                    value: Fmt.money(totalIn),
                    label: 'إجمالي القبض',
                    icon: Icons.south_west,
                    color: AppColors.success),
                StatTile(
                    value: Fmt.money(totalOut),
                    label: 'إجمالي الصرف',
                    icon: Icons.north_east,
                    color: AppColors.danger),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث (صاحب المشروع / مستلِم / وصف)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('الكل')),
                ButtonSegment(
                    value: 1, label: Text('قبض'), icon: Icon(Icons.south_west)),
                ButtonSegment(
                    value: 2, label: Text('صرف'), icon: Icon(Icons.north_east)),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            const SizedBox(height: 12),
            Text('عدد الوصولات: ${filtered.length}',
                style: const TextStyle(
                    color: AppColors.creamDim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const EmptyState(
                  message: 'لا توجد وصولات مطابقة.', icon: Icons.receipt_long)
            else
              ...filtered.map((r) => ReceiptTile(
                    receipt: r,
                    showOwner: true,
                    canDelete: true,
                  )),
          ],
        );
      },
    );
  }
}
