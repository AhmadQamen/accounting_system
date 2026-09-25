import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:accounting_system/features/auth/data/auth_repository.dart';
import 'package:accounting_system/features/auth/data/auth_session_manager.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:accounting_system/features/auth/domain/models/organization_activation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  choosingMembership,
  registeringDevice,
  deviceRevoked,
  noMembership,
  authenticated,
}

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({
    required AuthRepository repository,
    required AuthSessionManager sessionManager,
    required OrganizationActivator organizationActivator,
  }) : _repository = repository,
       _sessionManager = sessionManager,
       _organizationActivator = organizationActivator {
    _sessionManager.addExpiredListener(_onSessionExpired);
  }

  final AuthRepository _repository;
  final AuthSessionManager _sessionManager;
  final OrganizationActivator _organizationActivator;

  AuthStatus _status = AuthStatus.initializing;
  AuthUser? _user;
  Membership? _selectedMembership;
  String? _errorMessage;
  bool isLoggingIn = false;
  bool isLoggingOut = false;
  bool isActivatingOrganization = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  Membership? get selectedMembership => _selectedMembership;
  List<Membership> get memberships => _user?.memberships ?? const [];
  String? get errorMessage => _errorMessage;
  bool get isInitializing => _status == AuthStatus.initializing;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    _status = AuthStatus.initializing;
    notifyListeners();
    try {
      final user = await _repository.restoreSession();
      if (user == null) {
        _status = AuthStatus.unauthenticated;
      } else {
        await _applyUser(user);
      }
    } catch (error) {
      final cached =
          _isOfflineError(error)
              ? await _repository.restoreCachedSession()
              : null;
      if (cached != null && cached.memberships.isNotEmpty) {
        _user = cached;
        _selectedMembership = cached.memberships.single;
        _status = AuthStatus.authenticated;
        _errorMessage =
            'يعمل التطبيق دون اتصال؛ البيانات محلية حتى نجاح المزامنة.';
      } else {
        _errorMessage = _messageFor(error);
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    if (isLoggingIn) return;
    isLoggingIn = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await _repository.login(email: email, password: password);
      await _applyUser(user);
    } catch (error) {
      _errorMessage = _messageFor(error, login: true);
      _status = AuthStatus.unauthenticated;
    } finally {
      isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> selectMembership(Membership membership) async {
    if (!memberships.any(
      (candidate) => candidate.membershipId == membership.membershipId,
    )) {
      throw ArgumentError('Membership does not belong to the current user.');
    }
    await _activateMembership(membership);
  }

  void chooseAnotherMembership() {
    if (_user == null || memberships.isEmpty || isActivatingOrganization) {
      return;
    }
    _selectedMembership = null;
    _errorMessage = null;
    _status = AuthStatus.choosingMembership;
    notifyListeners();
  }

  Future<void> logout() async {
    if (isLoggingOut) return;
    isLoggingOut = true;
    notifyListeners();
    try {
      await _repository.logout();
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      _resetToLogin();
      isLoggingOut = false;
      notifyListeners();
    }
  }

  Future<void> _applyUser(AuthUser user) async {
    _user = user;
    _selectedMembership = null;
    if (user.memberships.isEmpty) {
      _status = AuthStatus.noMembership;
    } else if (user.memberships.length == 1) {
      await _activateMembership(user.memberships.single);
    } else {
      _status = AuthStatus.choosingMembership;
    }
  }

  Future<void> _activateMembership(Membership membership) async {
    final user = _user;
    if (user == null || isActivatingOrganization) return;
    isActivatingOrganization = true;
    _selectedMembership = membership;
    _status = AuthStatus.registeringDevice;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _organizationActivator.activate(
        user: user,
        membership: membership,
      );
      _status =
          result.revoked ? AuthStatus.deviceRevoked : AuthStatus.authenticated;
      if (result.revoked) {
        _errorMessage = 'ألغت الإدارة صلاحية هذا الجهاز لهذه المؤسسة.';
      }
    } catch (error) {
      _selectedMembership = null;
      _status = AuthStatus.choosingMembership;
      _errorMessage = _messageFor(error);
    } finally {
      isActivatingOrganization = false;
      notifyListeners();
    }
  }

  void _onSessionExpired() {
    _errorMessage = 'انتهت الجلسة. يرجى تسجيل الدخول مجددًا.';
    _resetToLogin(keepError: true);
    notifyListeners();
  }

  void _resetToLogin({bool keepError = false}) {
    _user = null;
    _selectedMembership = null;
    _status = AuthStatus.unauthenticated;
    if (!keepError) _errorMessage = null;
  }

  String _messageFor(Object error, {bool login = false}) {
    if (login && error is DioException && error.response?.statusCode == 401) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (error is AppException) return error.message;
    if (error is NetworkException) return error.message;
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'انتهت الجلسة. يرجى تسجيل الدخول مجددًا.';
      }
      if (error.response?.data case final Map data) {
        final message = data['message'];
        if (message != null) return message.toString();
      }
      return 'تعذر الاتصال بالخادم. حاول مرة أخرى.';
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  bool _isOfflineError(Object error) =>
      error is NetworkException ||
      (error is DioException && error.response == null);

  @override
  void dispose() {
    _sessionManager.removeExpiredListener(_onSessionExpired);
    super.dispose();
  }
}
