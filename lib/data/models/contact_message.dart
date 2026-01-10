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
    );
  }

  bool get hasReply => adminReply != null && adminReply!.isNotEmpty;
}
