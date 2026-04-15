import 'package:accounting_system/core/errors/failures.dart';
import 'package:accounting_system/core/utils/states/states_handler.dart';
import 'package:accounting_system/features/notifications/db/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationNotifier extends ChangeNotifier with StatesHandler {
  final Ref ref;
  final NotificationService _service;

  NotificationNotifier(this._service, this.ref);

  // ------------------------------
  // Loading states
  // ------------------------------
  bool isLoadingNotifications = false;
  bool isDeletingNotification = false;
  bool isClearingNotifications = false;
  bool isMarkingRead = false;

  // ------------------------------
  // Data
  // ------------------------------
  List<NotificationModel> notifications = [];

  /// ✅ unread count (for badge)
  int get unreadCount => notifications.where((e) => !e.isRead).length;

  // ------------------------------
  // Internal loading wrapper
  // ------------------------------
  Future<ProviderStates> _wrapLoading<T>(
    Future<Either<Failure, T>> Function() fn, {
    Function(bool)? loadingSetter,
  }) async {
    loadingSetter?.call(true);
    notifyListeners();

    final result = await fn();

    loadingSetter?.call(false);
    notifyListeners();

    return failureOrDataToState<T>(result);
  }

  // ------------------------------
  // Reset (used after logout/reset app)
  // ------------------------------
  Future<void> resetSettings() async {
    notifications.clear();
    notifyListeners();
  }

  // ------------------------------
  // Fetch all notifications
  // ------------------------------
  Future<ProviderStates> fetchNotifications() {
    return _wrapLoading<List<NotificationModel>>(() async {
      try {
        final list = await _service.getAll();
        return Right(list);
      } catch (e) {
        return Left(CacheFailure(message: e.toString()));
      }
    }, loadingSetter: (v) => isLoadingNotifications = v).then((state) {
      if (state is DataState<List<NotificationModel>>) {
        notifications = state.data;
      }
      return state;
    });
  }

  // ------------------------------
  // Add / Update notification
  // ------------------------------
  Future<ProviderStates> addNotification(NotificationModel notification) {
    return _wrapLoading<void>(() async {
      try {
        await _service.addOrUpdate(notification);
        return const Right(null);
      } catch (e) {
        return Left(CacheFailure(message: e.toString()));
      }
    }).then((state) {
      if (state is DataState<void>) {
        notifications.insert(0, notification);
        notifyListeners();
      }
      return state;
    });
  }

  // ------------------------------
  // ✅ Mark ONE as read
  // ------------------------------
  Future<ProviderStates> markAsRead(String id) {
    return _wrapLoading<void>(() async {
      try {
        await _service.markAsRead(id);
        return const Right(null);
      } catch (e) {
        return Left(CacheFailure(message: e.toString()));
      }
    }, loadingSetter: (v) => isMarkingRead = v).then((state) {
      if (state is DataState<void>) {
        final index = notifications.indexWhere((e) => e.id == id);
        if (index != -1) {
          notifications[index] = notifications[index].copyWith(isRead: true);
          notifyListeners();
        }
      }
      return state;
    });
  }

  // ------------------------------
  // ✅ Mark ALL as read
  // ------------------------------
  Future<ProviderStates> markAllAsRead() {
    return _wrapLoading<void>(() async {
      try {
        await _service.markAllAsRead();
        return const Right(null);
      } catch (e) {
        return Left(CacheFailure(message: e.toString()));
      }
    }, loadingSetter: (v) => isMarkingRead = v).then((state) {
      if (state is DataState<void>) {
        notifications = notifications
            .map((e) => e.copyWith(isRead: true))
            .toList();
        notifyListeners();
      }
      return state;
    });
  }

  // ------------------------------
  // Delete notification
  // ------------------------------
  Future<ProviderStates> deleteNotification(String id) {
    return _wrapLoading<void>(() async {
      try {
        await _service.delete(id);
        return const Right(null);
      } catch (e) {
        return Left(CacheFailure(message: e.toString()));
      }
    }, loadingSetter: (v) => isDeletingNotification = v).then((state) {
      if (state is DataState<void>) {
        notifications.removeWhere((e) => e.id == id);
        notifyListeners();
      }
      return state;
    });
  }

  // ------------------------------
  // Helpers
  // ------------------------------
  NotificationModel? getById(String id) {
    return notifications.where((e) => e.id == id).firstOrNull;
  }
}
