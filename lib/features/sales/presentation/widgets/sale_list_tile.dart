import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One sale of the history (design §11): when, how many lines, total.
class SaleListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final SaleListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: context.spacing.md,
      ),
      leading: Icon(Icons.receipt_rounded, color: context.colors.mint),
      title: Text(ltrIsolate(DateFormatter.dateTime(item.createdAt, language))),
      subtitle: Text(l10n.salesItemCount(item.itemCount)),
      trailing: MoneyText(item.totalAmount),
    );
  }
}
