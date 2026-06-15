import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import '../../widgets/project_tasks.dart';
import '../receipt.dart';

/// بوابة الزبون — متابعة مشروعه داخل التطبيق (لا متجر):
/// يسجّل الزبون دخوله برقم هاتفه فيرى مشاريعه: نسبة الإنجاز، الأيام المتبقية،
/// الحالة، الميزانية، الوصولات، والصور.
class ClientPortal extends StatefulWidget {
  const ClientPortal({super.key});
  @override
  State<ClientPortal> createState() => _ClientPortalState();
}

/// آخر 10 أرقام من الهاتف لمطابقة الصيغ المختلفة (0/964/+964).
String phoneKey(String raw) {
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length <= 10 ? d : d.substring(d.length - 10);
}

class _ClientPortalState extends State<ClientPortal> {
  String? _phone;

  @override
  void initState() {
    super.initState();
    final c = Session.getCustomer();
    final p = (c?['phone'] ?? '').toString();
    if (p.isNotEmpty) _phone = p;
  }

  Future<void> _login(String phone) async {
    await Session.setCustomer({'phone': phone});
    setState(() => _phone = phone);
  }

  Future<void> _logout() async {
    await Session.setCustomer(null);
    setState(() => _phone = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream50,
      appBar: AppBar(
        title: const Text('متابعة مشروعي — عصر الحداثة'),
        actions: [
          if (_phone != null)
            IconButton(
              tooltip: 'خروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: _phone == null
          ? _ClientLogin(onLogin: _login)
          : _ClientProjects(phone: _phone!),
    );
  }
}

// ===================== تسجيل الدخول برقم الهاتف =====================
class _ClientLogin extends StatefulWidget {
  final Future<void> Function(String phone) onLogin;
  const _ClientLogin({required this.onLogin});
  @override
  State<_ClientLogin> createState() => _ClientLoginState();
}

class _ClientLoginState extends State<_ClientLogin> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png',
                  height: 64,
                  errorBuilder: (context, error, stack) => const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.green600,
                        child: Text('ع',
                            style: TextStyle(color: Colors.white)),
                      )),
              const SizedBox(height: 12),
              const Text('متابعة مشروعك',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('أدخل رقم هاتفك المسجّل لدى الشركة لعرض مشاريعك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSoft)),
              const SizedBox(height: 18),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'رقم الهاتف'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('عرض مشاريعي'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final p = _phone.text.trim();
    if (p.isEmpty) return;
    widget.onLogin(p);
  }
}

// ===================== قائمة مشاريع الزبون =====================
class _ClientProjects extends StatelessWidget {
  final String phone;
  const _ClientProjects({required this.phone});

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  @override
  Widget build(BuildContext context) {
    final key = phoneKey(phone);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.designProjects.snapshots(),
      builder: (context, dSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Db.executionProjects.snapshots(),
          builder: (context, eSnap) {
            if (dSnap.hasError || eSnap.hasError) {
              return const Center(
                  child: Text('تعذّر تحميل مشاريعك. تأكّد من الإنترنت.'));
            }
            if (!dSnap.hasData || !eSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data, bool isExec})>[];
            for (final p in dSnap.data!.docs) {
              if (phoneKey('${p.data()['ownerPhone'] ?? ''}') == key) {
                items.add((ref: p.reference, data: p.data(), isExec: false));
              }
            }
            for (final p in eSnap.data!.docs) {
              if (phoneKey('${p.data()['ownerPhone'] ?? ''}') == key) {
                items.add((ref: p.reference, data: p.data(), isExec: true));
              }
            }

            if (items.isEmpty) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.folder_off_outlined,
                        size: 48, color: AppColors.muted),
                    const SizedBox(height: 12),
                    const Text('لا توجد مشاريع مرتبطة برقمك',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                        'تأكّد من إدخال نفس الرقم المسجّل لدى الشركة ($phone)، أو تواصل مع الإدارة.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [AppColors.green800, AppColors.green600],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مرحبًا بك 👋',
                            style: TextStyle(
                                color: AppColors.cream200, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('لديك ${items.length} مشروع',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final it in items) _card(context, it.ref, it.data, it.isExec),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> d, bool isExec) {
    final pct = taskProgressPercent((d['tasks'] as List?) ?? const []);
    final status = (d['status'] ?? 'قيد التنفيذ').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClientProjectDetail(reference: ref, isExec: isExec),
      )),
      child: Container(
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
                Text(isExec ? '🏗️' : '🎨',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(isExec ? 'مشروع تنفيذ' : 'مشروع تصميم',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                StatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
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
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_remaining(d)} يوم متبقٍ · اضغط لعرض التفاصيل',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ===================== تفاصيل مشروع الزبون (قراءة فقط) =====================
class ClientProjectDetail extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> reference;
  final bool isExec;
  const ClientProjectDetail(
      {required this.reference, required this.isExec, super.key});

  int _intOf(dynamic v) =>
      (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream50,
      appBar: AppBar(title: const Text('تفاصيل مشروعي')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('تم حذف هذا المشروع.'));
          }
          final d = snap.data!.data()!;
          final status = (d['status'] ?? 'قيد التنفيذ').toString();
          final currency = (d['currency'] ?? 'IQD').toString();
          final total = _intOf(d['totalAmount']);
          final received = _intOf(d['receivedAmount'] ?? d['paidAmount']);
          final due = total - received;
          final tasks = (d['tasks'] as List?) ?? const [];
          final photos = (d['photos'] as List?) ?? const [];
          final documents = (d['documents'] as List?) ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الرأس
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['ownerName'] ?? 'مشروعي').toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(isExec ? 'مشروع تنفيذ' : 'مشروع تصميم',
                          style: const TextStyle(color: AppColors.cream200)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        StatusBadge(status),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.green600,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('${_remaining(d)} يوم متبقٍ',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // نسبة الإنجاز والمهام (قراءة فقط)
                _section('مراحل العمل ونسبة الإنجاز',
                    ProjectTasks(
                        reference: reference,
                        tasks: tasks,
                        editable: false,
                        showDays: isExec)),
                const SizedBox(height: 16),

                // الميزانية
                _section(
                  'الميزانية',
                  Column(
                    children: [
                      _row('كامل المبلغ', moneyLabel(total, currency)),
                      _row('المدفوع', moneyLabel(received, currency)),
                      const Divider(),
                      _row('المتبقّي', moneyLabel(due, currency),
                          highlight: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // الوصولات
                _section(
                  'وصولات الدفع',
                  ReceiptsList(
                    projectId: reference.id,
                    projectCollection: reference.parent.id,
                    projectName: (d['ownerName'] ?? '').toString(),
                    canManage: false,
                  ),
                ),
                const SizedBox(height: 16),

                // الصور والملفات
                if (photos.isNotEmpty || documents.isNotEmpty)
                  _section(
                    'الصور والملفات',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in photos)
                          Chip(
                              avatar: const Text('🖼️'),
                              label: Text('${(f as Map)['name'] ?? 'صورة'}'),
                              backgroundColor: AppColors.cream100),
                        for (final f in documents)
                          Chip(
                              avatar: const Text('📄'),
                              label: Text('${(f as Map)['name'] ?? 'ملف'}'),
                              backgroundColor: AppColors.cream100),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.green900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color:
                        highlight ? AppColors.green900 : AppColors.textSoft,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w500)),
            Text(v,
                style: TextStyle(
                    fontSize: highlight ? 18 : 15,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppColors.green700 : AppColors.text)),
          ],
        ),
      );
}
