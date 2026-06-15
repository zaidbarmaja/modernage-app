import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/work_site.dart';

/// بطاقة عرض موقع عمل للتنفيذ.
class SiteCard extends StatelessWidget {
  final WorkSite site;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool showExecutor;

  const SiteCard({
    super.key,
    required this.site,
    this.onTap,
    this.onEdit,
    this.showExecutor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.oliveDark,
          child: Icon(Icons.engineering, color: AppColors.cream),
        ),
        title: Text(
          site.siteName.isEmpty ? site.ownerName : site.siteName,
          style: const TextStyle(
              color: AppColors.cream, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('صاحب المشروع: ${site.ownerName}',
                style: const TextStyle(color: AppColors.creamDim)),
            if (site.address.isNotEmpty)
              Text(site.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.creamDim)),
            if (showExecutor && (site.executorName ?? '').isNotEmpty)
              Text('المنفّذ: ${site.executorName}',
                  style: const TextStyle(color: AppColors.oliveBright)),
            if (showExecutor && (site.executorName ?? '').isEmpty)
              const Text('لم يُسنَد لمنفّذ بعد',
                  style: TextStyle(color: AppColors.warning)),
          ],
        ),
        trailing: onEdit != null
            ? IconButton(
                icon: const Icon(Icons.edit, color: AppColors.creamDim),
                onPressed: onEdit,
              )
            : const Icon(Icons.chevron_left, color: AppColors.creamDim),
        onTap: onTap,
      ),
    );
  }
}
