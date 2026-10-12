import 'dart:io';

import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_controls.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// A fixed rate-limit window of one endpoint (contract v1.4: per client IP;
/// the fake has one client).
final class _FixedWindow {
  DateTime? start;
  int count = 0;
}

/// Fake A1–A5 (contract §4): validation, rotation on every refresh, token
/// families (reusing a revoked refresh token revokes that login's whole
/// family, other logins are unaffected), account lockout and the login and
/// register rate limits (v1.4).
final class FakeAuthHandler implements FakeHandler {
  new({
    required this._state,
    required this._config,
    required this._controls,
    required this._clock,
    required this._uuid,
    required this._problems,
  });

  final FakeBackendState _state;
  final FakeBackendConfig _config;
  final FakeBackendControls _controls;
  final Clock _clock;
  final UuidGenerator _uuid;
  final FakeProblems _problems;

  static const int _emailMax = 256;
  static const int _passwordMin = 8;
  static const int _passwordMax = 128;
  static const int _nameMax = 200;
  static const int _phoneMax = 30;
  static const int _deviceIdMax = 100;
  static const Set<String> _languages = {'ar', 'en'};
  static const String _defaultLanguage = 'ar';
  static const String _accessPrefix = 'fake-access.';
  static const String _refreshPrefix = 'fake-refresh.';

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _letter = RegExp('[A-Za-z؀-ۿ]');
  static final RegExp _digit = RegExp(r'\d');

  /// Arabic diacritics, superscript alef and tatweel: removed before the
  /// "name is blank" check, like the backend's Arabic normalization.
  static final RegExp _arabicMarks = RegExp('[ً-ٰٟـ]');

  final _FixedWindow _loginWindow = _FixedWindow();
  final _FixedWindow _registerWindow = _FixedWindow();

  @override
  List<FakeRoute> get routes => [
    FakeRoute('POST', ApiPaths.authRegister, _register),
    FakeRoute('POST', ApiPaths.authLogin, _login),
    FakeRoute('POST', ApiPaths.authRefresh, _refresh),
    FakeRoute('POST', ApiPaths.authLogout, _logout),
    FakeRoute('GET', ApiPaths.authMe, _me),
  ];

  /// The valid access token of [request], or `null` (→ `401`).
  FakeAccessToken? authenticate(FakeRequest request) {
    final token = _state.accessTokens[request.bearerToken];
    return token == null || !token.expiresAt.isAfter(_clock.now())
        ? null
        : token;
  }

  FakeResponse _register(FakeRequest request) {
    if (_throttle(request, _registerWindow) case final throttled?) {
      return throttled;
    }
    final body = request.jsonObject ?? const {};
    final language = request.language;
    final errors = <String, List<String>>{};
    final email = _requiredString(body, 'email', _emailMax, language, errors);
    if (email != null && !_email.hasMatch(email)) {
      errors['email'] = [FakeMessages.invalidEmail(language)];
    }
    final password = _requiredString(
      body,
      'password',
      _passwordMax,
      language,
      errors,
    );
    if (password != null &&
        (password.length < _passwordMin ||
            !_letter.hasMatch(password) ||
            !_digit.hasMatch(password))) {
      errors['password'] = [FakeMessages.weakPassword(language)];
    }
    final fullName = _requiredString(
      body,
      'fullName',
      _nameMax,
      language,
      errors,
    );
    final phone = _optionalString(body, 'phone', _phoneMax, language, errors);
    _optionalString(body, 'deviceId', _deviceIdMax, language, errors);
    final preferredLanguage =
        _optionalString(body, 'preferredLanguage', null, language, errors) ??
        _defaultLanguage;
    if (!_languages.contains(preferredLanguage)) {
      errors['preferredLanguage'] = [FakeMessages.invalidValue(language)];
    }
    final shop = body['shop'];
    final shopJson = shop is Map<String, Object?> ? shop : null;
    if (shopJson == null) {
      errors['shop'] = [FakeMessages.required(language)];
    }
    final shopName = shopJson == null
        ? null
        : _requiredString(shopJson, 'name', _nameMax, language, errors, 'shop');
    final shopType = shopJson == null
        ? null
        : _requiredString(shopJson, 'shopType', null, language, errors, 'shop');
    if (errors.isNotEmpty ||
        email == null ||
        password == null ||
        fullName == null ||
        shopName == null ||
        shopType == null) {
      return _problems.validation(request, errors);
    }
    if (!FakeShopTypes.all.contains(shopType)) {
      return _problems.problem(
        request,
        HttpStatus.badRequest,
        ApiErrorCode.shopUnknownType,
      );
    }
    if (shopName.replaceAll(_arabicMarks, '').trim().isEmpty) {
      return _problems.problem(
        request,
        HttpStatus.badRequest,
        ApiErrorCode.shopNameRequired,
      );
    }
    if (_state.userByEmail(email) != null) {
      return _problems.problem(
        request,
        HttpStatus.conflict,
        ApiErrorCode.authEmailTaken,
      );
    }
    final user = FakeUser(
      id: _uuid.v4(),
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      preferredLanguage: preferredLanguage,
    );
    final newShop = FakeShop(
      id: _uuid.v4(),
      name: shopName.trim(),
      shopType: shopType,
      status: FakeShopStatuses.active,
    );
    _state.users.add(user);
    _state.shops.add(newShop);
    _state.memberships.add(
      FakeMembership(
        userId: user.id,
        shopId: newShop.id,
        role: FakeRoles.owner,
        joinedAt: _clock.now(),
      ),
    );
    return FakeResponse.json(
      HttpStatus.created,
      _issue(user, newShop, familyId: _uuid.v4()),
    );
  }

