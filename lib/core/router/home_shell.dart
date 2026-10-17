import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The tab bar around the shell branches (Sprint 3: products, invoices,
/// settings). `NavigationBar` mirrors itself in RTL. The invoices tab shows
/// how many scans wait to upload (design §6.6).
class HomeShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingScanCountProvider).value ?? 0;
    Widget badged(IconData icon) => Badge(
      isLabelVisible: pending > 0,
      label: Text('$pending'),
      child: Icon(icon),
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
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
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
