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
    if (storedToken == null || storedToken.isEmpty) return false;

    try {
      api.setToken(storedToken);
      user = await api.currentUser();
      notifyListeners();
      return true;
    } catch (error) {
      user = null;
      api.clearToken();
      await _tokenStore.clearToken();
      notifyListeners();
      return false;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final loggedInUser = await api.login(
      identifier: identifier,
      password: password,
    );

    final token = api.token;
    if (token != null && token.isNotEmpty) {
      await _tokenStore.saveToken(token);
    }

    user = loggedInUser;
    notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    api.clearToken();
    await _tokenStore.clearToken();
    notifyListeners();
  }
}
