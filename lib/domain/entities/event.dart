class Event {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String schedule;
  final String? iconColor;
  final bool isLive;
  final bool isTeensEvent;
  final String? youtubeUrl;
  final String? location;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.schedule,
    this.iconColor,
    this.isLive = false,
    this.isTeensEvent = false,
    this.youtubeUrl,
    this.location,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      schedule: json['schedule'] ?? '',
      iconColor: json['icon_color'],
      isLive: json['is_live'] ?? false,
      isTeensEvent: json['is_teens_event'] ?? false,
      youtubeUrl: json['youtube_url'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'schedule': schedule,
      'icon_color': iconColor,
      'is_live': isLive,
      'is_teens_event': isTeensEvent,
      'youtube_url': youtubeUrl,
      'location': location,
    };
  }
}
