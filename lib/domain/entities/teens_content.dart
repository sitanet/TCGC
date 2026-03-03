class TeensContent {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String? transcript;
  final String category;
  final DateTime date;
  final Duration? duration;

  const TeensContent({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.videoUrl,
    this.audioUrl,
    this.transcript,
    required this.category,
    required this.date,
    this.duration,
  });

  factory TeensContent.fromJson(Map<String, dynamic> json) {
    return TeensContent(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      videoUrl: json['video_url'],
      audioUrl: json['audio_url'],
      transcript: json['transcript'],
      category: json['category'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      duration: json['duration_minutes'] != null 
          ? Duration(minutes: json['duration_minutes']) 
          : null,
    );
  }
}
