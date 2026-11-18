import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/sermon.dart';
import 'api_service.dart';

class AudioRestreamInfo {
  final int id;
  final String title;
  final bool isLive;
  final bool isLooping;
  final int offsetSeconds;
  final int durationSeconds;
  final int listenerCount;
  final Sermon sermon;

  const AudioRestreamInfo({
    required this.id,
    required this.title,
    required this.isLive,
    required this.isLooping,
    required this.offsetSeconds,
    required this.durationSeconds,
    required this.listenerCount,
    required this.sermon,
  });

  factory AudioRestreamInfo.fromJson(Map<String, dynamic> json) {
    final sermonJson = json['sermon'] as Map<String, dynamic>;
    return AudioRestreamInfo(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? (sermonJson['title'] as String? ?? 'Live Rebroadcast'),
      isLive: json['is_live'] == true,
      isLooping: json['is_looping'] == true,
      offsetSeconds: (json['offset_seconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      listenerCount: (json['listener_count'] as num?)?.toInt() ?? 0,
      sermon: Sermon.fromJson(sermonJson),
    );
  }
}

class RestreamService {
  static final RestreamService _instance = RestreamService._internal();
  factory RestreamService() => _instance;
  RestreamService._internal();

  final ApiService _api = ApiService();

  Future<AudioRestreamInfo?> fetchActiveRestream() async {
    try {
      final res = await _api
          .get(ApiConstants.audioRestreamActive)
          .timeout(const Duration(seconds: 12));
      if (res.isSuccess && res.data['is_live'] == true && res.data['sermon'] != null) {
        return AudioRestreamInfo.fromJson(res.data);
      }
    } catch (e) {
      debugPrint('RestreamService.fetchActiveRestream error: $e');
    }
    return null;
  }

  Future<int?> sendHeartbeat(int restreamId) async {
    try {
      final res = await _api
          .postPublic(ApiConstants.audioRestreamHeartbeat(restreamId), {})
          .timeout(const Duration(seconds: 8));
      if (res.isSuccess) {
        return (res.data['listener_count'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }
}
