import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/project_tasks.dart';
import 'daily_report.dart';
import 'execution_project_detail.dart';
import 'project_attendance.dart';
import 'project_form.dart';

class ExecutionScreen extends StatefulWidget {
  /// صلاحية إدارية عند فتح صفحة الموظف من لوحة التحكم.
  final bool canManage;
  const ExecutionScreen({this.canManage = false, super.key});
  @override
  State<ExecutionScreen> createState() => _ExecutionScreenState();
}

class _ExecutionScreenState extends State<ExecutionScreen> {
  static const coll = 'execution_projects';
  EmployeeSession? _emp;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = Session.get(Session.executionKey);
    setState(() => _emp = saved);
    if (saved != null) {
      Db.applyDailyTick(coll, 'execution_meta', saved.id).catchError((_) {});
    }
  }

  Future<void> _onLogin(EmployeeSession s) async {
    await Session.set(Session.executionKey, s);
    setState(() => _emp = s);
    Db.applyDailyTick(coll, 'execution_meta', s.id).catchError((_) {});
  }

  Future<void> _logout() async {
    await Session.clear(Session.executionKey);
    setState(() => _emp = null);
  }

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  @override
  Widget build(BuildContext context) {
    if (_emp == null) return EmployeeLogin(onSuccess: _onLogin);
    final emp = _emp!;
    // تُحمَّل كل المشاريع وتُرشَّح حسب عضوية الفريق (تدعم البيانات القديمة).
    final stream = Db.executionProjects.snapshots();

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
                  const Text('موظفي التنفيذ',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  EmployeeBar(name: emp.name, onLogout: _logout),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي أيام التنفيذ المتبقية',
                              style: TextStyle(color: AppColors.cream200)),
                          const SizedBox(height: 6),
                          Text('$totalRemaining يوم',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Text(ArDate.fullArabicDate(DateTime.now()),
                        style: const TextStyle(color: AppColors.cream300)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AttendanceCheckCard(employee: emp),
              const SizedBox(height: 16),
              DailyReportCard(
                  employeeId: emp.id,
                  employeeName: emp.name,
                  kind: 'execution'),
              const SizedBox(height: 16),
              const Text('مشاريع التنفيذ',
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
                    icon: Icons.engineering,
                    title: 'لا توجد مشاريع بعد',
                    subtitle:
                        'ستظهر هنا المشاريع التي يسندها إليك المدير من لوحة التحكم.',
                  ),
                )
              else
                AutoGrid(
                  minTileWidth: 300,
                  gap: 14,
                  children: [for (final d in docs) _execCard(d)],
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _execCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = (data['status'] ?? 'قيد التنفيذ').toString();
    final suspended = status.contains('معلّق') || status.contains('معلق');
    final remaining = _remaining(data);
    final done = remaining == 0;
    final owner = (data['ownerName'] ?? '').toString();
    final tasks = (data['tasks'] as List?) ?? [];
    final pct = taskProgressPercent(tasks);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExecutionProjectDetailScreen(
          employee: _emp!,
          reference: doc.reference,
          canManage: widget.canManage,
        ),
      )),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                StatusBadge(status),
              ],
            ),
            if (owner.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('صاحب المشروع: $owner',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
            if ((data['location'] ?? '').toString().isNotEmpty)
              Text('الموقع: ${data['location']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}

/// نموذج إضافة/تعديل مشروع تنفيذ (يشمل الملفات والصرفيات).
class ExecForm extends StatefulWidget {
  final EmployeeSession employee;
  final DocumentSnapshot<Map<String, dynamic>>? existing;
  final VoidCallback onDone;
  const ExecForm({
    required this.employee,
    required this.onDone,
    this.existing,
    super.key,
  });

  @override
  State<ExecForm> createState() => ExecFormState();
}

class ExecFormState extends State<ExecForm> {
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _days;
  late final TextEditingController _details;
  late final TextEditingController _future;
  late final TextEditingController _notes;
  late final TextEditingController _total;
  late final TextEditingController _received;
  String _currency = 'IQD';

  final List<UploadFile> _newDocs = [];
  final List<UploadFile> _newPhotos = [];
  final List<TextEditingController> _expDesc = [];
  final List<TextEditingController> _expAmt = [];
  final List<TextEditingController> _expNote = [];
  final ValueNotifier<int> _expTotal = ValueNotifier<int>(0);
  List<dynamic> _existingDocs = [];
  List<dynamic> _existingPhotos = [];
  bool _busy = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing?.data() ?? {};
    _name = TextEditingController(text: d['name'] ?? '');
    _owner = TextEditingController(text: d['ownerName'] ?? '');
    _phone = TextEditingController(text: d['ownerPhone'] ?? '');
    _location = TextEditingController(text: d['location'] ?? '');
    final total = (d['totalAmount'] is num) ? (d['totalAmount'] as num).toInt() : 0;
    final received =
        (d['receivedAmount'] is num) ? (d['receivedAmount'] as num).toInt() : 0;
    _total = TextEditingController(text: total == 0 ? '' : '$total');
    _received = TextEditingController(text: received == 0 ? '' : '$received');
    _currency = (d['currency'] ?? 'IQD').toString() == 'USD' ? 'USD' : 'IQD';
    _days = TextEditingController(
        text: isEdit
            ? '${d['remainingDays'] ?? d['days'] ?? 0}'
            : '');
    _details = TextEditingController(text: d['details'] ?? '');
    _future = TextEditingController(text: d['futurePlan'] ?? '');
    _notes = TextEditingController(text: d['notes'] ?? '');
    _existingDocs = (d['documents'] as List?) ?? [];
    _existingPhotos = (d['photos'] as List?) ?? [];
    for (final e in (d['expenses'] as List?) ?? []) {
      if (e is Map) {
        _addExpense(
          desc: '${e['desc'] ?? ''}',
          amount: (e['amount'] is num) ? (e['amount'] as num).toInt() : 0,
          note: '${e['note'] ?? ''}',
        );
      }
    }
    _recomputeTotal();
  }

  void _addExpense({String desc = '', int amount = 0, String note = ''}) {
    final amtC = TextEditingController(text: amount == 0 ? '' : '$amount');
    amtC.addListener(_recomputeTotal);
    _expDesc.add(TextEditingController(text: desc));
    _expAmt.add(amtC);
    _expNote.add(TextEditingController(text: note));
  }

  void _removeExpense(int i) {
    _expDesc.removeAt(i).dispose();
    _expAmt.removeAt(i).dispose();
    _expNote.removeAt(i).dispose();
    _recomputeTotal();
  }

  void _recomputeTotal() {
    var total = 0;
    for (final c in _expAmt) {
      total += int.tryParse(c.text.trim()) ?? 0;
    }
    _expTotal.value = total;
  }

  List<Map<String, dynamic>> _collectExpenses() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _expDesc.length; i++) {
      final desc = _expDesc[i].text.trim();
      final amount = int.tryParse(_expAmt[i].text.trim()) ?? 0;
      final note = _expNote[i].text.trim();
      if (desc.isNotEmpty || amount != 0 || note.isNotEmpty) {
        out.add({'desc': desc, 'amount': amount, 'note': note});
      }
    }
    return out;
  }

  @override
  void dispose() {
    for (final c in [..._expDesc, ..._expAmt, ..._expNote]) {
      c.dispose();
    }
    _expTotal.dispose();
    _name.dispose();
    _owner.dispose();
    _phone.dispose();
    _location.dispose();
    _days.dispose();
    _details.dispose();
    _future.dispose();
    _notes.dispose();
    _total.dispose();
    _received.dispose();
    super.dispose();
  }

  Future<void> _pick(List<UploadFile> target, {bool imagesOnly = false}) async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: imagesOnly ? FileType.image : FileType.any,
    );
    if (res == null) return;
    for (final f in res.files) {
      if (f.bytes != null) target.add(UploadFile(f.name, f.bytes!));
    }
    setState(() {});
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final owner = _owner.text.trim();
    final location = _location.text.trim();
    final daysVal = int.tryParse(_days.text.trim());
    if (name.isEmpty || owner.isEmpty || location.isEmpty || daysVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الرجاء تعبئة الاسم وصاحب المشروع والموقع والأيام')));
      return;
    }
    setState(() => _busy = true);
    try {
      final upDocs =
          await Db.uploadFiles(_newDocs, 'documents', _ExecutionScreenState.coll);
      final upPhotos =
          await Db.uploadFiles(_newPhotos, 'photos', _ExecutionScreenState.coll);

      final documents = [..._existingDocs, ...upDocs];
      final photos = [..._existingPhotos, ...upPhotos];

      final total = int.tryParse(_total.text.trim()) ?? 0;
      final received = int.tryParse(_received.text.trim()) ?? 0;
      if (isEdit) {
        await widget.existing!.reference.update({
          'name': name,
          'ownerName': owner,
          'ownerPhone': _phone.text.trim(),
          'location': location,
          'remainingDays': daysVal,
          'details': _details.text.trim(),
          'futurePlan': _future.text.trim(),
          'notes': _notes.text.trim(),
          'currency': _currency,
          'totalAmount': total,
          'receivedAmount': received,
          'documents': documents,
          'photos': photos,
          'expenses': _collectExpenses(),
        });
      } else {
        await Db.executionProjects.add({
          'name': name,
          'ownerName': owner,
          'ownerPhone': _phone.text.trim(),
          'location': location,
          'details': _details.text.trim(),
          'futurePlan': _future.text.trim(),
          'notes': _notes.text.trim(),
          'currency': _currency,
          'totalAmount': total,
          'receivedAmount': received,
          'days': daysVal,
          'remainingDays': daysVal,
          'documents': documents,
          'photos': photos,
          'expenses': _collectExpenses(),
          'tasks': <Map<String, dynamic>>[],
          'employeeId': widget.employee.id,
          'employeeName': widget.employee.name,
          'status': 'قيد التنفيذ',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر الحفظ. حاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
      margin: isEdit ? null : const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'تعديل مشروع التنفيذ' : 'إضافة مشروع تنفيذ جديد',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            _field('اسم المشروع', _name),
            _field('اسم صاحب المشروع', _owner),
            _field('رقم هاتف صاحب المشروع', _phone,
                keyboard: TextInputType.phone),
            _field('موقع العمل', _location),
            const Text('العملة', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('دينار عراقي'),
                  selected: _currency == 'IQD',
                  onSelected: (_) => setState(() => _currency = 'IQD'),
                ),
                ChoiceChip(
                  label: const Text('دولار'),
                  selected: _currency == 'USD',
                  onSelected: (_) => setState(() => _currency = 'USD'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _field('كامل المبلغ', _total,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field('المستلَم', _received,
                        keyboard: TextInputType.number)),
              ],
            ),
            if (isEdit) ...[
              const Text('أيام التنفيذ المتبقية',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              DaysStepper(controller: _days),
              const SizedBox(height: 12),
            ] else
              _field('مدة التنفيذ (عدد الأيام)', _days,
                  keyboard: TextInputType.number),
            _field('تفاصيل المشروع', _details, maxLines: 3),
            _field('ماذا ستفعل في الأيام القادمة؟', _future, maxLines: 3),
            _field('ملاحظات عامة', _notes, maxLines: 2),
            _fileSection('مستندات القبض / المدفوعات', _newDocs, _existingDocs),
            _fileSection('الصور اليومية للعمل', _newPhotos, _existingPhotos,
                imagesOnly: true),
            _expensesBlock(),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المشروع'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                    onPressed: widget.onDone, child: const Text('إلغاء')),
                if (isEdit) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await widget.existing!.reference.delete();
                      widget.onDone();
                    },
                    child: const Text('حذف المشروع',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileSection(String label, List<UploadFile> newFiles,
      List<dynamic> existing,
      {bool imagesOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in existing)
                Chip(
                  label: Text('${(f as Map)['name'] ?? 'ملف'}'),
                  onDeleted: () => setState(() => existing.remove(f)),
                  backgroundColor: AppColors.cream100,
                ),
              for (final f in newFiles)
                Chip(
                  avatar: const Icon(Icons.upload_file, size: 16),
                  label: Text(f.name),
                  onDeleted: () => setState(() => newFiles.remove(f)),
                  backgroundColor: AppColors.green100,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('إضافة'),
                onPressed: () => _pick(newFiles, imagesOnly: imagesOnly),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expensesBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('السلف والصرفيات',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              OutlinedButton(
                onPressed: () => setState(() => _addExpense()),
                child: const Text('+ إضافة صرفية'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _expDesc.length; i++) _expenseRow(i),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي المصروف:'),
              ValueListenableBuilder<int>(
                valueListenable: _expTotal,
                builder: (context, total, child) => Text(arNumber(total),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expenseRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(hintText: 'البيان'),
              controller: _expDesc[i],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(hintText: 'المبلغ'),
              keyboardType: TextInputType.number,
              controller: _expAmt[i],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _removeExpense(i)),
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
              controller: c, maxLines: maxLines, keyboardType: keyboard),
        ],
      ),
    );
  }
}
