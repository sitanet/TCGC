class Sermon {
  final String id;
  final String title;
  final String description;
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

  const MessageCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  factory MessageCategory.fromJson(Map<String, dynamic> json) {
    return MessageCategory(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      isActive: json['is_active'] ?? true,
    );
  }
}
