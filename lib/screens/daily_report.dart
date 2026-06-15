import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

String _kindLabel(String kind) => kind == 'execution' ? 'تنفيذ' : 'تصميم';

/// بطاقة التقرير اليومي للموظف: «ماذا فعلت اليوم؟» — تُضمّن في صفحة الموظف.
class DailyReportCard extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String kind; // design | execution
  const DailyReportCard({
    required this.employeeId,
    required this.employeeName,
    required this.kind,
    super.key,
  });

  @override
  State<DailyReportCard> createState() => _DailyReportCardState();
}

class _DailyReportCardState extends State<DailyReportCard> {
  final _text = TextEditingController();
  final List<dynamic> _photos = [];
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _saved = false;

  String get _dateKey => WorkTime.dateKey(DateTime.now());
  String get _docId => '${widget.employeeId}_$_dateKey';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await Db.dailyReports.doc(_docId).get();
      _text.text = (doc.data()?['text'] ?? '').toString();
      final ph = doc.data()?['photos'];
      if (ph is List) _photos.addAll(ph);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Db.saveDailyReport(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        kind: widget.kind,
        dateKey: _dateKey,
        text: _text.text.trim(),
        photos: _photos,
      );
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر حفظ التقرير. حاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attach() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.image,
    );
    if (res == null) return;
    final files = <UploadFile>[];
    for (final f in res.files) {
      if (f.bytes != null) files.add(UploadFile(f.name, f.bytes!));
    }
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await Db.uploadFiles(files, 'reports', 'daily_reports');
      _photos.addAll(uploaded);
      await _save(); // حفظ فوري حتى تبقى الصور
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر رفع الصور.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 20, color: AppColors.green700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('تقريري اليومي — ماذا فعلت اليوم؟',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(ArDate.fullArabicDate(DateTime.now()),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LoadingView(),
            )
          else ...[
            TextField(
              controller: _text,
              maxLines: 4,
              onChanged: (_) {
                if (_saved) setState(() => _saved = false);
              },
              decoration: const InputDecoration(
                hintText: 'اكتب ما أنجزته اليوم بالتفصيل…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            // الصور المرفقة بالتقرير
            if (_photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _photos)
                      if (p is Map && '${p['url'] ?? ''}'.isNotEmpty)
                        GestureDetector(
                          onTap: () => _viewImage('${p['url']}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network('${p['url']}',
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                        width: 70,
                                        height: 70,
                                        color: AppColors.cream100,
                                        child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: AppColors.muted))),
                          ),
                        ),
                  ],
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('حفظ التقرير'),
                ),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _attach,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('إرفاق صورة'),
                ),
                if (_saved)
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: AppColors.green600, size: 18),
                    SizedBox(width: 4),
                    Text('تم الحفظ',
                        style: TextStyle(
                            color: AppColors.green700,
                            fontWeight: FontWeight.w700)),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// صفحة إدارية: التقارير اليومية لجميع الموظفين في تاريخ محدّد (الافتراضي اليوم).
class DailyReportsScreen extends StatefulWidget {
  const DailyReportsScreen({super.key});
  @override
  State<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends State<DailyReportsScreen> {
  DateTime _date = DateTime.now();

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (p != null) setState(() => _date = p);
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = WorkTime.dateKey(_date);
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير اليومية للموظفين')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.dailyReports.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const MessageView(
                icon: Icons.cloud_off,
                title: 'تعذّر تحميل التقارير',
                color: AppColors.danger);
          }
          if (!snap.hasData) return const LoadingView();
          final recs = snap.data!.docs
              .where((r) => '${r.data()['date'] ?? ''}' == dayKey)
              .where((r) => '${r.data()['text'] ?? ''}'.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => '${a.data()['employeeName'] ?? ''}'
                .compareTo('${b.data()['employeeName'] ?? ''}'));

          return PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isToday ? 'تقارير اليوم' : 'تقارير يوم محدّد',
                                style: const TextStyle(
                                    color: AppColors.cream200, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(ArDate.fullArabicDate(_date),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Text('${recs.length} تقرير',
                          style: const TextStyle(color: AppColors.cream200)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event, size: 18),
                      label: const Text('اختر تاريخًا'),
                    ),
                    const SizedBox(width: 8),
                    if (!_isToday)
                      OutlinedButton(
                        onPressed: () => setState(() => _date = DateTime.now()),
                        child: const Text('اليوم'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: MessageView(
                      icon: Icons.note_alt_outlined,
                      title: 'لا توجد تقارير في هذا اليوم',
                      subtitle: 'اختر تاريخًا آخر، أو لم يرفع الموظفون تقاريرهم بعد.',
                    ),
                  )
                else
                  Column(
                    children: [for (final r in recs) _reportCard(r.data())],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> d) {
    final name = (d['name'] ?? d['employeeName'] ?? '').toString();
    final kind = (d['kind'] ?? '').toString();
    final text = (d['text'] ?? '').toString();
    final updated = d['updatedAt'];
    final time = (updated is Timestamp)
        ? ArDate.timeOnly(updated.toDate().toIso8601String())
        : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.cream100,
                child: Text(name.isEmpty ? 'ع' : name.characters.first,
                    style: const TextStyle(
                        color: AppColors.green700, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (kind.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cream200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_kindLabel(kind),
                      style: const TextStyle(fontSize: 11)),
                ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(time,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(height: 1.5)),
          Builder(builder: (context) {
            final ph = (d['photos'] as List?) ?? const [];
            if (ph.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in ph)
                    if (p is Map && '${p['url'] ?? ''}'.isNotEmpty)
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                                child: Image.network('${p['url']}')),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network('${p['url']}',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                  width: 80,
                                  height: 80,
                                  color: AppColors.cream100,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.muted))),
                        ),
                      ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
