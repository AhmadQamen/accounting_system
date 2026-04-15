import '../../../../core/config/unset.dart';

class NotificationModel {
  final String? id;
  final String? title;
  final String? body;
  final String? date;
  final String? userId;
  final bool isRead;

  NotificationModel({
    this.id,
    this.title,
    this.body,
    this.date,
    this.userId,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      date: json['date'],
      userId: json['userId'],
      isRead: json['isRead'] == 1 || json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'date': date,
      'userId': userId,
      'isRead': isRead ? 1 : 0,
    };
  }

  NotificationModel copyWith({
    Object? id = unset,
    Object? page = unset,
    Object? title = unset,
    Object? body = unset,
    Object? orderId = unset,
    Object? date = unset,
    Object? userId = unset,
    Object? isRead = unset, // ✅ NEW
  }) {
    return NotificationModel(
      id: id is Unset ? this.id : id as String?,
      title: title is Unset ? this.title : title as String?,
      body: body is Unset ? this.body : body as String?,
      date: date is Unset ? this.date : date as String?,
      userId: userId is Unset ? this.userId : userId as String?,
      isRead: isRead is Unset ? this.isRead : isRead as bool,
    );
  }
}