  FakeResponse _login(FakeRequest request) {
    if (_throttle(request, _loginWindow) case final throttled?) {
      return throttled;
    }
    final body = request.jsonObject ?? const {};
    final language = request.language;
    final errors = <String, List<String>>{};
    final email = _requiredString(body, 'email', null, language, errors);
    final password = _requiredString(body, 'password', null, language, errors);
    _optionalString(body, 'deviceId', _deviceIdMax, language, errors);
    if (errors.isNotEmpty || email == null || password == null) {
      return _problems.validation(request, errors);
    }
    final user = _state.userByEmail(email);
    if (user == null) {
      return _invalidCredentials(request);
    }
    // Checked before the password: while locked, even the right password
    // is refused (contract A2).
    final lockedUntil = user.lockedUntil;
    final now = _clock.now();
    if (_controls.lockoutEnabled &&
        lockedUntil != null &&
        lockedUntil.isAfter(now)) {
      return _problems.problem(
        request,
        HttpStatus.locked,
        ApiErrorCode.authLockedOut,
        retryAfter: lockedUntil.difference(now),
      );
    }
    if (user.password != password) {
      _recordFailedLogin(user, now);
      return _invalidCredentials(request);
    }
    user
      ..failedLogins = 0
      ..lockedUntil = null;
    final membership = _state.activeMembershipOf(user.id);
    final shop = membership == null ? null : _state.shopById(membership.shopId);
    if (shop == null) {
      return _problems.problem(
        request,
        HttpStatus.forbidden,
        ApiErrorCode.authNoActiveShop,
      );
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _problems.problem(
        request,
        HttpStatus.forbidden,
        ApiErrorCode.shopSuspended,
      );
    }
    return FakeResponse.json(
      HttpStatus.ok,
      _issue(user, shop, familyId: _uuid.v4()),
    );
  }

  FakeResponse _refresh(FakeRequest request) {
    final token = _refreshTokenField(request);
    if (token == null) {
      return _refreshTokenRequired(request);
    }
    final stored = _state.refreshTokens[token];
    if (stored == null || !stored.expiresAt.isAfter(_clock.now())) {
      return _problems.problem(
        request,
        HttpStatus.unauthorized,
        ApiErrorCode.authInvalidRefreshToken,
      );
    }
    if (stored.revoked) {
      _state.revokeFamily(stored.familyId);
      return _problems.problem(
        request,
        HttpStatus.unauthorized,
        ApiErrorCode.authRefreshTokenReused,
      );
    }
    final user = _state.userById(stored.userId);
    final shop = _state.shopById(stored.shopId);
    if (user == null || shop == null) {
      return _problems.problem(
        request,
        HttpStatus.unauthorized,
        ApiErrorCode.authInvalidRefreshToken,
      );
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _problems.problem(
        request,
        HttpStatus.forbidden,
        ApiErrorCode.shopSuspended,
      );
    }
    stored.revoked = true;
    return FakeResponse.json(
      HttpStatus.ok,
      _issue(user, shop, familyId: stored.familyId),
    );
  }

  FakeResponse _logout(FakeRequest request) {
    if (authenticate(request) == null) {
      return _unauthenticated(request);
    }
    final token = _refreshTokenField(request);
    if (token == null) {
      return _refreshTokenRequired(request);
    }
    final stored = _state.refreshTokens[token];
    if (stored != null) {
      _state.revokeFamily(stored.familyId);
    }
    return const FakeResponse.noContent();
  }

