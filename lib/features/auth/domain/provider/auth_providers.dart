import 'package:flutter_riverpod/legacy.dart';

import 'auth_notifier.dart';

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
