class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final DateTime publishedAt;
  final String? duration;

  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    this.duration,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>;
    final resourceId = snippet['resourceId'] as Map<String, dynamic>?;
    final videoId = resourceId?['videoId'] ?? json['id']?['videoId'] ?? json['id'];
    
    return YouTubeVideo(
      id: videoId ?? '',
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? 
                    snippet['thumbnails']?['medium']?['url'] ?? 
                    snippet['thumbnails']?['default']?['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      publishedAt: DateTime.tryParse(snippet['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
