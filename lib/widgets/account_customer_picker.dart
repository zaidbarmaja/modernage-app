import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/firebase_service.dart';

/// منتقي زبون من مجموعة الحسابات المشتركة (customers): يربط المشروع بزبون موجود
/// في قاعدة البيانات بملء اسم صاحب المشروع باسمه. (نفس زبائن صفحة «الحسابات».)
class AccountCustomerPicker extends StatelessWidget {
  final String? selectedName;
  final ValueChanged<String> onSelected;
  final String label;
  const AccountCustomerPicker({
    super.key,
    required this.onSelected,
    this.selectedName,
    this.label = 'اربط بزبون من الحسابات (يملأ الاسم)',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.customers.snapshots(),
      builder: (context, snap) {
        final names = (snap.data?.docs ?? [])
            .map((d) => '${d.data()['name'] ?? ''}'.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (names.isEmpty) return const SizedBox.shrink();
        final value = names.contains(selectedName) ? selectedName : null;
        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceAlt,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.link),
          ),
          items: names
              .map((n) => DropdownMenuItem<String>(
                  value: n, child: Text(n, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
        );
      },
    );
  }
}
