# Stockly mobile — Project Structure

Moved from `stockly-backend/docs/architecture/structure.md` §3 when the repositories were split (ADR-0011 in stockly-backend). Theme tokens come from `brand/` in this folder.

## Flutter app

```
stockly-mobile/
├── pubspec.yaml
├── analysis_options.yaml         # very_good_analysis
├── l10n.yaml
├── lib/
│   ├── main.dart                 # ProviderScope + bootstrap
│   ├── app.dart                  # MaterialApp.router, theme, locale
│   ├── l10n/                     # app_ar.arb, app_en.arb (generated code ignored)
│   ├── core/
│   │   ├── config/               # env (API base URL via --dart-define)
│   │   ├── network/              # dio_client, auth_interceptor, refresh_interceptor, error_mapper
│   │   ├── error/                # Failure (sealed), Result
│   │   ├── theme/                # tokens.dart (from brand/), app_theme.dart, stockly_colors.dart (ThemeExtension)
│   │   ├── router/               # go_router, auth redirect, route names
│   │   ├── storage/              # secure_token_storage, preferences (language, theme)
│   │   ├── offline/              # drift database, pending_scans table, scan_sync_worker
│   │   ├── media/                # image picker + compression (max 2000px, ~80% JPEG)
│   │   └── widgets/              # AsyncStateView, EmptyState, ErrorState, MoneyText, QuantityText
│   └── features/
│       ├── splash/presentation/              # animated splash (brand spec)
│       ├── auth/
│       │   ├── data/        datasources/ models/ repositories/
│       │   ├── domain/      entities/ repositories/ usecases/
│       │   └── presentation/ providers/ screens/ widgets/
│       ├── products/        (same 3 layers)  # list, detail, add/edit, units, adjust
│       ├── invoices/        (same 3 layers)  # capture, queue, processing, review, confirm, history
│       ├── sales/           (same 3 layers)  # quick sale, barcode lookup
│       ├── dashboard/       (same 3 layers)  # summary, low stock, expiring soon
│       └── settings/        (same 3 layers)  # language, theme, shop members, logout
└── test/                     # mirrors lib/
```
