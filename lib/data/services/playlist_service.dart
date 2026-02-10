import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';

class Playlist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Sermon> sermons;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    List<Sermon>? sermons,
  }) : sermons = sermons ?? [];

  int get count => sermons.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'sermons': sermons.map((s) => s.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
      sermons: (json['sermons'] as List<dynamic>?)
          ?.map((s) => Sermon.fromJson(s))
          .toList(),
    );
  }

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<Sermon>? sermons,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sermons: sermons ?? List.from(this.sermons),
    );
  }
}

class PlaylistService extends ChangeNotifier {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  static const String _playlistsKey = 'user_playlists';
  List<Playlist> _playlists = [];
  bool _isLoaded = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  int get count => _playlists.length;

  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadPlaylists();
    _isLoaded = true;
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_playlistsKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        _playlists = json.map((j) => Playlist.fromJson(j)).toList();
        debugPrint('Loaded ${_playlists.length} playlists');
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _playlists.map((p) => p.toJson()).toList();
      await prefs.setString(_playlistsKey, jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  Playlist? getPlaylist(String playlistId) {
    try {
      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      return null;
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
    );
    _playlists.insert(0, playlist);
    await _savePlaylists();
    notifyListeners();
    debugPrint('Created playlist: $name');
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePlaylists();
    notifyListeners();
    debugPrint('Deleted playlist: $playlistId');
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(name: newName);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> addToPlaylist(String playlistId, Sermon sermon) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.sermons.any((s) => s.id == sermon.id)) {
        final updatedSermons = List<Sermon>.from(playlist.sermons)..add(sermon);
        _playlists[index] = playlist.copyWith(sermons: updatedSermons);
        await _savePlaylists();
        notifyListeners();
        debugPrint('Added ${sermon.title} to playlist ${playlist.name}');
      }
    }
  }

  Future<void> removeFromPlaylist(String playlistId, String sermonId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedSermons = playlist.sermons.where((s) => s.id != sermonId).toList();
      _playlists[index] = playlist.copyWith(sermons: updatedSermons);
      await _savePlaylists();
      notifyListeners();
    }
  }

  bool isInPlaylist(String playlistId, String sermonId) {
    final playlist = getPlaylist(playlistId);
    return playlist?.sermons.any((s) => s.id == sermonId) ?? false;
  }

  List<Playlist> getPlaylistsContaining(String sermonId) {
    return _playlists.where((p) => p.sermons.any((s) => s.id == sermonId)).toList();
  }

  Future<void> clearAll() async {
    _playlists.clear();
    await _savePlaylists();
    notifyListeners();
  }
}
