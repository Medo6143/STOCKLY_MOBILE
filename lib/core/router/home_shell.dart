import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/sales/presentation/providers/pending_sale_providers.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The tab bar around the shell branches: dashboard, products, invoices,
/// sales, profile. `NavigationBar` mirrors itself in RTL; its pill
/// indicator animates between tabs (instantly under reduce motion). The
/// invoices tab shows how many scans wait to upload (design §6.6). A sale
/// whose outcome is unknown reopens the quick sale, locked (design §6.8).
class HomeShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingScanCountProvider).value ?? 0;
    ref.listen(pendingSaleProvider, (previous, next) {
      final firstAnswer = previous == null || !previous.hasValue;
      if (firstAnswer && next.value != null) {
        context.goNamed(RouteNames.quickSale);
      }
    });
    Widget badged(IconData icon) => Badge(
      isLabelVisible: pending > 0,
      label: Text('$pending'),
      child: Icon(icon),
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        animationDuration: StocklyMotion.of(context)
            .resolve(context.durations.medium),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: l10n.navProducts,
          ),
          NavigationDestination(
            icon: badged(Icons.receipt_long_outlined),
            selectedIcon: badged(Icons.receipt_long),
            label: l10n.navInvoices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: const Icon(Icons.point_of_sale),
            label: l10n.navSales,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
