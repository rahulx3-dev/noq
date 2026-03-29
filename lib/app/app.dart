import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qcutapp/app/app_router.dart';
import 'package:qcutapp/app/app_theme.dart';

import 'package:qcutapp/core/providers/loading_provider.dart';
import 'package:qcutapp/core/widgets/app_loading_overlay.dart';
import 'package:qcutapp/features/student/providers/student_alert_provider.dart';
import 'package:qcutapp/core/widgets/app_notification_banner.dart';

/// Root application widget.
class QCutApp extends ConsumerWidget {
  const QCutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isLoading = ref.watch(globalLoadingProvider);
    final alert = ref.watch(studentAlertProvider);

    return MaterialApp.router(
      title: 'noq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              if (child != null) child,
              if (alert != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: AppNotificationBanner(
                    title: alert.title,
                    body: alert.body,
                    token: alert.token,
                    type: alert.type,
                    onDismiss: () =>
                        ref.read(studentAlertProvider.notifier).dismiss(),
                    onViewOrder: () {
                      ref.read(studentAlertProvider.notifier).dismiss();
                      router.push('/student/token');
                    },
                    onViewMenu: () {
                      ref.read(studentAlertProvider.notifier).dismiss();
                      router.push('/student/dashboard');
                    },
                  ),
                ),
              if (isLoading) const AppLoadingOverlay(),
            ],
          ),
        );
      },
    );
  }
}
