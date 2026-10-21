# Android release

How to build the signed release of Stockly and put it on the Play Console internal testing track.

## What the build enforces

`android/app/build.gradle.kts` stops a release build (`preReleaseBuild`) with a message starting `Stockly release build stopped` when:

- no signing is configured: neither `android/key.properties` nor the `STOCKLY_UPLOAD_*` environment variables (it **never** falls back to debug signing);
- `key.properties` is incomplete or its keystore file does not exist;
- `--dart-define=STOCKLY_API_BASE_URL` is missing or does not start with `https://`.

At run time the app checks the same again (`AppConfig.ensureValidFor`): a release build refuses any base URL that is not `https`.

Release builds are shrunk with R8 (`isMinifyEnabled`, `isShrinkResources`); keep rules for Flutter, drift/sqlite, `flutter_secure_storage` (Tink), `workmanager`, `mobile_scanner` (ML Kit) and `jni` are in `android/app/proguard-rules.pro`.

The version comes from `version:` in `pubspec.yaml` (`1.0.0+1` → versionName `1.0.0`, versionCode `1`). Raise the build number for every upload; Play rejects a versionCode it has seen. Keep `AppVersion` in `lib/core/config/app_version.dart` equal (a test checks it).

## 1. Create the upload keystore (once)

Use the JDK's `keytool`. Keep the keystore **outside the repository** and back it up with its passwords in the team password manager. `*.jks`, `*.keystore` and `key.properties` are git-ignored; never commit them.

```bash
keytool -genkeypair -v \
  -keystore ~/keys/stockly-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Enroll in **Play App Signing** when creating the app in the Play Console: Google keeps the app signing key, this keystore is only the upload key (it can be reset through Play support if lost).

## 2. Configure signing

**Locally:** copy `android/key.properties.example` to `android/key.properties` and fill it in. `storeFile` is relative to `android/` or absolute.

```properties
storeFile=/home/me/keys/stockly-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

**On CI:** store the keystore as a base64 secret and the passwords as secrets, decode the keystore to a temporary file in the job, and export:

| Variable | Value |
|---|---|
| `STOCKLY_UPLOAD_STORE_FILE` | absolute path of the decoded keystore |
| `STOCKLY_UPLOAD_STORE_PASSWORD` | keystore password |
| `STOCKLY_UPLOAD_KEY_ALIAS` | `upload` |
| `STOCKLY_UPLOAD_KEY_PASSWORD` | key password |

`key.properties`, when present, wins over the environment variables.

## 3. Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Play Console upload
flutter build appbundle --release --dart-define=STOCKLY_API_BASE_URL=https://<api host>

# Side-loaded test build
flutter build apk --release --dart-define=STOCKLY_API_BASE_URL=https://<api host>
```

The bundle is `build/app/outputs/bundle/release/app-release.aab`.

## 4. Play Console internal testing

1. Create the app (default language Arabic, app, free), complete **App content**: privacy policy URL (publish `docs/privacy/privacy-policy.md`), data safety (account info, shop data, photos sent to a processor, no ads, no data sold, deletion on request), target audience, content rating.
2. **Testing → Internal testing → Create new release**, upload the `.aab`, release notes in Arabic and English.
3. Add the testers' Google accounts to the internal testers list and share the opt-in link with the first shops.
4. Roll out; the build is available to testers within minutes.

## Checklist before each upload

- [ ] CI green on the commit (`.github/workflows/mobile.yml`: analyze, format, tests, coverage gate, debug build).
- [ ] `version:` build number raised; `AppVersion` matches.
- [ ] `STOCKLY_API_BASE_URL` points at the production API over `https`.
- [ ] Privacy contact placeholder replaced (`PrivacyContact.email`, `docs/privacy/privacy-policy.md`).
- [ ] Release built with the upload key (`keytool -printcert -jarfile app-release.apk` shows the upload certificate, not `Android Debug`).
- [ ] Installed on a real device from the internal track: register, sign in, scan, review, confirm, quick sale, Arabic and English, light and dark.
- [ ] No keystore, `key.properties` or password in `git status`.
