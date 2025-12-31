class AppNotification {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      imageUrl: json['image_url'],
      type: json['type'] ?? 'general',
      data: json['data'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    String? imageUrl,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool eventsEnabled;
  final bool sermonsEnabled;
  final bool walletEnabled;

  NotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.eventsEnabled = true,
    this.sermonsEnabled = true,
    this.walletEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] ?? true,
      emailEnabled: json['email_enabled'] ?? true,
      smsEnabled: json['sms_enabled'] ?? false,
      eventsEnabled: json['events_enabled'] ?? true,
      sermonsEnabled: json['sermons_enabled'] ?? true,
      walletEnabled: json['wallet_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'sms_enabled': smsEnabled,
      'events_enabled': eventsEnabled,
      'sermons_enabled': sermonsEnabled,
      'wallet_enabled': walletEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? eventsEnabled,
    bool? sermonsEnabled,
    bool? walletEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      sermonsEnabled: sermonsEnabled ?? this.sermonsEnabled,
      walletEnabled: walletEnabled ?? this.walletEnabled,
    );
  }
}
