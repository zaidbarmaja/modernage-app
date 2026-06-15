import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/execution_report.dart';
import '../../models/expense.dart';
import '../../models/receipt.dart';
import '../../models/site_checkin.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/execution_widgets.dart';
import '../../widgets/ui.dart';
import 'expense_form.dart';
import 'receipt_detail_screen.dart';
import 'receipt_form.dart';
import 'report_form.dart';

/// تفاصيل موقع عمل: تسجيل الدخول للموقع + التقارير + السلف والصرفيات.
/// [interactive] = false عند العرض من المحاسبة/الزبون.
class SiteDetailScreen extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;

  const SiteDetailScreen({
    super.key,
    required this.site,
    required this.user,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(site.siteName.isEmpty ? site.ownerName : site.siteName),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.cream,
            unselectedLabelColor: AppColors.creamDim,
            indicatorColor: AppColors.oliveBright,
            tabs: [
              Tab(text: 'دخول الموقع', icon: Icon(Icons.location_on)),
              Tab(text: 'التقارير', icon: Icon(Icons.assignment)),
              Tab(text: 'الوصولات', icon: Icon(Icons.receipt_long)),
              Tab(text: 'المصاريف', icon: Icon(Icons.payments)),
            ],
          ),
        ),
        body: Column(
          children: [
            _SiteHeader(site: site),
            Expanded(
              child: TabBarView(
                children: [
                  _CheckinTab(
                      site: site, user: user, interactive: interactive),
                  _ReportsTab(
                      site: site, user: user, interactive: interactive),
                  _ReceiptsTab(
                      site: site, user: user, interactive: interactive),
                  _ExpensesTab(
                      site: site, user: user, interactive: interactive),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  final WorkSite site;
  const _SiteHeader({required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.oliveGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.cream, size: 20),
              const SizedBox(width: 6),
              Text('صاحب المشروع: ${site.ownerName}',
                  style: const TextStyle(
                      color: AppColors.cream, fontWeight: FontWeight.bold)),
            ],
          ),
          if (site.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFE9E3CF), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(site.address,
                      style: const TextStyle(color: Color(0xFFE9E3CF))),
                ),
              ],
            ),
          ],
          if (site.durationDays != null) ...[
            const SizedBox(height: 6),
            Text('مدة التنفيذ المتوقعة: ${site.durationDays} يوم',
                style: const TextStyle(color: Color(0xFFE9E3CF))),
          ],
        ],
      ),
    );
  }
}

/// تبويب تسجيل الدخول للموقع.
class _CheckinTab extends StatefulWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _CheckinTab(
      {required this.site, required this.user, required this.interactive});

  @override
  State<_CheckinTab> createState() => _CheckinTabState();
}

