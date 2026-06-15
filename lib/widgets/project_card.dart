import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/design_project.dart';
import 'ui.dart';

/// بطاقة عرض مشروع تصميم بكل التفاصيل (صاحب المشروع، العرض، المبالغ، الأيام المتبقية).
class ProjectCard extends StatelessWidget {
  final DesignProject project;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool showDesigner;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onEdit,
    this.showDesigner = false,
  });

  @override
  Widget build(BuildContext context) {
    final remDays = project.remainingDays;
    final Color daysColor = remDays == null
        ? AppColors.creamDim
        : remDays < 0
            ? AppColors.danger
            : remDays <= 3
                ? AppColors.warning
                : AppColors.success;
    final String daysText = remDays == null
        ? 'غير محدد'
        : remDays < 0
            ? 'متأخر ${-remDays} يوم'
            : '$remDays يوم متبقٍ';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: AppColors.oliveBright),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.ownerName,
                      style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 20, color: AppColors.creamDim),
                      onPressed: onEdit,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(project.status, Icons.flag,
                      color: _statusColor(project.status)),
                  if (project.offerType.isNotEmpty)
                    _chip(project.offerType, Icons.local_offer),
                  _chip(daysText, Icons.event, color: daysColor),
                ],
              ),
              if (project.details.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 16, color: AppColors.oliveBright),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        project.details,
                        style: const TextStyle(
                            color: AppColors.creamDim, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
              if (project.nextPresentation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.oliveBright.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.oliveBright.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.upcoming_outlined,
                          size: 16, color: AppColors.oliveBright),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'العرض الموالي: ${project.nextPresentation}',
                          style: const TextStyle(
                              color: AppColors.cream, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (project.totalAmount > 0 || project.paidAmount > 0) ...[
                const Divider(height: 22),
                InfoRow(
                    label: 'المبلغ الكلي',
                    value: Fmt.money(project.totalAmount)),
                InfoRow(
                    label: 'المدفوع',
                    value: Fmt.money(project.paidAmount),
                    valueColor: AppColors.success),
                InfoRow(
                    label: 'المتبقي',
                    value: Fmt.money(project.remainingAmount),
                    valueColor: AppColors.warning),
              ],
              if (showDesigner) ...[
                const SizedBox(height: 6),
                InfoRow(label: 'المصمّم', value: project.designerName),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'منجز':
        return AppColors.success;
      case 'معلّق':
        return AppColors.warning;
      default:
        return AppColors.oliveBright;
    }
  }

  Widget _chip(String text, IconData icon, {Color? color}) {
    final c = color ?? AppColors.oliveBright;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: c, fontSize: 12.5)),
        ],
      ),
    );
  }
}
