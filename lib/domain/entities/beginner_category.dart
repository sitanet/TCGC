import 'sermon.dart';

class BeginnerCategory {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int sermonCount;
  final List<Sermon> sermons;

  const BeginnerCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    this.sermonCount = 0,
    this.sermons = const [],
  });

  factory BeginnerCategory.fromJson(Map<String, dynamic> json) {
    List<Sermon> sermonList = [];
    if (json['messages'] != null && json['messages'] is List) {
      for (var item in json['messages']) {
        if (item != null && item is Map<String, dynamic>) {
          try {
            sermonList.add(Sermon.fromJson(item));
          } catch (_) {}
        }
      }
    }

    return BeginnerCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      sermonCount: json['message_count'] != null
          ? int.tryParse(json['message_count'].toString()) ?? sermonList.length
          : sermonList.length,
      sermons: sermonList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'message_count': sermonCount,
      'messages': sermons.map((s) => s.toJson()).toList(),
    };
  }
}
