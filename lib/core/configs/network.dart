import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;

  /// Emits `true` whenever connectivity becomes available and `false` when it
  /// is lost. Backed by a broadcast stream so the sync engine can keep a
  /// single cancellable subscription.
  Stream<bool> get onlineStream;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl();
  final Connectivity _connectivity = Connectivity();

  @override
  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((event) => !event.contains(ConnectivityResult.none));

  void connectivityStream(Function(bool isOnline) eventCallBack) {
    _connectivity.onConnectivityChanged.listen(
      (event) {
        if (!event.contains(ConnectivityResult.none)) {
          eventCallBack.call(true);
        } else {
          eventCallBack.call(false);
        }
      },
    );
  }

  @override
  Future<bool> get isConnected async =>
      Future.value(!(await _connectivity.checkConnectivity())
          .contains(ConnectivityResult.none));
}
