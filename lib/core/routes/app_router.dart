import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/auth_shell_scaffold.dart';
import '../../features/inventory/domain/entities/inventory_item.dart';
import '../../features/inventory/presentation/pages/home_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/inventory/presentation/pages/item_form_page.dart';
import '../../features/inventory/presentation/pages/expiration_management_page.dart';
import '../../features/receipt/presentation/pages/receipt_scan_page.dart';
import '../../shared/layouts/mobile_shell_scaffold.dart';
import '../firebase/auth_session_providers.dart';
import '../firebase/firebase_providers.dart';
import 'route_names.dart';

/// Global navigator key for root navigator
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Listenable helper for GoRouter that triggers redirects on auth or user profile changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // 1. Listen to Firebase Auth state changes
    final auth = _ref.read(firebaseAuthProvider);
    final authSub = auth.authStateChanges().listen((_) => notifyListeners());
    _ref.onDispose(authSub.cancel);

    // 2. Listen to User document changes in Firestore (role/isActive updates)
    _ref.listen(currentUserDocStreamProvider, (_, _) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  final routerNotifier = RouterNotifier(ref);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: kIsWeb
        ? (auth.currentUser != null
              ? AppRouteNames.adminDashboard
              : AppRouteNames.adminLogin)
        : (auth.currentUser != null ? AppRouteNames.home : AppRouteNames.auth),
    debugLogDiagnostics: kDebugMode,
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final user = auth.currentUser;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      final isAdminRoute = location.startsWith('/admin');
      final isAuthRoute =
          location == AppRouteNames.auth ||
          location == AppRouteNames.forgotPassword ||
          location == AppRouteNames.adminLogin;

      // 1. Unauthenticated Guard (Immediate check, no waiting for Firestore admin stream)
      if (!isLoggedIn) {
        if (isAdminRoute && location != AppRouteNames.adminLogin) {
          return AppRouteNames.adminLogin;
        }
        if (!isAdminRoute && !isAuthRoute) {
          return AppRouteNames.auth;
        }
        return null;
      }

      // 2. Authenticated: Check Admin permission for Web Admin Domain ONLY
      if (isAdminRoute) {
        final isAdminAsync = ref.read(isAdminProvider);
        if (isAdminAsync.isLoading) {
          return null; // Wait briefly only if accessing an admin route
        }
        final isAdmin = isAdminAsync.value ?? false;
        final isAdminLogin = location == AppRouteNames.adminLogin;

        // Block non-admins from admin routes
        if (!isAdmin && !isAdminLogin) {
          return AppRouteNames.adminLogin;
        }

        // If authenticated admin visits admin login, redirect to dashboard
        if (isAdmin && isAdminLogin) {
          return AppRouteNames.adminDashboard;
        }

        return null;
      }

      // 3. Authenticated user visiting mobile Auth routes -> Redirect to Home
      if (isAuthRoute) {
        return AppRouteNames.home;
      }

      return null;
    },
    errorBuilder: (context, state) =>
        _NotFoundScreen(uri: state.uri.toString(), error: state.error),
    routes: [
      // ==========================================
      // 📱 MOBILE ROUTES
      // ==========================================
      GoRoute(
        path: AppRouteNames.auth,
        name: 'auth',
        builder: (context, state) => const AuthShellScaffold(child: AuthPage()),
      ),
      GoRoute(
        path: AppRouteNames.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) =>
            const AuthShellScaffold(child: ForgotPasswordPage()),
      ),
      GoRoute(
        path: AppRouteNames.notifications,
        name: 'notifications',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Notifications (FEFO Warnings)'),
      ),
      GoRoute(
        path: AppRouteNames.profileDetail,
        name: 'profileDetail',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Profile Detail (Edit Profile)'),
      ),
      GoRoute(
        path: AppRouteNames.membership,
        name: 'membership',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Membership (Free / Premium)'),
      ),
      GoRoute(
        path: AppRouteNames.paymentHistory,
        name: 'paymentHistory',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Payment History'),
      ),
      GoRoute(
        path: AppRouteNames.itemForm,
        name: 'itemForm',
        builder: (context, state) {
          final itemToEdit = state.extra as InventoryItem?;
          return ItemFormPage(itemToEdit: itemToEdit);
        },
      ),

      // Mobile Bottom Navigation Tabs (StatefulShellRoute)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MobileShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRouteNames.home,
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          // Tab 2: Inventory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRouteNames.inventory,
                name: 'inventory',
                builder: (context, state) => const InventoryPage(),
                routes: [
                  GoRoute(
                    path: AppRouteNames.expirationManagement,
                    name: 'expirationManagement',
                    builder: (context, state) => const ExpirationManagementPage(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Scan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRouteNames.scan,
                name: 'scan',
                builder: (context, state) => const ReceiptScanPage(),
              ),
            ],
          ),
          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRouteNames.profile,
                name: 'profile',
                builder: (context, state) => const _PlaceholderScreen(
                  title: 'Profile Tab (Account & Settings)',
                ),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // 💻 WEB ADMIN ROUTES
      // ==========================================
      GoRoute(
        path: AppRouteNames.adminLogin,
        name: 'adminLogin',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Admin Login'),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return _AdminShellScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRouteNames.adminDashboard,
            name: 'adminDashboard',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Admin Dashboard (Statistics)'),
          ),
          GoRoute(
            path: AppRouteNames.adminUsers,
            name: 'adminUsers',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Admin Users Management'),
          ),
          GoRoute(
            path: AppRouteNames.adminMemberships,
            name: 'adminMemberships',
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Admin Memberships Configuration',
            ),
          ),
          GoRoute(
            path: AppRouteNames.adminAiUsage,
            name: 'adminAiUsage',
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Admin AI Usage & Quota Monitoring',
            ),
          ),
          GoRoute(
            path: AppRouteNames.adminShelfLifeRules,
            name: 'adminShelfLifeRules',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Admin Shelf-Life Rules'),
          ),
          GoRoute(
            path: AppRouteNames.adminPayments,
            name: 'adminPayments',
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Admin Payments & Transactions',
            ),
          ),
        ],
      ),
    ],
  );
});

