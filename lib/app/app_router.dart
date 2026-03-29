import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/models/user_profile_model.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_link_sent_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/verify_success_screen.dart';
import '../features/student/student_shell.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/student_cart_screen.dart';
import '../features/student/screens/student_checkout_screen.dart';
import '../features/student/screens/student_orders_screen.dart';
import '../features/student/screens/student_token_screen.dart';
import '../features/student/screens/student_profile_screen.dart';
import '../features/student/screens/student_edit_profile_screen.dart';
import '../features/student/screens/student_notifications_screen.dart';
import '../features/student/screens/student_change_password_screen.dart';
import '../features/student/screens/student_no_network_screen.dart';
import '../features/staff/staff_shell.dart';
import '../features/staff/screens/staff_dashboard_screen.dart';
import '../features/staff/screens/staff_kitchen_screen.dart';
import '../features/staff/screens/staff_profile_screen.dart';
import '../features/staff/screens/kitchen_tv_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_release_screen.dart';
import '../features/admin/screens/admin_manage_menu_screen.dart';
import '../features/admin/screens/admin_orders_screen.dart';
import '../features/admin/screens/admin_reports_screen.dart';
import '../features/admin/screens/admin_profile_screen.dart';
import '../features/admin/screens/admin_canteen_details_screen.dart';
import '../features/admin/screens/admin_session_scheduler_screen.dart';
import '../features/admin/screens/admin_slot_defaults_screen.dart';
import '../features/admin/screens/admin_staff_management_screen.dart';
import '../features/admin/screens/admin_live_menu_screen.dart';
import '../features/admin/screens/admin_edit_profile_screen.dart';
import '../features/admin/screens/admin_notifications_screen.dart';
import '../features/admin/screens/admin_no_network_screen.dart';
import '../features/admin/admin_shell.dart';

// Themes
import 'themes/auth_theme.dart';
import 'themes/student_theme.dart';
import 'themes/staff_theme.dart';
import 'themes/admin_theme.dart';

import '../core/providers/connectivity_provider.dart';

