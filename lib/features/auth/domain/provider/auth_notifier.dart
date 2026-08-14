import 'package:flutter/material.dart';
import '../../../../core/utils/states/states_handler.dart';

class AuthNotifier extends ChangeNotifier with StatesHandler {
  bool isInitializing=false,isLoggingIn=false,isRegistering=false,isRefreshingProfile=false,isLoggingOut=false;
  bool _isAuthenticated=false;
  bool get isAuthenticated=>_isAuthenticated;
  Future<void> login() async {isLoggingIn=true;notifyListeners();try{_isAuthenticated=true;}finally{isLoggingIn=false;notifyListeners();}}
  Future<void> logout() async {isLoggingOut=true;notifyListeners();_isAuthenticated=false;isLoggingOut=false;notifyListeners();}
}
