import 'package:flutter/material.dart';
import '../../../../core/utils/states/states_handler.dart';

class AuthNotifier extends ChangeNotifier with StatesHandler {
  AuthNotifier();

  // =========================
  // Loading States
  // =========================

  bool isInitializing = false;
  bool isLoggingIn = false;
  bool isRegistering = false;
  bool isRefreshingProfile = false;
  bool isLoggingOut = false;
  bool au = false;
  bool get isAuthenticated => au;
  Future<void> login() async {
    au = true;
    notifyListeners();
  }
}
