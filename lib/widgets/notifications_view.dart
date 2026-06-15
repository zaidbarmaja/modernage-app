import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/app_notification.dart';
import '../services/firestore_service.dart';
import 'ui.dart';

/// قائمة الإشعارات الداخلية (دخول المواقع وغيرها) للوحة الإدارة/المحاسبة.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<AppNotification>>(
      stream: fs.notificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyState(
              message: 'لا توجد إشعارات بعد.',
              icon: Icons.notifications_none);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final n = items[i];
            return Card(
              color: n.read
                  ? AppColors.surface
                  : AppColors.oliveDark.withValues(alpha: 0.45),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.olive,
                  child: Icon(
                    n.type == 'site_checkin'
                        ? Icons.location_on
                        : Icons.notifications,
                    color: AppColors.cream,
                  ),
                ),
                title: Text(n.title,
                    style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${n.body}\n${Fmt.dateTime(n.createdAt)}',
                  style: const TextStyle(
                      color: AppColors.creamDim, height: 1.5),
                ),
                isThreeLine: true,
                trailing: n.read
                    ? null
                    : const Icon(Icons.fiber_new, color: AppColors.warning),
                onTap: () {
                  if (!n.read) fs.markNotificationRead(n.id);
                },
              ),
            );
          },
        );
      },
    );
  }
}
