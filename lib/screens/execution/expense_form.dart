import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/expense.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';

/// نموذج إضافة سلفة أو صرفية (المبلغ المصروف مع الملاحظة).
class ExpenseForm extends StatefulWidget {
  final WorkSite site;
  final AppUser executor;
  const ExpenseForm({super.key, required this.site, required this.executor});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  ExpenseType _type = ExpenseType.spending;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _fs.addExpense(Expense(
        id: '',
        siteId: widget.site.id,
        siteName: widget.site.siteName,
        ownerName: widget.site.ownerName,
        executorUid: widget.executor.uid,
        executorName: widget.executor.name,
        type: _type,
        amount: num.tryParse(_amount.text.trim()) ?? 0,
        note: _note.text.trim(),
        date: DateTime.now(),
      ));
      if (mounted) {
        showSnack(context, 'تم تسجيل ${_type.labelAr} ✓');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر الحفظ.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلفة / صرفية')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ExpenseType>(
                  segments: const [
                    ButtonSegment(
                        value: ExpenseType.spending,
                        label: Text('صرفية'),
                        icon: Icon(Icons.shopping_cart)),
                    ButtonSegment(
                        value: ExpenseType.advance,
                        label: Text('سلفة'),
                        icon: Icon(Icons.account_balance_wallet)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المصروف',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    final n = num.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الملاحظة',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
