import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/youtube_video.dart';

class YouTubeVideoResult {
  final List<YouTubeVideo> videos;
  final String? nextPageToken;
  final bool hasMore;

  YouTubeVideoResult({
    required this.videos,
    this.nextPageToken,
    required this.hasMore,
  });
}

class YouTubeService {
  static const String _channelUrl = 'https://www.youtube.com/@dcitygatechurch/videos';
  
  // YouTube API key - Replace with your actual API key
  static const String _apiKey = 'YOUR_YOUTUBE_API_KEY';
  
  // Channel ID for D CityGate Church
  static const String _channelId = 'UCYour_Channel_ID';
  
  // Number of videos to fetch per request
  static const int _videosPerPage = 5;

  static Future<YouTubeVideoResult> fetchVideos({String? pageToken}) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&channelId=$_channelId'
      '&maxResults=$_videosPerPage'
      '&order=date'
      '&type=video'
      '${pageToken != null ? '&pageToken=$pageToken' : ''}'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        final nextToken = data['nextPageToken'] as String?;
        
        final videos = items.map((item) => YouTubeVideo.fromJson(item)).toList();
        
        return YouTubeVideoResult(
          videos: videos,
          nextPageToken: nextToken,
          hasMore: nextToken != null,
        );
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      // Fall back to hardcoded videos for demo/development
      return YouTubeVideoResult(
        videos: getChannelVideos(),
        hasMore: false,
      );
    }
  }

  // Fallback hardcoded videos for demo/development
  static List<YouTubeVideo> getChannelVideos() {
    return [
      YouTubeVideo(
        id: 'dQw4w9WgXcQ',
        title: 'Sunday Service - The Power of Faith',
        description: 'Join us for an inspiring Sunday service message about the transformative power of faith.',
        thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelTitle: 'D CityGate Church',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      YouTubeVideo(
        id: 'jNQXAC9IVRw',
        title: 'Midweek Service - Walking in Purpose',
        description: 'A powerful message about discovering and walking in your God-given purpose.',
        thumbnailUrl: 'https://img.youtube.com/vi/jNQXAC9IVRw/hqdefault.jpg',
        channelTitle: 'D CityGate Church',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      YouTubeVideo(
        id: 'M7lc1UVf-VE',
        title: 'The School of Christ - Lesson 1',
        description: 'Beginning of our series on understanding the teachings of Christ.',
        thumbnailUrl: 'https://img.youtube.com/vi/M7lc1UVf-VE/hqdefault.jpg',
        channelTitle: 'D CityGate Church',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      YouTubeVideo(
        id: 'kJQP7kiw5Fk',
        title: 'Feast of Glory Conference Day 1',
        description: 'Highlights from the first day of our annual Feast of Glory Conference.',
        thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
        channelTitle: 'D CityGate Church',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      YouTubeVideo(
        id: 'RgKAFK5djSk',
        title: 'Word & Prayer Session',
        description: 'A spirit-filled Word and Prayer session to strengthen your faith.',
        thumbnailUrl: 'https://img.youtube.com/vi/RgKAFK5djSk/hqdefault.jpg',
        channelTitle: 'D CityGate Church',
        publishedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  static String get channelUrl => _channelUrl;
}
