import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_service.dart';
import 'auth_token_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(
    this.api, {
    AuthTokenStore tokenStore = const AuthTokenStore(),
  }) : _tokenStore = tokenStore;

  final ApiService api;
  final AuthTokenStore _tokenStore;
  AppUser? user;

  bool get isAuthenticated => user != null;

  Future<bool> restoreSession() async {
    final storedToken = await _tokenStore.readToken();
    if (storedToken == null || storedToken.isEmpty) {
      return false;
    }

    try {
      api.setToken(storedToken);
      user = await api.currentUser();
      debugPrint(
        'AUTH SESSION RESTORED: user set -> ${user?.name}, role=${user?.role}',
      );
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('AUTH SESSION RESTORE FAILED: $error');
      debugPrint('STACKTRACE: $stackTrace');
      user = null;
      api.clearToken();
      await _tokenStore.clearToken();
      notifyListeners();
      return false;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    debugPrint('AUTH SESSION LOGIN CALLED - delegating to ApiService');

    // Delegates all HTTP logic to ApiService, which is already correct.
    final loggedInUser = await api.login(email: email, password: password);

    final token = api.token;
    if (token != null && token.isNotEmpty) {
      await _tokenStore.saveToken(token);
    }

    user = loggedInUser;
    debugPrint('AUTH SESSION: user set -> ${user?.name}, role=${user?.role}');
    notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    api.clearToken();
    await _tokenStore.clearToken();
    notifyListeners();
  }
}