// Scaffold layout with Sidebar Navigation for Web Admin (6 Modules)
class _AdminShellScaffold extends StatelessWidget {
  final Widget child;

  const _AdminShellScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 900,
            selectedIndex: _calculateSelectedIndex(context),
            onDestinationSelected: (index) =>
                _onDestinationSelected(index, context),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.card_membership_outlined),
                selectedIcon: Icon(Icons.card_membership),
                label: Text('Memberships'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: Text('AI Usage'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: Text('Shelf-life Rules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payment_outlined),
                selectedIcon: Icon(Icons.payment),
                label: Text('Payments'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRouteNames.adminUsers)) return 1;
    if (location.startsWith(AppRouteNames.adminMemberships)) return 2;
    if (location.startsWith(AppRouteNames.adminAiUsage)) return 3;
    if (location.startsWith(AppRouteNames.adminShelfLifeRules)) return 4;
    if (location.startsWith(AppRouteNames.adminPayments)) return 5;
    return 0;
  }

  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRouteNames.adminDashboard);
        break;
      case 1:
        context.go(AppRouteNames.adminUsers);
        break;
      case 2:
        context.go(AppRouteNames.adminMemberships);
        break;
      case 3:
        context.go(AppRouteNames.adminAiUsage);
        break;
      case 4:
        context.go(AppRouteNames.adminShelfLifeRules);
        break;
      case 5:
        context.go(AppRouteNames.adminPayments);
        break;
    }
  }
}

// 404 Not Found Screen for Invalid URLs
class _NotFoundScreen extends StatelessWidget {
  final String uri;
  final Exception? error;

  const _NotFoundScreen({required this.uri, this.error});

  @override
  Widget build(BuildContext context) {
    debugPrint('[FOORA 404] state.uri = $uri | error = $error');
    final isWebAdmin = kIsWeb || uri.startsWith('/admin');

    return Scaffold(
      appBar: AppBar(title: const Text('404 - Không tìm thấy trang')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Đường dẫn không tồn tại',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Không tìm thấy màn hình cho URL: $uri',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (isWebAdmin) {
                    context.go(AppRouteNames.adminDashboard);
                  } else {
                    context.go(AppRouteNames.home);
                  }
                },
                icon: const Icon(Icons.home),
                label: Text(isWebAdmin ? 'Về Admin Dashboard' : 'Về Trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends ConsumerWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(firebaseAuthProvider).currentUser?.email ?? '';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (userEmail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Đang đăng nhập: $userEmail',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(AppRouteNames.auth);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
