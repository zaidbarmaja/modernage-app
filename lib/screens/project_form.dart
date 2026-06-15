import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';

// ===========================================================================
//  نظام إضافة/تعديل المشروع الموحّد (من لوحة التحكم)
//  ـ يختار المدير النوع (تصميم/تنفيذ) ـ يُدخل التفاصيل ـ يُكلّف عدّة موظفين.
//  المشروع يصبح ملك «فريق» (assignedIds) بدل موظف واحد فقط.
// ===========================================================================

/// قائمة معرّفات الموظفين المكلّفين بالمشروع (مع دعم البيانات القديمة).
List<String> assignedIdList(Map<String, dynamic> d) {
  final raw = d['assignedIds'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }
  final legacy = (d['employeeId'] ?? '').toString();
  return legacy.isEmpty ? const [] : [legacy];
}

/// هل الموظف ضمن الفريق المكلّف بهذا المشروع؟
bool projectAssignedTo(Map<String, dynamic> d, String empId) =>
    assignedIdList(d).contains(empId);

/// أسماء الفريق المكلّف كنص واحد («زيد، علي، ...»).
String assignedNamesLabel(Map<String, dynamic> d) {
  final list = (d['assignedEmployees'] as List?) ?? const [];
  final names = <String>[];
  for (final e in list) {
    if (e is Map) {
      final nm = (e['name'] ?? '').toString().trim();
      if (nm.isNotEmpty) names.add(nm);
    }
  }
  if (names.isEmpty) {
    final legacy = (d['employeeName'] ?? '').toString().trim();
    if (legacy.isNotEmpty) names.add(legacy);
  }
  return names.join('، ');
}

const _statusOptions = ['قيد التنفيذ', 'معلّق', 'منجز'];

/// يبدأ تدفّق إضافة مشروع: إن لم يُحدّد النوع يُسأل عنه أولًا، ثم يُفتح النموذج.
Future<void> showAddProjectFlow(
  BuildContext context, {
  String? kind,
  EmployeeSession? preset,
}) async {
  final chosen = kind ??
      await showDialog<String>(
        context: context,
        builder: (_) => const _ProjectTypeDialog(),
      );
  if (chosen == null || !context.mounted) return;
  await showProjectForm(context, kind: chosen, preset: preset);
}

/// يفتح نموذج المشروع (إضافة أو تعديل).
Future<void> showProjectForm(
  BuildContext context, {
  required String kind,
  EmployeeSession? preset,
  DocumentSnapshot<Map<String, dynamic>>? existing,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: UnifiedProjectForm(
          kind: kind,
          preset: preset,
          existing: existing,
          onDone: () => Navigator.of(context).maybePop(),
        ),
      ),
    ),
  );
}

/// نافذة اختيار نوع المشروع.
class _ProjectTypeDialog extends StatelessWidget {
  const _ProjectTypeDialog();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('نوع المشروع الجديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر نوع المشروع لإضافته وتكليف الموظفين به.',
                style: TextStyle(color: AppColors.textSoft, fontSize: 13)),
            const SizedBox(height: 16),
            _typeCard(context, 'design', 'مشروع تصميم',
                'تصميم وعروض ومخططات', Icons.brush_outlined, AppColors.green600),
            const SizedBox(height: 12),
            _typeCard(context, 'execution', 'مشروع تنفيذ',
                'تنفيذ ميداني وصرفيات', Icons.construction_outlined,
                AppColors.green700),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
        ],
      ),
    );
  }

  Widget _typeCard(BuildContext context, String kind, String title,
      String sub, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, kind),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, AppColors.green900],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.cream200, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// نموذج المشروع الموحّد (تصميم/تنفيذ) — إضافة أو تعديل، مع تكليف الفريق.
class UnifiedProjectForm extends StatefulWidget {
  final String kind; // 'design' | 'execution'
  final EmployeeSession? preset; // موظف يُختار مسبقًا عند الإضافة
  final DocumentSnapshot<Map<String, dynamic>>? existing; // للتعديل
  final VoidCallback onDone;
  const UnifiedProjectForm({
    required this.kind,
    required this.onDone,
    this.preset,
    this.existing,
    super.key,
  });

  @override
  State<UnifiedProjectForm> createState() => _UnifiedProjectFormState();
}

class _UnifiedProjectFormState extends State<UnifiedProjectForm> {
  late final TextEditingController _owner;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _days;
  late final TextEditingController _total;
  late final TextEditingController _received;
  late final TextEditingController _details;
  late final TextEditingController _notes;
  late final TextEditingController _future;
  late final TextEditingController _offer;

