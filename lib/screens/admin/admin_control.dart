import 'package:flutter/material.dart';


import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/daily_report.dart';
import '../../models/design_project.dart';
import '../../models/receipt.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../../widgets/user_dropdown.dart';
import 'accounts_receipts_screen.dart';
import 'accounts_screen.dart';
import 'add_customer_form.dart';
import 'add_employee_form.dart';
import 'admin_notifications.dart';
import 'company_settings_screen.dart';
import 'electronic_payments.dart';
import 'users_management.dart';

/// لوحة تحكّم الإدارة (تبويب الإعدادات): مدخل موحّد للتحكّم بالحسابات وبيانات
/// قاعدة البيانات وإعدادات الشركة.
class AdminControlHub extends StatelessWidget {
  final AppUser user;
  const AdminControlHub({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const PageHeader(
          title: 'الإعدادات ولوحة التحكّم',
          subtitle: 'الحسابات + البيانات + إعدادات الشركة',
          icon: Icons.settings,
        ),
        const SizedBox(height: 14),
        _hubCard(
          context,
          icon: Icons.receipt_long,
          title: 'الحسابات (الوصولات الإلكترونية)',
          subtitle:
              'كل وصولات القبض والصرف (من الموظفين والمدير) + إصدار وصل جديد + مشاركة',
          page: AccountsReceiptsScreen(user: user),
        ),
        _hubCard(
          context,
          icon: Icons.groups,
          title: 'أرصدة الزبائن',
          subtitle: 'أرصدة الزبائن الحاليين (كم دفع كل زبون وكم رصيده)',
          page: const AccountsScreen(),
        ),
        _hubCard(
          context,
          icon: Icons.person_add_alt_1,
          title: 'إضافة حساب جديد',
          subtitle: 'إضافة موظف (تصميم / تنفيذ / محاسبة) أو زبون',
          onTap: () => _showAddAccountSheet(context),
        ),
        _hubCard(
          context,
          icon: Icons.bolt,
          title: 'الدفع الإلكتروني',
          subtitle: 'وصولات القبض/الصرف التلقائية من موظفي التنفيذ (بفلتر الزبون)',
          page: const ElectronicPaymentsScreen(),
        ),
        _hubCard(
          context,
          icon: Icons.manage_accounts,
          title: 'إدارة الحسابات',
          subtitle:
              'كل الحسابات: تعديل، الأدوار، إعادة تعيين كلمة المرور، تفعيل/تعطيل، حذف',
          page: Scaffold(
            appBar: AppBar(title: const Text('إدارة الحسابات')),
            body: UsersManagementTab(currentUid: user.uid),
          ),
        ),
        _hubCard(
          context,
          icon: Icons.notifications_active,
          title: 'الإشعارات',
          subtitle: 'إرسال تنبيه لكل المستخدمين + استعراض كل الإشعارات',
          page: AdminNotificationsScreen(admin: user),
        ),
        _hubCard(
          context,
          icon: Icons.storage,
          title: 'إدارة البيانات',
          subtitle: 'حذف المشاريع والمواقع والوصولات + إعادة إسناد المصممين',
          page: const DataManagementScreen(),
        ),
        _hubCard(
          context,
          icon: Icons.apartment,
          title: 'إعدادات الشركة',
          subtitle: 'موقع البصمة المعتمد ونطاقه + وقت الدوام الموحّد',
          page: Scaffold(
            appBar: AppBar(title: const Text('إعدادات الشركة')),
            body: const CompanySettingsTab(),
          ),
        ),
      ],
    );
  }

  Widget _hubCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      Widget? page,
      VoidCallback? onTap}) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.oliveDark,
          child: Icon(icon, color: AppColors.cream),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.creamDim, height: 1.4)),
        trailing: const Icon(Icons.chevron_left, color: AppColors.creamDim),
        onTap: onTap ??
            () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => page!)),
      ),
    );
  }

  /// نافذة اختيار نوع الحساب المراد إضافته (موظف أو زبون).
  void _showAddAccountSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.engineering, color: AppColors.oliveBright),
              title: const Text('إضافة موظف',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('مصمم / تنفيذ / محاسبة',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEmployeeForm()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.oliveBright),
              title: const Text('إضافة زبون',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('دخول بالهاتف ورمز الوصول (قراءة فقط)',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddCustomerForm()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// إدارة بيانات قاعدة البيانات (للمدير): حذف المشاريع/المواقع/الوصولات،
/// وإعادة إسناد مشاريع التصميم لمصمم آخر.
class DataManagementScreen extends StatelessWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة البيانات'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'المشاريع'),
              Tab(text: 'المواقع'),
              Tab(text: 'الوصولات'),
              Tab(text: 'البصمات'),
              Tab(text: 'التقارير'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProjectsManage(),
            _SitesManage(),
            _ReceiptsManage(),
            _AttendanceManage(),
            _ReportsManage(),
          ],
        ),
      ),
    );
  }
}

