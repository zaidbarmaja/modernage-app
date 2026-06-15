import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';

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
  final _search = TextEditingController();
  String _query = '';

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
                  message:
                      _query.isEmpty ? 'لا يوجد مستخدمون بعد.' : 'لا نتائج للبحث.',
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
          '${u.department != Department.none ? ' • ${u.department.labelAr}' : ''}'
          '${u.phone.isNotEmpty ? '\n${u.phone}' : ''}'
          '${u.isEmployee ? '\nالدوام: ${_fmtMin(u.workStartMin)}–${_fmtMin(u.workEndMin)}' : ''}'
          '${u.contact.isNotEmpty ? '\n${u.contact}' : ''}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.5),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          color: AppColors.surfaceAlt,
          icon: const Icon(Icons.more_vert, color: AppColors.creamDim),
          onSelected: (v) {
            if (v == 'role') {
              _editRole(context, u);
            } else if (v == 'toggle') {
              _toggleActive(u);
            } else if (v == 'attendance') {
              _viewAttendance(context, u);
            } else if (v == 'delete') {
              _deleteUser(u);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'role',
              child:
                  Text('تغيير الدور', style: TextStyle(color: AppColors.cream)),
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
          'لن يستطيع الدخول أو الوصول لأي بيانات. لا يمكن التراجع.',
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
      await _fs.deleteUser(u.uid);
      if (mounted) showSnack(context, 'تم حذف حساب ${u.name} ✓');
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر حذف الحساب.', error: true);
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
                await _fs.updateUserRole(user.uid, role, dept);
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
