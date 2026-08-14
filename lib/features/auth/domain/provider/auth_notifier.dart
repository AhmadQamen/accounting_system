import 'package:flutter/material.dart';
import '../../../../core/utils/states/states_handler.dart';

class AuthNotifier extends ChangeNotifier with StatesHandler {
<<<<<<< HEAD
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
=======
  bool isInitializing=false,isLoggingIn=false,isRegistering=false,isRefreshingProfile=false,isLoggingOut=false;
  bool _isAuthenticated=false;
  bool get isAuthenticated=>_isAuthenticated;
  Future<void> login() async {isLoggingIn=true;notifyListeners();try{_isAuthenticated=true;}finally{isLoggingIn=false;notifyListeners();}}
  Future<void> logout() async {isLoggingOut=true;notifyListeners();_isAuthenticated=false;isLoggingOut=false;notifyListeners();}
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
}
