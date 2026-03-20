class TeensContent {
  final String id;
  final String title;
  final String description;
  final String? speaker;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String? transcript;
  final String? htmlTranscript;
  final String category;
  final DateTime date;
  final Duration? duration;

  const TeensContent({
    required this.id,
    required this.title,
    required this.description,
    this.speaker,
    this.thumbnailUrl,
    this.videoUrl,
    this.audioUrl,
    this.transcript,
    this.htmlTranscript,
    required this.category,
    required this.date,
    this.duration,
  });

  factory TeensContent.fromJson(Map<String, dynamic> json) {
    return TeensContent(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      speaker: json['speaker'],
      thumbnailUrl: json['thumbnail_url'],
      videoUrl: json['video_url'],
      audioUrl: json['audio_url'],
      transcript: json['transcript'],
      htmlTranscript: json['html_transcript'],
      category: json['category_name'] ?? json['category']?.toString() ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      duration: json['duration_minutes'] != null 
          ? Duration(minutes: json['duration_minutes']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'speaker': speaker,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'transcript': transcript,
      'html_transcript': htmlTranscript,
      'category_name': category,
      'date': date.toIso8601String(),
      'duration_minutes': duration?.inMinutes,
    };
  }

  TeensContent copyWith({
    String? id,
    String? title,
    String? description,
    String? speaker,
    String? thumbnailUrl,
    String? videoUrl,
    String? audioUrl,
    String? transcript,
    String? htmlTranscript,
    String? category,
    DateTime? date,
    Duration? duration,
  }) {
    return TeensContent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      speaker: speaker ?? this.speaker,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      transcript: transcript ?? this.transcript,
      htmlTranscript: htmlTranscript ?? this.htmlTranscript,
      category: category ?? this.category,
      date: date ?? this.date,
      duration: duration ?? this.duration,
    );
  }
}
