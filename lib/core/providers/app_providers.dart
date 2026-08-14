import 'package:accounting_system/core/configs/server_link.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../extensions/network_checker.dart';
import '../utils/api_client.dart';

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});
final globalContainer = ProviderContainer();
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiLink,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  return dio;
});

final appInitializerProvider = FutureProvider<void>((ref) async {
  await init();
  timeago.setLocaleMessages("ar", timeago.ArMessages());

  await Future.delayed(Duration(seconds: 3));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(dio: ref.watch(dioProvider));
});

Future<void> init() async {
  // if (defaultTargetPlatform == TargetPlatform.android) {
  //   if (Firebase.apps.isEmpty) {
  //     await Firebase.initializeApp(
  //       options: DefaultFirebaseOptions.currentPlatform,
  //     );
  //   }
  //   await FcmService.instance.init();
  // }

  // await LocalNoti.instance.init();
}
