class MessageReply {
  final int id;
  final String senderType;
  final String? senderName;
  final String message;
  final DateTime createdAt;

  MessageReply({
    required this.id,
    required this.senderType,
    this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory MessageReply.fromJson(Map<String, dynamic> json) {
    return MessageReply(
      id: json['id'],
      senderType: json['sender_type'] ?? 'user',
      senderName: json['sender_name'],
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isSupport => senderType == 'support';
  bool get isUser => senderType == 'user';
}

class ContactMessage {
  final int id;
  final String? name;
  final String email;
  final String category;
  final String categoryDisplay;
  final String subject;
  final String message;
  final String? adminReply;
  final DateTime? repliedAt;
  final String? repliedByName;
  final bool isResolved;
  final DateTime createdAt;
  final List<MessageReply> replies;

  ContactMessage({
    required this.id,
    this.name,
    required this.email,
    required this.category,
    required this.categoryDisplay,
    required this.subject,
    required this.message,
    this.adminReply,
    this.repliedAt,
    this.repliedByName,
    required this.isResolved,
    required this.createdAt,
    this.replies = const [],
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) {
    return ContactMessage(
      id: json['id'],
      name: json['name'],
      email: json['email'] ?? '',
      category: json['category'] ?? 'general',
      categoryDisplay: json['category_display'] ?? 'General Inquiry',
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      adminReply: json['admin_reply'],
      repliedAt: json['replied_at'] != null 
          ? DateTime.parse(json['replied_at']) 
          : null,
      repliedByName: json['replied_by_name'],
      isResolved: json['is_resolved'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      replies: json['replies'] != null
          ? (json['replies'] as List).map((r) => MessageReply.fromJson(r)).toList()
          : [],
    );
  }

  bool get hasReply => adminReply != null && adminReply!.isNotEmpty;
  bool get hasReplies => replies.isNotEmpty;
}
