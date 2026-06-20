import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/project_card.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../design/design_project_detail.dart';
import 'customer_site_screen.dart';

/// عرض شامل لزبون: الميزانية + مشاريع التصميم + مواقع التنفيذ.
/// يُستخدم في صفحة الزبون نفسه وفي درج المحاسبة.
class CustomerOverview extends StatelessWidget {
  final String customerUid;
  final String customerName;

  /// مستخدم لفتح تفاصيل الموقع (دائماً للعرض فقط هنا).
  final AppUser viewer;

  const CustomerOverview({
    super.key,
    required this.customerUid,
    required this.customerName,
    required this.viewer,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PageHeader(
          title: customerName.isEmpty ? 'الزبون' : customerName,
          subtitle: 'الميزانية وتفاصيل المشاريع',
          icon: Icons.person,
        ),
        const SizedBox(height: 12),
        // ميزانية الزبون من مشاريع التصميم.
        StreamBuilder<List<DesignProject>>(
          stream: fs.projectsByCustomer(customerUid),
          builder: (context, snapshot) {
            final projects = snapshot.data ?? [];
            num total = 0, paid = 0;
            for (final p in projects) {
              total += p.totalAmount;
              paid += p.paidAmount;
            }
            final remaining = total - paid;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'ميزانية الزبون',
                  icon: Icons.account_balance_wallet,
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      StatTile(
                          value: Fmt.money(total),
                          label: 'الكلي',
                          icon: Icons.summarize),
                      StatTile(
                          value: Fmt.money(paid),
                          label: 'المدفوع',
                          icon: Icons.price_check,
                          color: AppColors.success),
                      StatTile(
                          value: Fmt.money(remaining),
                          label: 'المتبقي',
                          icon: Icons.pending_actions,
                          color: AppColors.warning),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('مشاريع التصميم',
                    style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (projects.isEmpty)
                  const EmptyState(
                      message: 'لا توجد مشاريع تصميم مرتبطة.',
                      icon: Icons.architecture)
                else
                  ...projects.map((p) => ProjectCard(
                        project: p,
                        // الزبون يفتح التفاصيل الكاملة للقراءة فقط (T-4.1/T-4.2).
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DesignProjectDetail(
                                projectId: p.id, canEdit: false),
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text('مواقع التنفيذ',
            style: const TextStyle(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        StreamBuilder<List<WorkSite>>(
          stream: fs.sitesByCustomer(customerUid),
          builder: (context, snapshot) {
            final sites = snapshot.data ?? [];
            if (sites.isEmpty) {
              return const EmptyState(
                  message: 'لا توجد مواقع تنفيذ مرتبطة.',
                  icon: Icons.location_city);
            }
            // الزبون يرى بطاقات مواقعه (المالك/العنوان/المنفّذ). تفاصيل الموقع
            // التشغيلية للطاقم فقط؛ بيانات الزبون (وصولاته/تقاريره) في تبويباته.
            return Column(
              children: sites
                  .map((s) => SiteCard(
                        site: s,
                        showExecutor: true,
                        // الزبون يفتح تقدّم موقعه وتقاريره وصوره (قراءة فقط).
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerSiteScreen(
                                site: s, customerUid: customerUid),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
