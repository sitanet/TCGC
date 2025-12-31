class Event {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String schedule;
  final String? iconColor;
  final bool isLive;
  final bool isTeensEvent;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.schedule,
    this.iconColor,
    this.isLive = false,
    this.isTeensEvent = false,
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
    );
  }
}
