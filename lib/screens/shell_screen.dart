import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers.dart';
import 'login_screen.dart';
import '../pages/dashboard_page.dart';
import '../pages/users_page.dart';
import '../pages/posts_page.dart';
import '../pages/boosts_page.dart';
import '../pages/reports_page.dart';
import '../pages/support_page.dart';
import '../pages/payouts_page.dart';
import '../pages/balances_page.dart';
import '../pages/earnings_page.dart';
import '../pages/operations_page.dart';

class AdminShell extends HookConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final user = useState<models.User?>(null);

    useEffect(() {
      () async {
        isLoading.value = true;
        error.value = null;
        try {
          final me = await account.get();
          user.value = me;
        } on AppwriteException {
          // Not logged in – stay on login view.
        } finally {
          isLoading.value = false;
        }
      }();
      return null;
    }, const []);

    if (isLoading.value) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.value == null) {
      return AdminLoginScreen(
        onLoggedIn: (me) => user.value = me,
      );
    }

    return AdminHomeScreen(
      currentUser: user.value!,
      onLogout: () async {
        await account.deleteSessions();
        user.value = null;
      },
    );
  }
}

class AdminHomeScreen extends HookConsumerWidget {
  const AdminHomeScreen({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  final models.User currentUser;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    final selectedIndex = useState(0);

    final pages = [
      DashboardPage(tables: tables),
      UsersPage(tables: tables),
      PostsPage(tables: tables),
      BoostsPage(tables: tables),
      ReportsPage(tables: tables),
      SupportPage(tables: tables),
      PayoutsPage(tables: tables),
      BalancesPage(tables: tables),
      EarningsPage(tables: tables),
      OperationsPage(tables: tables),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('XapZap Admin Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                currentUser.email,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              onLogout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Row(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
              ),
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: selectedIndex.value,
                  onDestinationSelected: (i) => selectedIndex.value = i,
                  labelType: NavigationRailLabelType.all,
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
                      icon: Icon(Icons.article_outlined),
                      selectedIcon: Icon(Icons.article),
                      label: Text('Posts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.campaign_outlined),
                      selectedIcon: Icon(Icons.campaign),
                      label: Text('Boosts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.report_gmailerrorred_outlined),
                      selectedIcon: Icon(Icons.report),
                      label: Text('Reports'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.support_agent_outlined),
                      selectedIcon: Icon(Icons.support_agent),
                      label: Text('Support'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.payments_outlined),
                      selectedIcon: Icon(Icons.payments),
                      label: Text('Payouts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Balances'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.attach_money_outlined),
                      selectedIcon: Icon(Icons.attach_money),
                      label: Text('Earnings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.developer_mode_outlined),
                      selectedIcon: Icon(Icons.developer_mode),
                      label: Text('Operations'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[selectedIndex.value]),
        ],
      ),
    );
  }
}
