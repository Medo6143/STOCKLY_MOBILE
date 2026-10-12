import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/panel/fake_backend_panel_notifier.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Debug-only controls of the fake backend (design §12.1), opened by a long
/// press on the version text in settings in fake mode. Codes are shown as
/// their wire strings: they are what QA looks up in the contract.
class FakeBackendPanel extends ConsumerWidget {
  const new({required this.shopId, required this.onShopSuspended, super.key});

  /// The signed-in shop, the one "suspend the shop" suspends.
  final String shopId;

  /// Called after the shop was suspended, so the app can ask the server.
  final VoidCallback onShopSuspended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final panel = ref.watch(fakeBackendPanelProvider);
    final notifier = ref.read(fakeBackendPanelProvider.notifier);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
        children: [
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
            child: Text(
              l10n.fakePanelTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SwitchListTile(
            title: Text(l10n.fakePanelOffline),
            value: panel.offline,
            onChanged: (value) => notifier.setOffline(offline: value),
          ),
          ListTile(
            title: Text(l10n.fakePanelFailNext),
            subtitle: DropdownButton<ApiErrorCode?>(
              isExpanded: true,
              value: panel.failNextWith,
              onChanged: notifier.failNextWith,
              items: [
                DropdownMenuItem(child: Text(l10n.fakePanelFailNextNone)),
                for (final code in ApiErrorCode.values)
                  DropdownMenuItem(
                    value: code,
                    child: Text(code.wire, textDirection: TextDirection.ltr),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: Text(l10n.fakePanelExpireToken),
            onTap: notifier.expireAccessToken,
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(l10n.fakePanelSuspendShop),
            onTap: () {
              notifier.suspendShop(shopId);
              Navigator.of(context).pop();
              onShopSuspended();
            },
          ),
          SwitchListTile(
            title: Text(l10n.fakePanelLockout),
            value: panel.lockoutEnabled,
            onChanged: (value) => notifier.setLockout(enabled: value),
          ),
          SwitchListTile(
            title: Text(l10n.fakePanelRateLimit),
            value: panel.rateLimitEnabled,
            onChanged: (value) => notifier.setRateLimit(enabled: value),
          ),
        ],
      ),
    );
  }
}