/// A notifier that notifies GoRouter when auth state or connectivity changes without rebuilding the router itself.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(userProfileProvider, (_, _) => notifyListeners());
    _ref.listen(connectivityStreamProvider, (_, _) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      // Use ref.read here to get values without triggering a router rebuild
      final authState = ref.read(authStateProvider);
      final userProfile = ref.read(userProfileProvider);
      final isOffline = ref.read(isOfflineProvider);

      final user = authState.value;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      final isNoNetworkRoute = location.contains('/no-network');

      // Check connectivity first
      if (isOffline && !isNoNetworkRoute) {
        // Redirect to appropriate offline screen
        final profile = userProfile.valueOrNull;
        if (profile?.role == UserRole.admin) {
          return '/admin/no-network';
        }
        return '/student/no-network';
      }

      // If online but on no-network screen, redirect back based on role
      if (!isOffline && isNoNetworkRoute) {
        final profile = userProfile.valueOrNull;
        if (profile?.role == UserRole.admin) return '/admin/dashboard';
        if (profile?.role == UserRole.staff) return '/staff/dashboard';
        return '/student/dashboard';
      }

      debugPrint(
        'ROUTER REDIRECT: location=$location, isLoggedIn=$isLoggedIn, profileLoading=${userProfile.isLoading}',
      );

      // Public screens
      if (location == '/splash') return null;

      final isAuthRoute =
          location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password' ||
          location == '/reset-link-sent';

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // Logic for logged in users
      final isEmailVerified = user.emailVerified;
      final isVerifyRoute =
          location == '/verify-email' || location == '/verify-success';

      // Load profile
      if (userProfile.isLoading) return null;
      final profile = userProfile.value;

      // If registered but no profile yet, wait or redirect to login (safeguard)
      if (profile == null) {
        if (isAuthRoute) return null;
        debugPrint('ROUTER: No profile found for logged in user, signing out.');
        // Optional: sign out if user logged in but no profile exists
        return '/login';
      }

      // If email not verified (for students only), force verification
      if (profile.role == UserRole.student && !isEmailVerified) {
        return isVerifyRoute ? null : '/verify-email';
      }

      // Block students from Kitchen TV
      if (profile.role == UserRole.student && location == '/kitchen-tv') {
        return '/student/dashboard';
      }

      // If verified or staff/admin, redirect away from auth/verify screens to dashboard
      if (isAuthRoute || isVerifyRoute) {
        switch (profile.role) {
          case UserRole.student:
            return '/student/dashboard';
          case UserRole.staff:
            return '/staff/dashboard';
          case UserRole.admin:
            return '/admin/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, s) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (context, s) =>
            Theme(data: AuthTheme.theme(context), child: const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, s) =>
            Theme(data: AuthTheme.theme(context), child: const SignupScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, s) => Theme(
          data: AuthTheme.theme(context),
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/reset-link-sent',
        builder: (context, s) {
          final email = s.extra as String? ?? '';
          return Theme(
            data: AuthTheme.theme(context),
            child: ResetLinkSentScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, s) => Theme(
          data: AuthTheme.theme(context),
          child: const VerifyEmailScreen(),
        ),
      ),
      GoRoute(
        path: '/verify-success',
        builder: (context, s) => Theme(
          data: AuthTheme.theme(context),
          child: const VerifySuccessScreen(),
        ),
      ),
      GoRoute(
        path: '/student/notifications',
        builder: (context, s) => Theme(
          data: StudentTheme.theme(context),
          child: const StudentNotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder: (context, s) => Theme(
          data: AdminTheme.theme(context),
          child: const AdminNotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/student/cart',
        builder: (context, s) => Theme(
          data: StudentTheme.theme(context),
          child: const StudentCartScreen(),
        ),
      ),
      GoRoute(
        path: '/student/checkout',
        builder: (context, s) {
          final extras = s.extra as Map<String, dynamic>? ?? {};
          return Theme(
            data: StudentTheme.theme(context),
            child: StudentCheckoutScreen(
              subtotal: extras['subtotal'] ?? 0.0,
              taxAmount: extras['taxAmount'] ?? 0.0,
              platformFee: extras['platformFee'] ?? 0.0,
              totalAmount: extras['totalAmount'] ?? 0.0,
            ),
          );
        },
      ),

      // Student Shell (Stateful for state preservation)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Theme(
            data: StudentTheme.theme(context),
            child: StudentShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/dashboard',
                builder: (context, s) => const StudentDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/orders',
                builder: (context, s) => const StudentOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/token',
                builder: (context, s) => const StudentTokenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/profile',
                builder: (context, s) => const StudentProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, s) => const StudentEditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'change-password',
                    builder: (context, s) =>
                        const StudentChangePasswordScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Staff Shell (Stateful)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Theme(
            data: StaffTheme.theme(context),
            child: StaffShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/dashboard',
                builder: (context, s) => const StaffDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/kitchen',
                builder: (context, s) => const StaffKitchenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/profile',
                builder: (context, s) => const StaffProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Admin Shell (Stateful)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Theme(
            data: AdminTheme.theme(context),
            child: AdminShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, s) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/release',
                builder: (context, s) => AdminReleaseScreen(
                  initialDate: s.extra as DateTime?,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/manage-menu',
                builder: (context, s) => const AdminManageMenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/live-menu',
                builder: (context, s) => const AdminLiveMenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/orders',
                builder: (context, s) => const AdminOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/reports',
                builder: (context, s) => const AdminReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile/session-scheduler',
                builder: (context, s) => const AdminSessionSchedulerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile/staff',
                builder: (context, s) => const AdminStaffManagementScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (context, s) => const AdminProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, s) => const AdminEditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'canteen-details',
                    builder: (context, s) => const AdminCanteenDetailsScreen(),
                  ),
                  GoRoute(
                    path: 'slot-defaults',
                    builder: (context, s) => const AdminSlotDefaultsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/student/no-network',
        builder: (context, s) => Theme(
          data: StudentTheme.theme(context),
          child: const StudentNoNetworkScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/no-network',
        builder: (context, s) => Theme(
          data: AdminTheme.theme(context),
          child: const AdminNoNetworkScreen(),
        ),
      ),
      GoRoute(
        path: '/kitchen-tv',
        builder: (context, s) => Theme(
          data: StaffTheme.theme(
            context,
          ), // Using staff theme for consistent branding
          child: const KitchenTvScreen(),
        ),
      ),
    ],
  );
});
