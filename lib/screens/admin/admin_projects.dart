import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/project_card.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../design/design_project_detail.dart';
import '../execution/site_detail_screen.dart';
import 'add_site_form.dart';

enum _ProjType { all, design, execution }

enum _DesignStatus { all, active, done, onHold }

/// عرض كل المشاريع (T-1.11): قائمة شاملة لمشاريع التصميم ومواقع التنفيذ معاً،
/// مع بحث وفلترة حسب النوع/الزبون/الحالة، والضغط يفتح التفاصيل الكاملة.
class AdminProjectsView extends StatefulWidget {
  final AppUser user;
  const AdminProjectsView({super.key, required this.user});

  @override
  State<AdminProjectsView> createState() => _AdminProjectsViewState();
}

class _AdminProjectsViewState extends State<AdminProjectsView> {
  final _fs = FirestoreService();
  final _search = TextEditingController();
  String _query = '';
  _ProjType _type = _ProjType.all;
  _DesignStatus _status = _DesignStatus.all;
  String? _customerUid; // null = كل الزبائن
  WorkCategory? _category; // null = كل أقسام التنفيذ

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchSearch(String owner, String extra) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return owner.toLowerCase().contains(q) || extra.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final showDesign = _type != _ProjType.execution;
    final showExec = _type != _ProjType.design;
    return Column(
      children: [
        _filtersBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              if (showDesign) _designSection(),
              if (showExec) _execSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'بحث باسم صاحب المشروع/الموقع…',
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
          const SizedBox(height: 10),
          Row(
            children: [
              _typeChip('الكل', _ProjType.all),
              const SizedBox(width: 8),
              _typeChip('تصميم', _ProjType.design),
              const SizedBox(width: 8),
              _typeChip('تنفيذ', _ProjType.execution),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _customerFilter()),
              if (_type != _ProjType.execution) ...[
                const SizedBox(width: 8),
                Expanded(child: _statusFilter()),
              ],
              if (_type != _ProjType.design) ...[
                const SizedBox(width: 8),
                Expanded(child: _categoryFilter()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryFilter() {
    return DropdownButtonFormField<WorkCategory?>(
      initialValue: _category,
      isExpanded: true,
      isDense: true,
      dropdownColor: AppColors.surfaceAlt,
      decoration: const InputDecoration(labelText: 'قسم التنفيذ'),
      items: [
        const DropdownMenuItem<WorkCategory?>(value: null, child: Text('الكل')),
        ...WorkCategory.values.map((c) => DropdownMenuItem<WorkCategory?>(
              value: c,
              child: Text(c.labelAr, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) => setState(() => _category = v),
    );
  }

  Widget _typeChip(String label, _ProjType t) {
    return ChoiceChip(
      label: Text(label),
      selected: _type == t,
      onSelected: (_) => setState(() => _type = t),
    );
  }

  Widget _customerFilter() {
    return StreamBuilder<List<AppUser>>(
      stream: _fs.usersByRole(UserRole.customer),
      builder: (context, snap) {
        final customers = snap.data ?? [];
        final value =
            customers.any((c) => c.uid == _customerUid) ? _customerUid : null;
        return DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.surfaceAlt,
          decoration: const InputDecoration(labelText: 'الزبون'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
            ...customers.map((c) => DropdownMenuItem<String?>(
                  value: c.uid,
                  child: Text(c.name.isEmpty ? c.phone : c.name,
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (v) => setState(() => _customerUid = v),
        );
      },
    );
  }

  Widget _statusFilter() {
    return DropdownButtonFormField<_DesignStatus>(
      initialValue: _status,
      isExpanded: true,
      isDense: true,
      dropdownColor: AppColors.surfaceAlt,
      decoration: const InputDecoration(labelText: 'الحالة'),
      items: const [
        DropdownMenuItem(value: _DesignStatus.all, child: Text('الكل')),
        DropdownMenuItem(value: _DesignStatus.active, child: Text('نشط')),
        DropdownMenuItem(value: _DesignStatus.done, child: Text('منجز')),
        DropdownMenuItem(value: _DesignStatus.onHold, child: Text('معلّق')),
      ],
      onChanged: (v) => setState(() => _status = v ?? _DesignStatus.all),
    );
  }

  Widget _designSection() {
    return StreamBuilder<List<DesignProject>>(
      stream: _fs.allProjects(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(20), child: LoadingView());
        }
        final list = (snap.data ?? <DesignProject>[]).where((p) {
          if (_customerUid != null && p.customerUid != _customerUid) {
            return false;
          }
          if (_status == _DesignStatus.active && p.remainingAmount <= 0) {
            return false;
          }
          if (_status == _DesignStatus.done && p.remainingAmount > 0) {
            return false;
          }
          if (_status == _DesignStatus.onHold && p.status != 'معلّق') {
            return false;
          }
          return _matchSearch(p.ownerName, p.details);
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('مشاريع التصميم (${list.length})', Icons.architecture),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد مشاريع تصميم مطابقة.',
                    style: TextStyle(color: AppColors.creamDim)),
              )
            else
              ...list.map((p) => ProjectCard(
                    project: p,
                    showDesigner: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DesignProjectDetail(
                              projectId: p.id, authorName: widget.user.name)),
                    ),
                  )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _execSection() {
    return StreamBuilder<List<WorkSite>>(
      stream: _fs.allSites(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(20), child: LoadingView());
        }
        final list = (snap.data ?? <WorkSite>[]).where((s) {
          if (_customerUid != null && s.customerUid != _customerUid) {
            return false;
          }
          if (_category != null && s.category != _category) {
            return false;
          }
          return _matchSearch(s.ownerName, s.siteName);
        }).toList();
        final title = _category == null
            ? 'مواقع التنفيذ (${list.length})'
            : '${_category!.labelAr} (${list.length})';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(title, Icons.location_city),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد مواقع تنفيذ مطابقة.',
                    style: TextStyle(color: AppColors.creamDim)),
              )
            else
              ...list.map((s) => SiteCard(
                    site: s,
                    showExecutor: true,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddSiteForm(existing: s)),
                    ),
                    // interactive: تتيح للإدارة إصدار الوصولات (قبض/صرف) وكتابة
                    // التقارير من داخل مشروع التنفيذ.
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteDetailScreen(
                            site: s, user: widget.user, interactive: true),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String t, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.oliveBright),
            const SizedBox(width: 6),
            Text(t,
                style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
