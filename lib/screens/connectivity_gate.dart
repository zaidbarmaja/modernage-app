import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/connectivity_service.dart';
import '../widgets/ui.dart';

/// بوابة الاتصال (المهمة #1): تحجب التطبيق كلياً عند غياب الإنترنت وتمنع
/// الدخول أو تخطّي الفحص، وتعرض رسالة واضحة مع علامة تحذير وزر إعادة محاولة.
class ConnectivityGate extends StatelessWidget {
  final Widget child;
  const ConnectivityGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    // ريثما يكتمل أول فحص: شاشة تحميل (تفادي وميض واجهة الدخول قبل معرفة الحالة).
    if (!conn.checked) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: LoadingView(),
      );
    }
    if (!conn.online) return const _OfflineScreen();
    return child;
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        size: 64, color: AppColors.warning),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'يرجى الاتصال بالانترنت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يمكن استخدام التطبيق بدون اتصال بالإنترنت.\n'
                    'يعتمد التطبيق على قاعدة البيانات السحابية مباشرةً، '
                    'تحقّق من اتصالك ثم أعد المحاولة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.creamDim,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final online = await context
                            .read<ConnectivityService>()
                            .recheck();
                        if (!online && context.mounted) {
                          showSnack(context, 'لا يزال الاتصال غير متاح.',
                              error: true);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