/// تأكيد حذف عام.
Future<bool> _confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('تأكيد الحذف', style: TextStyle(color: AppColors.cream)),
      content: Text('$message\nلا يمكن التراجع.',
          style: const TextStyle(color: AppColors.creamDim, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              const Text('إلغاء', style: TextStyle(color: AppColors.creamDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف نهائي',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return ok == true;
}

class _ProjectsManage extends StatelessWidget {
  const _ProjectsManage();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DesignProject>>(
      stream: fs.allProjects(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final projects = snap.data ?? const <DesignProject>[];
        if (projects.isEmpty) {
          return const EmptyState(
              message: 'لا توجد مشاريع تصميم.', icon: Icons.architecture);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: projects
              .map((p) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.architecture,
                          color: AppColors.oliveBright),
                      title: Text(p.ownerName,
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${p.offerType.isEmpty ? 'مشروع تصميم' : p.offerType}\n'
                        'المصمّم: ${p.designerName.isEmpty ? 'غير مُسنَد' : p.designerName}',
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.4),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        color: AppColors.surfaceAlt,
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.creamDim),
                        onSelected: (v) {
                          if (v == 'reassign') {
                            _reassignDesigner(context, fs, p);
                          } else if (v == 'delete') {
                            _deleteProject(context, fs, p);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'reassign',
                            child: Text('إعادة الإسناد لمصمم',
                                style: TextStyle(color: AppColors.cream)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف المشروع',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteProject(
      BuildContext context, FirestoreService fs, DesignProject p) async {
    if (!await _confirmDelete(context,
        'حذف مشروع «${p.ownerName}» مع وصولاته وتقاريره اليومية؟ '
        'وستُفكّ مواقع التنفيذ المرتبطة به.')) {
      return;
    }
    try {
      await fs.deleteProjectCascade(p.id);
      if (context.mounted) showSnack(context, 'تم حذف المشروع وما يتبعه ✓');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر حذف المشروع.', error: true);
      }
    }
  }

  Future<void> _reassignDesigner(
      BuildContext context, FirestoreService fs, DesignProject p) async {
    // نبدأ بلا اختيار: تُلتقط القيمة حصراً من اختيار حيّ في القائمة، فلا يُحفظ
    // مصمّم قديم/محذوف عن طريق الخطأ. زرّ الحفظ معطّل حتى يُختار مصمّم صالح.
    String? uid;
    String name = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('إسناد مشروع «${p.ownerName}»',
              style: const TextStyle(color: AppColors.cream, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المصمّم الحالي: ${p.designerName.isEmpty ? 'غير مُسنَد' : p.designerName}',
                style: const TextStyle(color: AppColors.creamDim, height: 1.5),
              ),
              const SizedBox(height: 14),
              UserDropdown(
                role: UserRole.designEmployee,
                selectedUid: uid,
                label: 'المصمّم الجديد',
                icon: Icons.architecture,
                onChanged: (u) => setLocal(() {
                  uid = u?.uid;
                  name = u?.name ?? '';
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim)),
            ),
            ElevatedButton(
              onPressed: uid == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || uid == null) return;
    try {
      await fs.updateProject(
          p.id, {'designerUid': uid, 'designerName': name});
      if (context.mounted) {
        showSnack(context, 'تم إسناد المشروع إلى $name ✓');
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر إعادة الإسناد.', error: true);
      }
    }
  }
}

class _SitesManage extends StatelessWidget {
  const _SitesManage();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<WorkSite>>(
      stream: fs.allSites(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final sites = snap.data ?? const <WorkSite>[];
        if (sites.isEmpty) {
          return const EmptyState(
              message: 'لا توجد مواقع تنفيذ.', icon: Icons.location_city);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: sites
              .map((s) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_city,
                          color: AppColors.oliveBright),
                      title: Text(
                          s.siteName.isEmpty ? s.ownerName : s.siteName,
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'صاحب المشروع: ${s.ownerName}'
                        '${s.executorsLabel.isEmpty ? '' : '\nالمنفّذ: ${s.executorsLabel}'}',
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.4),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () => _deleteSite(context, fs, s),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteSite(
      BuildContext context, FirestoreService fs, WorkSite s) async {
    final label = s.siteName.isEmpty ? s.ownerName : s.siteName;
    if (!await _confirmDelete(context,
        'حذف موقع «$label» مع وصولاته وتقاريره وصرفياته وتسجيلات الدخول؟')) {
      return;
    }
    try {
      await fs.deleteSiteCascade(s.id);
      if (context.mounted) showSnack(context, 'تم حذف الموقع وما يتبعه ✓');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر حذف الموقع.', error: true);
      }
    }
  }
}

class _ReceiptsManage extends StatelessWidget {
  const _ReceiptsManage();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<Receipt>>(
      stream: fs.allReceipts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final receipts = snap.data ?? const <Receipt>[];
        if (receipts.isEmpty) {
          return const EmptyState(
              message: 'لا توجد وصولات.', icon: Icons.receipt_long);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: receipts
              .map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long,
                          color: AppColors.success),
                      title: Text(Fmt.money(r.amount),
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${r.ownerName.isEmpty ? (r.description.isEmpty ? 'وصل' : r.description) : r.ownerName}\n'
                        'رقم ${r.shortNo} • ${Fmt.date(r.date)}',
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.4),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () => _deleteReceipt(context, fs, r),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteReceipt(
      BuildContext context, FirestoreService fs, Receipt r) async {
    if (!await _confirmDelete(
        context, 'حذف وصل ${r.shortNo} بمبلغ ${Fmt.money(r.amount)}؟')) {
      return;
    }
    try {
      await fs.deleteReceipt(r.id);
      if (context.mounted) showSnack(context, 'تم حذف الوصل ✓');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر حذف الوصل.', error: true);
      }
    }
  }
}

/// حذف سجلات البصمة (النظام الجديد: attendance بحقل uid وTimestamp).
class _AttendanceManage extends StatelessWidget {
  const _AttendanceManage();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<AttendanceRecord>>(
      stream: fs.allAttendance(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل البصمات.', icon: Icons.error_outline);
        }
        final recs = snap.data ?? const <AttendanceRecord>[];
        if (recs.isEmpty) {
          return const EmptyState(
              message: 'لا توجد بصمات.', icon: Icons.fingerprint);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: recs
              .map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.fingerprint,
                          color: AppColors.oliveBright),
                      title: Text(
                          '${r.userName.isEmpty ? 'موظف' : r.userName} • ${Fmt.date(r.checkIn)}',
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'دخول ${Fmt.time(r.checkIn)} • خروج '
                          '${r.checkOut == null ? 'داخل الآن' : Fmt.time(r.checkOut)}',
                          style: const TextStyle(color: AppColors.creamDim)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () => _delete(context, fs, r),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, FirestoreService fs, AttendanceRecord r) async {
    if (!await _confirmDelete(context,
        'حذف بصمة «${r.userName}» بتاريخ ${Fmt.date(r.checkIn)}؟')) {
      return;
    }
    try {
      await fs.deleteAttendance(r.id);
      if (context.mounted) showSnack(context, 'تم حذف البصمة ✓');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر حذف البصمة.', error: true);
      }
    }
  }
}

/// حذف التقارير اليومية.
class _ReportsManage extends StatelessWidget {
  const _ReportsManage();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DailyReport>>(
      stream: fs.allDailyReports(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final reports = (snap.data ?? const <DailyReport>[]).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        if (reports.isEmpty) {
          return const EmptyState(
              message: 'لا توجد تقارير.', icon: Icons.event_busy);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: reports
              .map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_note,
                          color: AppColors.oliveBright),
                      title: Text(r.userName.isEmpty ? 'موظف' : r.userName,
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${Fmt.date(r.date)}'
                        '${r.projectName.isNotEmpty ? ' • ${r.projectName}' : ''}',
                        style: const TextStyle(color: AppColors.creamDim),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () => _delete(context, fs, r),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, FirestoreService fs, DailyReport r) async {
    if (!await _confirmDelete(context,
        'حذف تقرير «${r.userName}» بتاريخ ${Fmt.date(r.date)}؟')) {
      return;
    }
    try {
      await fs.deleteDailyReport(r.id);
      if (context.mounted) showSnack(context, 'تم حذف التقرير ✓');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'تعذّر حذف التقرير.', error: true);
      }
    }
  }
}
