<<<<<<< HEAD
=======
import 'package:flutter_riverpod/flutter_riverpod.dart';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
import 'package:flutter_riverpod/legacy.dart';

import 'auth_notifier.dart';

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
