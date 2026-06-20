import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/work_site.dart';
import 'ui.dart';

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
        leading: CircleAvatar(
          backgroundColor: AppColors.oliveDark,
          child: Icon(site.category.icon, color: AppColors.cream),
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
            if (site.category.isPools)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.oliveBright.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(site.category.labelAr,
                    style: const TextStyle(
                        color: AppColors.oliveBright,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            Text('صاحب المشروع: ${site.ownerName}',
                style: const TextStyle(color: AppColors.creamDim)),
            if (site.address.isNotEmpty)
              Text(site.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.creamDim)),
            if (showExecutor && site.executorsLabel.isNotEmpty)
              Text(
                  '${site.executorCount > 1 ? 'المنفّذون' : 'المنفّذ'}: ${site.executorsLabel}',
                  style: const TextStyle(color: AppColors.oliveBright)),
            if (showExecutor && !site.hasExecutor)
              const Text('لم يُسنَد لمنفّذ بعد',
                  style: TextStyle(color: AppColors.warning)),
            if (site.autoProgressPercent != null) ...[
              const SizedBox(height: 8),
              ProgressBar(
                  percent: site.autoProgressPercent!,
                  label: 'نسبة الإنجاز التقديرية'),
            ],
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
