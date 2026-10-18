import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Where deletion requests go (docs/privacy/privacy-policy.md). A
/// placeholder until the production contact is chosen before release.
abstract final class PrivacyContact {
  static const String email = 'privacy@stockly.example';
}

/// The privacy policy (brief mobile-6 §3.4), the app copy of
/// `docs/privacy/privacy-policy.md`. Static text from the ARB files, so the
/// only state is data; opened from the profile and the register screen,
/// signed in or not.
class PrivacyPolicyScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final sections = [
      _PolicySection(
        icon: Icons.inventory_2_outlined,
        title: l10n.privacyCollectedTitle,
        paragraphs: [
          l10n.privacyCollectedAccount,
          l10n.privacyCollectedShop,
          l10n.privacyCollectedPhotos,
          l10n.privacyCollectedSales,
        ],
      ),
      _PolicySection(
        icon: Icons.document_scanner_outlined,
        title: l10n.privacyProcessorsTitle,
        paragraphs: [l10n.privacyProcessorsBody],
      ),
      _PolicySection(
        icon: Icons.block_rounded,
        title: l10n.privacyNeverTitle,
        paragraphs: [l10n.privacyNeverBody],
      ),
      _PolicySection(
        icon: Icons.phone_android_rounded,
        title: l10n.privacyDeviceTitle,
        paragraphs: [l10n.privacyDeviceBody],
      ),
      _PolicySection(
        icon: Icons.delete_outline_rounded,
        title: l10n.privacyDeletionTitle,
        paragraphs: [
          l10n.privacyDeletionBody(ltrIsolate(PrivacyContact.email)),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: EntranceScope(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            spacing.md,
            spacing.sm,
            spacing.md,
            spacing.xl,
          ),
          children: [
            const Entrance(child: _PolicyIntro()),
            for (final (index, section) in sections.indexed) ...[
              SizedBox(height: spacing.md),
              Entrance(index: index + 1, child: section),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyIntro extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SurfaceCard(
      level: 2,
      radius: context.radii.xxl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingBadge(icon: Icons.privacy_tip_outlined, size: spacing.huge),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              AppLocalizations.of(context).privacyIntro,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: context.colors.ink);
    return SectionCard(
      title: title,
      icon: icon,
      children: [
        for (final paragraph in paragraphs) Text(paragraph, style: style),
      ],
    );
  }
}
