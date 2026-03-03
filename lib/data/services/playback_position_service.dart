import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPosition {
  final String sermonId;
  final int positionMs;
  final int durationMs;
  final DateTime savedAt;

  PlaybackPosition({
    required this.sermonId,
    required this.positionMs,
    required this.durationMs,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'sermonId': sermonId,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'savedAt': savedAt.toIso8601String(),
  };

  factory PlaybackPosition.fromJson(Map<String, dynamic> json) => PlaybackPosition(
    sermonId: json['sermonId'] as String,
    positionMs: json['positionMs'] as int,
    durationMs: json['durationMs'] as int,
    savedAt: DateTime.parse(json['savedAt'] as String),
  );

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);
  
  double get progress => durationMs > 0 ? positionMs / durationMs : 0.0;
  
  String get formattedPosition {
    final hours = position.inHours;
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
  
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
  
  bool get isSignificant => positionMs > 5000 && progress < 0.95;
}

class PlaybackPositionService {
  static const String _storageKey = 'playback_positions';
  static PlaybackPositionService? _instance;
  
  SharedPreferences? _prefs;
  Map<String, PlaybackPosition> _positions = {};
  
  PlaybackPositionService._();
  
  static PlaybackPositionService get instance {
    _instance ??= PlaybackPositionService._();
    return _instance!;
  }
  
  factory PlaybackPositionService() => instance;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadPositions();
  }
  
  void _loadPositions() {
    final data = _prefs?.getString(_storageKey);
    if (data != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(data);
        _positions = json.map((key, value) => 
          MapEntry(key, PlaybackPosition.fromJson(value as Map<String, dynamic>))
        );
        _cleanOldPositions();
      } catch (e) {
        _positions = {};
      }
    }
  }
  
  Future<void> _savePositions() async {
    final json = _positions.map((key, value) => MapEntry(key, value.toJson()));
    await _prefs?.setString(_storageKey, jsonEncode(json));
  }
  
  void _cleanOldPositions() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    _positions.removeWhere((_, pos) => pos.savedAt.isBefore(thirtyDaysAgo));
  }
  
  Future<void> savePosition(String sermonId, Duration position, Duration duration) async {
    if (position.inMilliseconds < 5000) return;
    if (duration.inMilliseconds == 0) return;
    
    final progress = position.inMilliseconds / duration.inMilliseconds;
    if (progress > 0.95) {
      await clearPosition(sermonId);
      return;
    }
    
    _positions[sermonId] = PlaybackPosition(
      sermonId: sermonId,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      savedAt: DateTime.now(),
    );
    await _savePositions();
  }
  
  PlaybackPosition? getPosition(String sermonId) {
    final position = _positions[sermonId];
    if (position != null && position.isSignificant) {
      return position;
    }
    return null;
  }
  
  bool hasPosition(String sermonId) {
    return getPosition(sermonId) != null;
  }
  
  Future<void> clearPosition(String sermonId) async {
    _positions.remove(sermonId);
    await _savePositions();
  }
  
  Future<void> clearAllPositions() async {
    _positions.clear();
    await _savePositions();
  }
}
