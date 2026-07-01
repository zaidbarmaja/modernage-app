import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';
import 'add_employee_form.dart';

/// تبويب إدارة المستخدمين: بحث + عرض الجميع + تغيير الدور/القسم + تفعيل/تعطيل.
/// التعطيل يمنع الدخول فوراً (عبر AuthGate الذي يستمع لملف المستخدم لحظياً).
class UsersManagementTab extends StatefulWidget {
  final String currentUid;
  const UsersManagementTab({super.key, required this.currentUid});

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _search = TextEditingController();
  String _query = '';
  // المهمة #3: تبديل سريع بين عرض الطاقم الداخلي وعرض الزبائن (للأدمن).
  bool _showCustomers = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('الموظفون'),
                  icon: Icon(Icons.engineering)),
              ButtonSegment(
                  value: true,
                  label: Text('الزبائن'),
                  icon: Icon(Icons.people)),
            ],
            selected: {_showCustomers},
            onSelectionChanged: (s) =>
                setState(() => _showCustomers = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رقم الهاتف…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _fs.allUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              var users = snapshot.data ?? [];
              // تصفية حسب التبويب: طاقم داخلي (غير الزبائن) أو زبائن.
              users = users
                  .where((u) => _showCustomers
                      ? u.role == UserRole.customer
                      : u.role != UserRole.customer)
                  .toList();
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                users = users
                    .where((u) =>
                        u.name.toLowerCase().contains(q) ||
                        u.phone.contains(q))
                    .toList();
              }
              if (users.isEmpty) {
                return EmptyState(
                  message: _query.isNotEmpty
                      ? 'لا نتائج للبحث.'
                      : (_showCustomers
                          ? 'لا يوجد زبائن بعد.'
                          : 'لا يوجد موظفون بعد.'),
                  icon: Icons.people_outline,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: users.length,
                itemBuilder: (context, i) => _userTile(users[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _fmtMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Widget _userTile(AppUser u) {
    final isSelf = u.uid == widget.currentUid;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: u.active ? AppColors.oliveDark : AppColors.surfaceAlt,
          child: Icon(u.role.icon,
              color: u.active ? AppColors.cream : AppColors.creamDim),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                u.name.isEmpty ? u.phone : u.name,
                style: TextStyle(
                  color: u.active ? AppColors.cream : AppColors.creamDim,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!u.active) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('معطّل',
                    style: TextStyle(color: AppColors.danger, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${u.role.labelAr}'
          '${u.role == UserRole.executionEmployee && u.workCategory.isPools ? ' • ${u.workCategory.labelAr}' : ''}'
          '${u.department != Department.none ? ' • ${u.department.labelAr}' : ''}'
          '${u.phone.isNotEmpty ? '\n${u.phone}' : ''}'
          '${u.isEmployee ? '\nالدوام: ${u.hasCustomSchedule ? '${_fmtMin(u.workStartMin!)}–${_fmtMin(u.workEndMin!)}' : 'غير محدّد'}' : ''}'
          '${u.contact.isNotEmpty ? '\n${u.contact}' : ''}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.5),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          color: AppColors.surfaceAlt,
          icon: const Icon(Icons.more_vert, color: AppColors.creamDim),
          onSelected: (v) {
            if (v == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddEmployeeForm(existing: u)),
              );
            } else if (v == 'rename') {
              _changeName(u);
            } else if (v == 'role') {
              _editRole(context, u);
            } else if (v == 'toggle') {
              _toggleActive(u);
            } else if (v == 'attendance') {
              _viewAttendance(context, u);
            } else if (v == 'impersonate') {
              _impersonate(u);
            } else if (v == 'password') {
              _resetPassword(u);
            } else if (v == 'delete') {
              _deleteUser(u);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('تعديل المعلومات',
                  style: TextStyle(color: AppColors.cream)),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Text('تغيير الاسم',
                  style: TextStyle(color: AppColors.cream)),
            ),
            const PopupMenuItem(
              value: 'role',
              child:
                  Text('تغيير الدور', style: TextStyle(color: AppColors.cream)),
            ),
            const PopupMenuItem(
              value: 'password',
              child: Text('إعادة تعيين كلمة المرور',
                  style: TextStyle(color: AppColors.cream)),
            ),
            if (!isSelf)
              const PopupMenuItem(
                value: 'impersonate',
                child: Text('الدخول إلى الحساب',
                    style: TextStyle(color: AppColors.oliveBright)),
              ),
            if (u.isEmployee)
              const PopupMenuItem(
                value: 'attendance',
                child: Text('عرض الحضور',
                    style: TextStyle(color: AppColors.cream)),
              ),
            if (!isSelf)
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  u.active ? 'تعطيل الحساب' : 'تفعيل الحساب',
                  style: TextStyle(
                      color: u.active ? AppColors.danger : AppColors.success),
                ),
              ),
            if (!isSelf)
              const PopupMenuItem(
                value: 'delete',
                child: Text('حذف الحساب نهائياً',
                    style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }

  /// يدخل الأدمن إلى حساب المستخدم ويتصرّف كأنه هو (مع شريط عودة دائم).
  Future<void> _impersonate(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('الدخول إلى الحساب',
            style: TextStyle(color: AppColors.cream)),
        content: Text(
          'ستدخل إلى حساب «${u.name.isEmpty ? u.phone : u.name}» (${u.role.labelAr}) '
          'وتتصرّف كأنك هو — أي إجراء (تقرير/مهمة/وصل…) يُنسب إليه.\n'
          'يمكنك العودة لحساب الإدارة في أي وقت من الشريط العلوي.',
          style: const TextStyle(color: AppColors.creamDim, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('دخول')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<AuthController>().impersonate(u);
      // ننتقل مباشرة لصفحة الحساب: نُغلق شاشات الإدارة المكدّسة فتظهر صفحة
      // المستخدم (CustomerHome للزبون) التي يبنيها الموجّه بعد تبديل الجلسة.
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _viewAttendance(BuildContext context, AppUser u) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('حضور ${u.name}')),
          body: AttendanceView(user: u, interactive: false),
        ),
      ),
    );
  }

  Future<void> _deleteUser(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('حذف الحساب', style: TextStyle(color: AppColors.cream)),
        content: Text(
          'حذف حساب «${u.name}» نهائياً؟\n'
          'سيُحذف الحساب وبيانات دخوله من قاعدة البيانات ويتحرّر '
          'رقم الهاتف/اسم الدخول لإعادة استخدامه. لا يمكن التراجع.',
          style: const TextStyle(color: AppColors.creamDim, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائي',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _fs.deleteUserPermanently(u.uid);
      if (mounted) showSnack(context, 'تم حذف حساب ${u.name} نهائياً ✓');
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر حذف الحساب.', error: true);
    }
  }

  /// المدير يعيّن كلمة مرور جديدة لأي حساب (تُخزَّن كتجزئة في Firestore،
  /// ويصبح الدخول بها مباشرةً عبر مسار كلمة مرور Firestore).
  Future<void> _resetPassword(AppUser u) async {
    final ctrl = TextEditingController();
    var obscure = true;
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('كلمة مرور: ${u.name.isEmpty ? u.phone : u.name}',
              style: const TextStyle(color: AppColors.cream, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل كلمة المرور الجديدة (4 خانات على الأقل) لهذا الحساب — '
                'يدخل بها مباشرة بعد الحفظ.',
                style: TextStyle(color: AppColors.creamDim, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppColors.cream),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setLocal(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (newPass == null) return;
    // نتحقّق ونجزّئ نفس القيمة (مقصوصة) كي يطابقها الدخول الذي لا يقصّ.
    // تُقبل أي كلمة مرور (أرقام أو حروف) بطول 4 خانات على الأقل.
    final pass = newPass.trim();
    if (pass.length < 4) {
      if (mounted) {
        showSnack(context, 'كلمة المرور 4 خانات على الأقل.', error: true);
      }
      return;
    }
    try {
      final c = AuthService.makeCredential(u.uid, pass);
      await _fs.setUserPassword(u.uid, c['salt']!, c['hash']!);
      if (mounted) {
        showSnack(context, 'تم تعيين كلمة مرور جديدة لـ ${u.name} ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تعيين كلمة المرور.', error: true);
    }
  }

  /// تغيير اسم أي حساب (موظف أو زبون) — يحدّث الاسم ومفاتيح الدخول كي يبقى
  /// الدخول بالاسم/الهاتف صحيحاً.
  Future<void> _changeName(AppUser u) async {
    final ctrl = TextEditingController(text: u.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تغيير الاسم', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            labelText: 'الاسم الجديد',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('إلغاء', style: TextStyle(color: AppColors.creamDim)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null) return;
    final name = newName.trim();
    if (name.isEmpty) {
      if (mounted) showSnack(context, 'أدخل الاسم.', error: true);
      return;
    }
    try {
      await _fs.updateUser(u.uid, {
        'name': name,
        'loginNames': _auth.loginKeys(name, u.phone),
      });
      if (mounted) showSnack(context, 'تم تغيير الاسم إلى $name ✓');
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تغيير الاسم.', error: true);
    }
  }

  Future<void> _toggleActive(AppUser u) async {
    try {
      await _fs.setUserActive(u.uid, !u.active);
      if (mounted) {
        showSnack(context,
            u.active ? 'تم تعطيل ${u.name} ✓' : 'تم تفعيل ${u.name} ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تغيير حالة الحساب.', error: true);
    }
  }

  Future<void> _editRole(BuildContext context, AppUser user) async {
    UserRole role = user.role;
    Department department =
        user.department == Department.none ? Department.civil : user.department;
    WorkCategory category = user.workCategory;

    bool needsDept(UserRole r) =>
        r == UserRole.designEmployee || r == UserRole.executionEmployee;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('تغيير دور: ${user.name}',
              style: const TextStyle(color: AppColors.cream, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                isExpanded: true,
                dropdownColor: AppColors.surfaceAlt,
                decoration: const InputDecoration(
                  labelText: 'الدور',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: UserRole.values
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r.labelAr)))
                    .toList(),
                onChanged: (v) => setLocal(() => role = v ?? role),
              ),
              if (needsDept(role)) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<Department>(
                  initialValue: department,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'القسم (لجدول البصمة)',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: const [Department.civil, Department.architectural]
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.labelAr),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => department = v ?? department),
                ),
              ],
              if (role == UserRole.executionEmployee) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<WorkCategory>(
                  initialValue: category,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'قسم التنفيذ',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: WorkCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c, child: Text(c.labelAr)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim)),
            ),
            ElevatedButton(
              onPressed: () async {
                final dept = needsDept(role) ? department : Department.none;
                await _fs.updateUserRole(user.uid, role, dept,
                    workCategory: category);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSnack(context, 'تم تحديث دور ${user.name} ✓');
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
