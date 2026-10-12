import 'package:flutter/material.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Exhaustive enum-to-text mappings of the settings screen (design §8.3).

String localePreferenceLabel(AppLocalizations l10n, LocalePreference value) =>
    switch (value) {
      LocalePreference.system => l10n.settingsLanguageSystem,
      LocalePreference.ar => l10n.settingsLanguageArabic,
      LocalePreference.en => l10n.settingsLanguageEnglish,
    };

String themeModeLabel(AppLocalizations l10n, ThemeMode value) =>
    switch (value) {
      ThemeMode.system => l10n.settingsThemeSystem,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.dark => l10n.settingsThemeDark,
    };

String shopRoleLabel(AppLocalizations l10n, ShopRole role) => switch (role) {
  ShopRole.owner => l10n.roleOwner,
  ShopRole.staff => l10n.roleStaff,
};

String settingsShopTypeLabel(AppLocalizations l10n, ShopType type) =>
    switch (type) {
      ShopType.pharmacy => l10n.shopTypePharmacy,
      ShopType.grocery => l10n.shopTypeGrocery,
      ShopType.mobileShop => l10n.shopTypeMobileShop,
      ShopType.other => l10n.shopTypeOther,
    };