class _CheckinTabState extends State<_CheckinTab> {
  final _fs = FirestoreService();
  bool _busy = false;

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      final now = DateTime.now();
      await _fs.addSiteCheckin(SiteCheckin(
        id: '',
        siteId: widget.site.id,
        siteName: widget.site.siteName,
        ownerName: widget.site.ownerName,
        executorUid: widget.user.uid,
        executorName: widget.user.name,
        lat: loc.lat,
        lng: loc.lng,
        address: loc.address,
        time: now,
      ));
      // إشعار دخول الموقع للوحة الإدارة.
      await _fs.addNotification(AppNotification(
        id: '',
        type: 'site_checkin',
        title: 'دخول موقع: ${widget.site.ownerName}',
        body:
            '${widget.user.name} سجّل الدخول إلى الموقع${loc.address.isEmpty ? '' : ' (${loc.address})'} الساعة ${Fmt.time(now)}',
        fromUid: widget.user.uid,
        fromName: widget.user.name,
        relatedId: widget.site.id,
        lat: loc.lat,
        lng: loc.lng,
      ));
      if (mounted) {
        showSnack(context, 'تم تسجيل الدخول للموقع وإرسال إشعار للإدارة ✓');
      }
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تسجيل الدخول للموقع.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _checkIn,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.cream, strokeWidth: 2.2))
                    : const Icon(Icons.my_location),
                label: const Text('تسجيل الدخول للموقع (إرسال الموقع للإدارة)'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<SiteCheckin>>(
            stream: _fs.checkinsBySite(widget.site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyState(
                    message: 'لا توجد تسجيلات دخول لهذا الموقع بعد.',
                    icon: Icons.location_off);
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: items.map((c) => SiteCheckinTile(checkin: c)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// تبويب التقارير اليومية.
class _ReportsTab extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _ReportsTab(
      {required this.site, required this.user, required this.interactive});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Column(
      children: [
        if (interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReportForm(site: site, executor: user)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('تقرير يومي جديد'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<ExecutionReport>>(
            stream: fs.reportsBySite(site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyState(
                    message: 'لا توجد تقارير لهذا الموقع بعد.',
                    icon: Icons.assignment_outlined);
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children:
                    items.map((r) => ExecutionReportCard(report: r)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// تبويب الوصولات الإلكترونية: إجمالي المدفوعات + قائمة الوصولات (T-3.6/T-3.7).
class _ReceiptsTab extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _ReceiptsTab(
      {required this.site, required this.user, required this.interactive});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Column(
      children: [
        if (interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReceiptForm(site: site, executor: user)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('إصدار وصل إلكتروني'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Receipt>>(
            stream: fs.receiptsBySite(site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return const EmptyState(
                    message: 'تعذّر تحميل الوصولات.',
                    icon: Icons.error_outline);
              }
              final items = snapshot.data ?? [];
              num total = 0;
              for (final r in items) {
                total += r.amount;
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SectionCard(
                    title: 'إجمالي المدفوعات',
                    icon: Icons.summarize,
                    child: Column(
                      children: [
                        InfoRow(
                            label: 'عدد الوصولات', value: '${items.length}'),
                        InfoRow(
                            label: 'إجمالي المبالغ',
                            value: Fmt.money(total),
                            valueColor: AppColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const EmptyState(
                        message: 'لا توجد وصولات لهذا الموقع بعد.',
                        icon: Icons.receipt_long)
                  else
                    ...items.map((r) => _ReceiptTile(receipt: r)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// عنصر وصل واحد في القائمة — يفتح تفاصيله عند الضغط.
class _ReceiptTile extends StatelessWidget {
  final Receipt receipt;
  const _ReceiptTile({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: receipt.imageUrl.isEmpty
            ? const Icon(Icons.receipt, color: AppColors.oliveBright)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(receipt.imageUrl,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.receipt, color: AppColors.oliveBright)),
              ),
        title: Text(Fmt.money(receipt.amount),
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${receipt.description.isEmpty ? 'وصل' : receipt.description}\n'
          'رقم ${receipt.shortNo} • ${Fmt.date(receipt.date)}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.4),
        ),
        isThreeLine: true,
        trailing:
            const Icon(Icons.chevron_left, color: AppColors.creamDim),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReceiptDetailScreen(receipt: receipt)),
        ),
      ),
    );
  }
}

/// تبويب السلف والصرفيات.
class _ExpensesTab extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _ExpensesTab(
      {required this.site, required this.user, required this.interactive});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Column(
      children: [
        if (interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ExpenseForm(site: site, executor: user)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('إضافة سلفة / صرفية'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Expense>>(
            stream: fs.expensesBySite(site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final items = snapshot.data ?? [];
              num advances = 0, spending = 0;
              for (final e in items) {
                if (e.type == ExpenseType.advance) {
                  advances += e.amount;
                } else {
                  spending += e.amount;
                }
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SectionCard(
                    title: 'الإجمالي',
                    icon: Icons.summarize,
                    child: Column(
                      children: [
                        InfoRow(
                            label: 'إجمالي السلف',
                            value: Fmt.money(advances),
                            valueColor: AppColors.warning),
                        InfoRow(
                            label: 'إجمالي الصرفيات',
                            value: Fmt.money(spending),
                            valueColor: AppColors.danger),
                        InfoRow(
                            label: 'المجموع',
                            value: Fmt.money(advances + spending)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const EmptyState(
                        message: 'لا توجد سلف أو صرفيات بعد.',
                        icon: Icons.money_off)
                  else
                    ...items.map((e) => ExpenseTile(expense: e)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