  FakeResponse _me(FakeRequest request) {
    final access = authenticate(request);
    if (access == null) {
      return _unauthenticated(request);
    }
    final user = _state.userById(access.userId);
    final shop = _state.shopById(access.shopId);
    if (user == null || shop == null) {
      return _unauthenticated(request);
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _problems.problem(
        request,
        HttpStatus.forbidden,
        ApiErrorCode.shopSuspended,
      );
    }
    return FakeResponse.json(HttpStatus.ok, {
      'user': _userJson(user),
      'shop': _shopJson(user, shop),
    });
  }

  FakeResponse _invalidCredentials(FakeRequest request) => _problems.problem(
    request,
    HttpStatus.unauthorized,
    ApiErrorCode.authInvalidCredentials,
  );

  /// Identity-style lockout: the failure that reaches the threshold is still
  /// `401`; the account is locked from then on.
  void _recordFailedLogin(FakeUser user, DateTime now) {
    if (!_controls.lockoutEnabled) {
      return;
    }
    user.failedLogins++;
    if (user.failedLogins >= _config.lockoutThreshold) {
      user
        ..failedLogins = 0
        ..lockedUntil = now.add(_config.lockoutDuration);
    }
  }

  /// `429 Auth.TooManyRequests` once [window] has used its permits, with
  /// `Retry-After` until the window resets. `null` lets the request through.
  FakeResponse? _throttle(FakeRequest request, _FixedWindow window) {
    if (!_controls.rateLimitEnabled) {
      return null;
    }
    final now = _clock.now();
    final start = window.start;
    if (start == null || !now.isBefore(start.add(_config.authWindow))) {
      window
        ..start = now
        ..count = 0;
    }
    if (window.count >= _config.authPermitLimit) {
      return _problems.problem(
        request,
        HttpStatus.tooManyRequests,
        ApiErrorCode.authTooManyRequests,
        retryAfter: window.start!.add(_config.authWindow).difference(now),
      );
    }
    window.count++;
    return null;
  }

  FakeResponse _unauthenticated(FakeRequest request) => _problems.problem(
    request,
    HttpStatus.unauthorized,
    ApiErrorCode.authUnauthenticated,
  );

  FakeResponse _refreshTokenRequired(FakeRequest request) =>
      _problems.validation(request, {
        'refreshToken': [FakeMessages.required(request.language)],
      });

  String? _refreshTokenField(FakeRequest request) {
    final value = request.jsonObject?['refreshToken'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// A new access token and a new refresh token in [familyId].
  Map<String, Object?> _issue(
    FakeUser user,
    FakeShop shop, {
    required String familyId,
  }) {
    final now = _clock.now();
    final access = FakeAccessToken(
      token: '$_accessPrefix${_uuid.v4()}',
      userId: user.id,
      shopId: shop.id,
      expiresAt: now.add(_config.accessTokenLifetime),
    );
    final refresh = FakeRefreshToken(
      token: '$_refreshPrefix${_uuid.v4()}',
      familyId: familyId,
      userId: user.id,
      shopId: shop.id,
      expiresAt: now.add(_config.refreshTokenLifetime),
    );
    _state.accessTokens[access.token] = access;
    _state.refreshTokens[refresh.token] = refresh;
    return {
      'accessToken': access.token,
      'accessTokenExpiresAt': _timestamp(access.expiresAt),
      'refreshToken': refresh.token,
      'refreshTokenExpiresAt': _timestamp(refresh.expiresAt),
      'user': _userJson(user),
      'shop': _shopJson(user, shop),
    };
  }

  Map<String, Object?> _userJson(FakeUser user) => {
    'id': user.id,
    'email': user.email,
    'fullName': user.fullName,
    'phone': user.phone,
    'preferredLanguage': user.preferredLanguage,
  };

  Map<String, Object?> _shopJson(FakeUser user, FakeShop shop) => {
    'id': shop.id,
    'name': shop.name,
    'shopType': shop.shopType,
    'status': shop.status,
    'role': _state.membership(user.id, shop.id)?.role ?? FakeRoles.staff,
  };

  String _timestamp(DateTime value) => value.toUtc().toIso8601String();

  String? _requiredString(
    Map<String, Object?> json,
    String field,
    int? max,
    String language,
    Map<String, List<String>> errors, [
    String? parent,
  ]) {
    final key = parent == null ? field : '$parent.$field';
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      errors[key] = [FakeMessages.required(language)];
      return null;
    }
    if (max != null && value.length > max) {
      errors[key] = [FakeMessages.tooLong(language, max)];
      return null;
    }
    return value;
  }

  String? _optionalString(
    Map<String, Object?> json,
    String field,
    int? max,
    String language,
    Map<String, List<String>> errors,
  ) {
    final value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      errors[field] = [FakeMessages.invalidValue(language)];
      return null;
    }
    if (max != null && value.length > max) {
      errors[field] = [FakeMessages.tooLong(language, max)];
      return null;
    }
    return value;
  }
}
