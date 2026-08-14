import 'package:accounting_system/core/configs/server_link.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/shortcuts/keyboard_shortcut_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../extensions/network_checker.dart';
import '../utils/api_client.dart';

final globalContainer=ProviderContainer();
final networkInfoProvider=Provider<NetworkInfo>((ref)=>NetworkInfoImpl());
final dioProvider=Provider<Dio>((ref)=>Dio(BaseOptions(baseUrl:apiLink,connectTimeout:const Duration(seconds:30),receiveTimeout:const Duration(seconds:30))));
final apiClientProvider=Provider<ApiClient>((ref)=>ApiClient(dio:ref.watch(dioProvider)));
final appInitializerProvider=FutureProvider<void>((ref) async{
  await AppDatabase.instance.database;
  await LocalContextService.instance.current;
  await KeyboardShortcutService.instance.insertDefaults();
  timeago.setLocaleMessages('ar',timeago.ArMessages());
});
