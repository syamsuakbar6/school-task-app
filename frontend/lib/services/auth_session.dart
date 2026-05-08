import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_service.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this.api);

  final ApiService api;
  AppUser? user;

  bool get isAuthenticated => user != null;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    debugPrint('AUTH SESSION LOGIN CALLED - delegating to ApiService');

    // Delegates all HTTP logic to ApiService, which is already correct.
    final loggedInUser = await api.login(email: email, password: password);

    user = loggedInUser;
    debugPrint('AUTH SESSION: user set -> ${user?.name}, role=${user?.role}');
    notifyListeners();
  }

  void logout() {
    user = null;
    api.clearToken();
    notifyListeners();
  }
}
