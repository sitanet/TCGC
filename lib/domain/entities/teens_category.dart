class TeensCategory {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int contentCount;
  final bool isActive;
  final DateTime createdAt;

  TeensCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.contentCount,
    required this.isActive,
    required this.createdAt,
  });

  factory TeensCategory.fromJson(Map<String, dynamic> json) {
    return TeensCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'] ?? json['image'],
      contentCount: json['content_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
