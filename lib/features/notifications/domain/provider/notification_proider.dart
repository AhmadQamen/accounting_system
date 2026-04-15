import 'dart:developer';
import 'package:accounting_system/features/notifications/db/notification_service.dart';
import 'package:accounting_system/features/notifications/domain/models/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'notification_notifier.dart';

final notificationProvider = ChangeNotifierProvider(
  (ref) => NotificationNotifier(NotificationService.instance, ref),
);

final globalContainer = ProviderContainer();
void notifyProvider(NotificationModel notification) {
  globalContainer.read(notificationProvider).fetchNotifications();
  log('done');
}
