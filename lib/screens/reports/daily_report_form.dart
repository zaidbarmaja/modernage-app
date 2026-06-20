import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';

/// نموذج كتابة/تعديل تقرير اليوم (ماذا أنجزت اليوم بالتفصيل).
class DailyReportForm extends StatefulWidget {
  final AppUser user;
  final DailyReport? existing;
  const DailyReportForm({super.key, required this.user, this.existing});

  @override
  State<DailyReportForm> createState() => _DailyReportFormState();
}

class _DailyReportFormState extends State<DailyReportForm> {
  final _fs = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _content;
  String? _projectId;
  String _projectName = '';
  String? _customerUid; // زبون المشروع/الموقع المختار (لعزل بيانات الزبون)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.existing?.content ?? '');
    _projectId = widget.existing?.projectId;
    _projectName = widget.existing?.projectName ?? '';
    _customerUid = widget.existing?.customerUid;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _fs.setDailyReport(DailyReport(
        id: '',
        uid: widget.user.uid,
        userName: widget.user.name,
        date: widget.existing?.date ?? DateTime.now(),
        content: _content.text.trim(),
        projectId: _projectId,
        projectName: _projectName,
        customerUid: _customerUid,
      ));
      if (mounted) {
        showSnack(context, 'تم حفظ تقرير اليوم ✓');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر حفظ التقرير: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// التسمية المعروضة/المخزّنة لمشروع تصميم (تُميّز مشاريع نفس الزبون بنوع العرض).
  String _designLabel(DesignProject p) {
    final base = p.ownerName.trim().isEmpty ? 'مشروع' : p.ownerName.trim();
    return p.offerType.trim().isEmpty ? base : '$base • ${p.offerType.trim()}';
  }

  /// التسمية المعروضة/المخزّنة لموقع تنفيذ (تتراجع لاسم الصاحب إن كان الاسم فارغاً).
  String _siteLabel(WorkSite s) {
    if (s.siteName.trim().isNotEmpty) return s.siteName.trim();
    return s.ownerName.trim().isEmpty ? 'موقع' : s.ownerName.trim();
  }

  /// منتقي ربط اختياري: مشاريع المصمم أو مواقع المنفّذ.
  /// التسمية المعروضة هي نفسها المخزّنة في `_projectName` (تطابق العرض/الفلترة)،
  /// ويُحقن عنصر مؤقّت للرابط الحالي إن لم يَرِد بعد من الـStream (عند التعديل).
  Widget _projectPicker() {
    final role = widget.user.role;
    if (role == UserRole.designEmployee) {
      return StreamBuilder<List<DesignProject>>(
        stream: _fs.projectsByDesigner(widget.user.uid),
        builder: (context, snap) {
          final projects = snap.data ?? const <DesignProject>[];
          final known = projects.any((p) => p.id == _projectId);
          final items = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
                value: null, child: Text('بدون ربط')),
            if (_projectId != null && !known)
              DropdownMenuItem<String?>(
                value: _projectId,
                child: Text(_projectName.isEmpty ? 'مشروع مرتبط' : _projectName,
                    overflow: TextOverflow.ellipsis),
              ),
            ...projects.map((p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(_designLabel(p), overflow: TextOverflow.ellipsis),
                )),
          ];
          return DropdownButtonFormField<String?>(
            initialValue: _projectId,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            decoration: const InputDecoration(
              labelText: 'ربط بمشروع (اختياري)',
              prefixIcon: Icon(Icons.link),
            ),
            items: items,
            onChanged: (id) => setState(() {
              _projectId = id;
              if (id == null) {
                _projectName = '';
                _customerUid = null;
              } else {
                final p = projects.firstWhere((p) => p.id == id);
                _projectName = _designLabel(p);
                _customerUid = p.customerUid;
              }
            }),
          );
        },
      );
    }
    if (role == UserRole.executionEmployee) {
      return StreamBuilder<List<WorkSite>>(
        stream: _fs.sitesByExecutor(widget.user.uid),
        builder: (context, snap) {
          final sites = snap.data ?? const <WorkSite>[];
          final known = sites.any((s) => s.id == _projectId);
          final items = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
                value: null, child: Text('بدون ربط')),
            if (_projectId != null && !known)
              DropdownMenuItem<String?>(
                value: _projectId,
                child: Text(_projectName.isEmpty ? 'موقع مرتبط' : _projectName,
                    overflow: TextOverflow.ellipsis),
              ),
            ...sites.map((s) => DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(_siteLabel(s), overflow: TextOverflow.ellipsis),
                )),
          ];
          return DropdownButtonFormField<String?>(
            initialValue: _projectId,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            decoration: const InputDecoration(
              labelText: 'ربط بموقع (اختياري)',
              prefixIcon: Icon(Icons.link),
            ),
            items: items,
            onChanged: (id) => setState(() {
              _projectId = id;
              if (id == null) {
                _projectName = '';
                _customerUid = null;
              } else {
                final s = sites.firstWhere((s) => s.id == id);
                _projectName = _siteLabel(s);
                _customerUid = s.customerUid;
              }
            }),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير اليوم')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اكتب ماذا أنجزت اليوم بالتفصيل:',
                    style: TextStyle(color: AppColors.creamDim, fontSize: 14)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _content,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    hintText:
                        'مثال: أنجزتُ تصميم الواجهة الرئيسية، وراجعتُ ملاحظات الزبون، وبدأتُ المخطط التنفيذي…',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اكتب تفاصيل ما أنجزته اليوم'
                      : null,
                ),
                const SizedBox(height: 16),
                _projectPicker(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.save),
                  label: const Text('حفظ التقرير'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