  // إحداثيات موقع العمل (للتنفيذ) — تُستخدم نفسها كموقع بصمة الموظفين.
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  int _radius = 200;
  bool _locating = false;
  static const _radiusOptions = [100, 250, 500, 1000, 2000, 5000];

  String _currency = 'IQD';
  String _status = 'قيد التنفيذ';

  // الفريق المكلّف.
  final Set<String> _selectedIds = {};
  final Map<String, String> _empNames = {};
  List<({String id, String name, int days})> _employees = const [];
  bool _loadingEmps = true;

  // الصرفيات (للتنفيذ).
  final List<TextEditingController> _expDesc = [];
  final List<TextEditingController> _expAmt = [];
  final List<TextEditingController> _expNote = [];
  final ValueNotifier<int> _expTotal = ValueNotifier<int>(0);

  // الملفات.
  final List<UploadFile> _newDocs = [];
  final List<UploadFile> _newPhotos = [];
  List<dynamic> _existingDocs = [];
  List<dynamic> _existingPhotos = [];

  bool _busy = false;

  bool get isExec => widget.kind == 'execution';
  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing?.data() ?? <String, dynamic>{};
    _owner = TextEditingController(text: '${d['ownerName'] ?? ''}');
    _phone = TextEditingController(text: '${d['ownerPhone'] ?? ''}');
    _location = TextEditingController(text: '${d['location'] ?? ''}');
    _lat = TextEditingController(
        text: d['lat'] is num ? '${(d['lat'] as num)}' : '');
    _lng = TextEditingController(
        text: d['lng'] is num ? '${(d['lng'] as num)}' : '');
    _radius = (d['radius'] is num) ? (d['radius'] as num).toInt() : 200;
    if (!_radiusOptions.contains(_radius)) _radius = 200;
    final total = (d['totalAmount'] is num) ? (d['totalAmount'] as num).toInt() : 0;
    final received = (d['receivedAmount'] is num)
        ? (d['receivedAmount'] as num).toInt()
        : (d['paidAmount'] is num ? (d['paidAmount'] as num).toInt() : 0);
    _total = TextEditingController(text: total == 0 ? '' : '$total');
    _received = TextEditingController(text: received == 0 ? '' : '$received');
    _currency = '${d['currency'] ?? 'IQD'}' == 'USD' ? 'USD' : 'IQD';
    final rem = d['remainingDays'] ?? d['days'] ?? 0;
    _days = TextEditingController(text: isEdit ? '$rem' : '');
    _details = TextEditingController(text: '${d['details'] ?? ''}');
    _notes = TextEditingController(text: '${d['notes'] ?? ''}');
    _future = TextEditingController(text: '${d['futurePlan'] ?? ''}');
    _offer = TextEditingController(text: '${d['offerType'] ?? ''}');
    _status = '${d['status'] ?? 'قيد التنفيذ'}';
    if (!_statusOptions.contains(_status)) _status = 'قيد التنفيذ';
    _existingDocs = List<dynamic>.from((d['documents'] as List?) ?? const []);
    _existingPhotos = List<dynamic>.from((d['photos'] as List?) ?? const []);
    for (final e in (d['expenses'] as List?) ?? const []) {
      if (e is Map) {
        _addExpense(
          desc: '${e['desc'] ?? ''}',
          amount: (e['amount'] is num) ? (e['amount'] as num).toInt() : 0,
          note: '${e['note'] ?? ''}',
        );
      }
    }
    // الفريق المكلّف الحالي (للتعديل) + الموظف الممرّر مسبقًا.
    _selectedIds.addAll(assignedIdList(d));
    for (final e in (d['assignedEmployees'] as List?) ?? const []) {
      if (e is Map) _empNames['${e['id']}'] = '${e['name'] ?? ''}';
    }
    final legacyId = (d['employeeId'] ?? '').toString();
    if (legacyId.isNotEmpty) {
      _empNames.putIfAbsent(legacyId, () => '${d['employeeName'] ?? ''}');
    }
    if (widget.preset != null) {
      _selectedIds.add(widget.preset!.id);
      _empNames[widget.preset!.id] = widget.preset!.name;
    }
    _recomputeTotal();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final depts = await Db.departments.get();
      final keyword = isExec ? 'تنفيذ' : 'تصميم';
      final deptIds = depts.docs
          .where((x) => '${x.data()['name'] ?? ''}'.contains(keyword))
          .map((x) => x.id)
          .toSet();
      // مجموع الأيام المتبقية لكل موظف من مشاريعه الحالية (ليعرف المدير من لديه وقت).
      final daysByEmp = <String, int>{};
      final projSnap =
          await (isExec ? Db.executionProjects : Db.designProjects).get();
      for (final p in projSnap.docs) {
        final d = p.data();
        final v = d['remainingDays'] ?? d['days'] ?? 0;
        final rem = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
        if (rem <= 0) continue;
        for (final id in assignedIdList(d)) {
          daysByEmp[id] = (daysByEmp[id] ?? 0) + rem;
        }
      }
      final emps = await Db.employees.get();
      final list = <({String id, String name, int days})>[];
      for (final e in emps.docs) {
        if (deptIds.contains(e.data()['departmentId'])) {
          final nm = '${e.data()['name'] ?? ''}';
          list.add((id: e.id, name: nm, days: daysByEmp[e.id] ?? 0));
          _empNames[e.id] = nm;
        }
      }
      list.sort((a, b) => a.days.compareTo(b.days));
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loadingEmps = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEmps = false);
    }
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
    _owner.dispose();
    _phone.dispose();
    _location.dispose();
    _lat.dispose();
    _lng.dispose();
    _days.dispose();
    _total.dispose();
    _received.dispose();
    _details.dispose();
    _notes.dispose();
    _future.dispose();
    _offer.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
    if (mounted) setState(() {});
  }

  /// يلتقط الموقع الحالي كموقع عمل/بصمة لمشروع التنفيذ.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      _lat.text = loc.lat.toStringAsFixed(6);
      _lng.text = loc.lng.toStringAsFixed(6);
      if (_location.text.trim().isEmpty && loc.address.isNotEmpty) {
        _location.text = loc.address;
      }
      if (mounted) setState(() {});
    } on LocationException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر تحديد الموقع. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final owner = _owner.text.trim();
    final phone = _phone.text.trim();
    // الحقول الوحيدة الإلزامية: اسم صاحب المشروع ورقم هاتفه. الباقي اختياري.
    if (owner.isEmpty || phone.isEmpty) {
      _toast('أدخل اسم صاحب المشروع ورقم هاتفه (إلزامي).');
      return;
    }
    final daysVal = int.tryParse(_days.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      final collName = isExec ? 'execution_projects' : 'design_projects';
      final upDocs = await Db.uploadFiles(_newDocs, 'documents', collName);
      final documents = [..._existingDocs, ...upDocs];
      var photos = _existingPhotos;
      if (isExec) {
        final upPhotos = await Db.uploadFiles(_newPhotos, 'photos', collName);
        photos = [..._existingPhotos, ...upPhotos];
      }
      final total = int.tryParse(_total.text.trim()) ?? 0;
      final received = int.tryParse(_received.text.trim()) ?? 0;
      final ids = _selectedIds.toList();
      final team = [
        for (final id in ids) {'id': id, 'name': _empNames[id] ?? ''}
      ];
      final coll = isExec ? Db.executionProjects : Db.designProjects;

      final data = <String, dynamic>{
        // لا يوجد حقل «اسم المشروع» — يُعرَّف المشروع باسم صاحبه.
        'name': owner,
        'ownerName': owner,
        'ownerPhone': phone,
        'location': _location.text.trim(),
        'currency': _currency,
        'totalAmount': total,
        'receivedAmount': received,
        'remainingDays': daysVal,
        'details': _details.text.trim(),
        'notes': _notes.text.trim(),
        'status': _status,
        'assignedIds': ids,
        'assignedEmployees': team,
        'employeeId': ids.isEmpty ? '' : ids.first,
        'employeeName': ids.isEmpty ? '' : (_empNames[ids.first] ?? ''),
        'documents': documents,
      };
      if (isExec) {
        data['futurePlan'] = _future.text.trim();
        data['photos'] = photos;
        data['expenses'] = _collectExpenses();
        // موقع البصمة لموظفي التنفيذ = إحداثيات موقع العمل.
        final lat = double.tryParse(_lat.text.trim());
        final lng = double.tryParse(_lng.text.trim());
        data['lat'] = lat;
        data['lng'] = lng;
        data['radius'] = _radius;
      } else {
        data['offerType'] = _offer.text.trim();
      }

      if (isEdit) {
        await widget.existing!.reference.update(data);
      } else {
        await coll.add({
          ...data,
          'days': daysVal,
          'tasks': <Map<String, dynamic>>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      widget.onDone();
    } catch (_) {
      if (mounted) {
        _toast('تعذّر الحفظ. حاول مجددًا.');
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: const Text('حذف هذا المشروع نهائيًا؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف',
                    style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.existing!.reference.delete();
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel = isExec ? 'تنفيذ' : 'تصميم';
    return Container(
      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cream100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      isExec
                          ? Icons.construction_outlined
                          : Icons.brush_outlined,
                      color: AppColors.green700,
                      size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      isEdit
                          ? 'تعديل مشروع $kindLabel'
                          : 'إضافة مشروع $kindLabel جديد',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field('اسم صاحب المشروع', _owner, required: true),
            _field('رقم هاتف صاحب المشروع', _phone,
                keyboard: TextInputType.phone, required: true),

            // ===== موقع العمل =====
            if (isExec)
              _execLocationSection()
            else
              _field('موقع العمل', _location),

            // ===== الفريق المكلّف =====
            _teamPicker(),
            const SizedBox(height: 12),

            // ===== العملة =====
            const Text('العملة', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
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
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _field('كامل المبلغ', _total,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(isExec ? 'المصروفات' : 'المستلم', _received,
                        keyboard: TextInputType.number)),
              ],
            ),
            _field(isEdit ? 'الأيام المتبقية' : 'مدة المشروع (عدد الأيام)', _days,
                keyboard: TextInputType.number),
            if (!isExec) _field('نوع العرض', _offer),

            // ===== حالة المشروع =====
            const Text('حالة المشروع', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _statusOptions)
                ChoiceChip(
                  label: Text(s),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
            const SizedBox(height: 12),

            _field('تفاصيل المشروع', _details, maxLines: 3),
            if (isExec)
              _field('ماذا ستفعلون في الأيام القادمة؟', _future, maxLines: 2),
            _field('ملاحظات عامة', _notes, maxLines: 2),

            _fileSection('ملفات / مستندات المشروع', _newDocs, _existingDocs),
            if (isExec) ...[
              _fileSection('الصور اليومية للعمل', _newPhotos, _existingPhotos,
                  imagesOnly: true),
              _expensesBlock(),
            ],
            const SizedBox(height: 14),
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
                    onPressed: _busy ? null : _delete,
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

  // ===== اختيار الفريق المكلّف =====
  Widget _teamPicker() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
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
            children: [
              const Icon(Icons.groups_outlined,
                  size: 18, color: AppColors.green700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('الموظفون المكلّفون بالمشروع',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (_selectedIds.isNotEmpty)
                Text('${_selectedIds.length} مختار',
                    style: const TextStyle(
                        color: AppColors.green700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingEmps)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('جارٍ تحميل الموظفين…',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            )
          else if (_employees.isEmpty)
            const Text(
                'لا يوجد موظفون في هذا القسم. أضِفهم من «الأقسام والموظفون» أولًا.',
                style: TextStyle(color: AppColors.danger, fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _employees)
                  FilterChip(
                    label: Text(
                        e.days > 0 ? '${e.name} · ${e.days} يوم' : '${e.name} · متفرّغ'),
                    avatar: CircleAvatar(
                      backgroundColor: e.days > 0
                          ? AppColors.cream200
                          : AppColors.green100,
                      child: Text('${e.days}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    selected: _selectedIds.contains(e.id),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selectedIds.add(e.id);
                      } else {
                        _selectedIds.remove(e.id);
                      }
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fileSection(
      String label, List<UploadFile> newFiles, List<dynamic> existing,
      {bool imagesOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
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
      {int maxLines = 1, TextInputType? keyboard, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.text),
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800))
                else
                  const TextSpan(
                      text: ' (اختياري)',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextField(controller: c, maxLines: maxLines, keyboardType: keyboard),
        ],
      ),
    );
  }

  // ===== موقع العمل لمشروع التنفيذ (إحداثيات = موقع البصمة) =====
  Widget _execLocationSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.location_on, size: 18, color: AppColors.green700),
            SizedBox(width: 8),
            Expanded(
              child: Text('موقع العمل (يُستخدم كموقع بصمة الموظفين)',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
              'حدّد الموقع بالضغط على «موقعي الحالي» أو بإدخال خطّي الطول والعرض يدويًا.',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 10),
          _field('اسم/عنوان الموقع', _location),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('خط العرض (Lat)',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('خط الطول (Lng)',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('موقعي الحالي'),
            ),
          ),
          const SizedBox(height: 10),
          const Text('النطاق المسموح للبصمة (متر)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _radiusOptions)
                ChoiceChip(
                  label: Text('$r م'),
                  selected: _radius == r,
                  onSelected: (_) => setState(() => _radius = r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
