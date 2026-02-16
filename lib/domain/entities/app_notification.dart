class AppNotification {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final String notificationType;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool isGlobal;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.notificationType,
    this.data,
    this.isRead = false,
    this.isGlobal = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      imageUrl: json['image_url'],
      notificationType: json['notification_type'] ?? 'system',
      data: json['data'],
      isRead: json['is_read'] ?? false,
      isGlobal: json['is_global'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'notification_type': notificationType,
      'data': data,
      'is_read': isRead,
      'is_global': isGlobal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    String? imageUrl,
    String? notificationType,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isGlobal,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      notificationType: notificationType ?? this.notificationType,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isGlobal: isGlobal ?? this.isGlobal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool eventsEnabled;
  final bool messagesEnabled; // Sermons/messages
  final bool walletEnabled;
  final bool teensEnabled;
  final bool announcementsEnabled;
  final bool promotionsEnabled;

  NotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.eventsEnabled = true,
    this.messagesEnabled = true,
    this.walletEnabled = true,
    this.teensEnabled = true,
    this.announcementsEnabled = true,
    this.promotionsEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] ?? true,
      emailEnabled: json['email_enabled'] ?? true,
      eventsEnabled: json['events_enabled'] ?? true,
      messagesEnabled: json['messages_enabled'] ?? true,
      walletEnabled: json['wallet_enabled'] ?? true,
      teensEnabled: json['teens_enabled'] ?? true,
      announcementsEnabled: json['announcements_enabled'] ?? true,
      promotionsEnabled: json['promotions_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'events_enabled': eventsEnabled,
      'messages_enabled': messagesEnabled,
      'wallet_enabled': walletEnabled,
      'teens_enabled': teensEnabled,
      'announcements_enabled': announcementsEnabled,
      'promotions_enabled': promotionsEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? eventsEnabled,
    bool? messagesEnabled,
    bool? walletEnabled,
    bool? teensEnabled,
    bool? announcementsEnabled,
    bool? promotionsEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      walletEnabled: walletEnabled ?? this.walletEnabled,
      teensEnabled: teensEnabled ?? this.teensEnabled,
      announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
      promotionsEnabled: promotionsEnabled ?? this.promotionsEnabled,
    );
  }
}
