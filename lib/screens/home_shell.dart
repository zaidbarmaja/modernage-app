import 'package:flutter/material.dart';

import '../theme.dart';
import 'dashboard_screen.dart';
import 'design_screen.dart';
import 'execution_screen.dart';
import 'reports_screen.dart';
import 'fingerprint_screen.dart';
import 'client/client_portal.dart';

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _items = const <_NavItem>[
    _NavItem('لوحة التحكم', Icons.dashboard_outlined),
    _NavItem('موظفي التصميم', Icons.brush_outlined),
    _NavItem('موظفي التنفيذ', Icons.construction_outlined),
    _NavItem('التقارير', Icons.bar_chart_outlined),
    _NavItem('نظام البصمة', Icons.fingerprint),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    final pages = <Widget>[
      DashboardScreen(onOpenTab: _select, onOpenClient: _openClient),
      const DesignScreen(),
      const ExecutionScreen(),
      const ReportsScreen(),
      const FingerprintScreen(),
    ];

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              items: _items,
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              onClient: _openClient,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_items[_index].label),
        actions: [
          IconButton(
            tooltip: 'بوابة العملاء',
            onPressed: _openClient,
            icon: const Icon(Icons.public),
          ),
        ],
      ),
      drawer: Drawer(
        child: _Sidebar(
          items: _items,
          index: _index,
          embedded: true,
          onSelect: (i) {
            setState(() => _index = i);
            Navigator.of(context).pop();
          },
          onClient: () {
            Navigator.of(context).pop();
            _openClient();
          },
        ),
      ),
      body: body,
    );
  }

  void _openClient() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClientPortal()),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onClient;
  final bool embedded;

  const _Sidebar({
    required this.items,
    required this.index,
    required this.onSelect,
    required this.onClient,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: embedded ? null : 276,
      color: AppColors.green800,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/logo.png',
                        width: 46, height: 46, fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const CircleAvatar(
                              radius: 23,
                              backgroundColor: AppColors.green500,
                              child: Text('ع',
                                  style: TextStyle(color: Colors.white)),
                            )),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عصر الحداثة',
                            style: TextStyle(
                                color: AppColors.cream50,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                        Text('نظام المهام والتقارير',
                            style: TextStyle(
                                color: AppColors.cream300, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.green700, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _navTile(items[i].icon, items[i].label, i == index,
                        () => onSelect(i)),
                  const Divider(color: AppColors.green700),
                  _navTile(Icons.public, 'بوابة العملاء', false, onClient),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(IconData icon, String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: active ? AppColors.green600 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: active ? Colors.white : AppColors.cream300, size: 20),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.white : AppColors.cream100,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
