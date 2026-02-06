class Sermon {
  final String id;
  final String title;
  final String description;
  final String? speaker;
  final String? imageUrl;
  final String? audioUrl;
  final String? videoUrl;
  final String? transcript;
  final String category;
  final String categoryName;
  final DateTime date;
  final Duration duration;

  const Sermon({
    required this.id,
    required this.title,
    required this.description,
    this.speaker,
    this.imageUrl,
    this.audioUrl,
    this.videoUrl,
    this.transcript,
    required this.category,
    this.categoryName = '',
    required this.date,
    required this.duration,
  });

  factory Sermon.fromJson(Map<String, dynamic> json) {
    // Handle category - could be int or string
    final categoryValue = json['category'];
    final categoryStr = categoryValue?.toString() ?? '';
    
    // Handle category_name
    final categoryName = json['category_name']?.toString() ?? '';
    
    return Sermon(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      speaker: json['speaker'],
      imageUrl: json['image_url'],
      audioUrl: json['audio_url'],
      videoUrl: json['video_url'],
      transcript: json['transcript'],
      category: categoryStr,
      categoryName: categoryName,
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      duration: Duration(minutes: json['duration_minutes'] ?? 0),
    );
  }
}

class MessageCategory {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime? latestMessageDate;
  final bool hasNewMessage;

  const MessageCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.latestMessageDate,
    this.hasNewMessage = false,
  });

  factory MessageCategory.fromJson(Map<String, dynamic> json) {
    return MessageCategory(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      isActive: json['is_active'] ?? true,
      latestMessageDate: json['latest_message_date'] != null 
          ? DateTime.tryParse(json['latest_message_date'].toString())
          : null,
      hasNewMessage: json['has_new_message'] ?? false,
    );
  }

  MessageCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    bool? isActive,
    DateTime? latestMessageDate,
    bool? hasNewMessage,
  }) {
    return MessageCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      latestMessageDate: latestMessageDate ?? this.latestMessageDate,
      hasNewMessage: hasNewMessage ?? this.hasNewMessage,
    );
  }
}
