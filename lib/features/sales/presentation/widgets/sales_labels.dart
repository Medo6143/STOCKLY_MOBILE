import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The message of a cart field issue; number issues reuse the server's
/// `Precision.*` texts (design §5.3).
String saleFieldIssueLabel(AppLocalizations l10n, SaleFieldIssue issue) =>
    switch (issue) {
      SaleFieldIssue.required => l10n.salesFieldRequired,
      SaleFieldIssue.invalidNumber => l10n.salesFieldInvalidNumber,
      SaleFieldIssue.tooManyDecimals => l10n.errorPrecisionTooManyDecimals,
      SaleFieldIssue.negative => l10n.errorPrecisionNegative,
      SaleFieldIssue.notPositive => l10n.errorPrecisionNotPositive,
      SaleFieldIssue.outOfRange => l10n.errorPrecisionOutOfRange,
    };

String saleDateRangeLabel(AppLocalizations l10n, SaleDateRange range) =>
    switch (range) {
      SaleDateRange.today => l10n.salesRangeToday,
      SaleDateRange.lastSevenDays => l10n.salesRangeSevenDays,
      SaleDateRange.all => l10n.salesRangeAll,
    };
