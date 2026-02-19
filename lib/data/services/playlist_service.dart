import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

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
    List<Sermon> sermonsList = [];
    if (json['sermons'] != null) {
      sermonsList = (json['sermons'] as List<dynamic>)
          .map((s) => Sermon.fromJson(s['message'] ?? s))
          .toList();
    } else if (json['messages'] != null) {
      sermonsList = (json['messages'] as List<dynamic>)
          .map((s) => Sermon.fromJson(s['message'] ?? s))
          .toList();
    }
    
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      sermons: sermonsList,
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
  final ApiService _api = ApiService();
  List<Playlist> _playlists = [];
  bool _isLoaded = false;
  bool _isSyncing = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  int get count => _playlists.length;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadPlaylists();
    _isLoaded = true;
    // Sync with backend in background
    _syncWithBackend();
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_playlistsKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        _playlists = json.map((j) => Playlist.fromJson(j)).toList();
        debugPrint('Loaded ${_playlists.length} playlists from local storage');
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

  Future<void> _syncWithBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      // Fetch playlists from backend
      final response = await _api.get(ApiConstants.playlists);
      if (response.isSuccess) {
        final List<dynamic> data = response.dataList;
        final backendPlaylists = data.map((j) => Playlist.fromJson(j)).toList();
        
        // Merge strategy: Backend is source of truth after first sync
        // Replace local with backend data
        if (backendPlaylists.isNotEmpty) {
          _playlists = backendPlaylists;
        } else if (_playlists.isNotEmpty) {
          // If backend is empty but we have local playlists, upload them
          for (final playlist in _playlists) {
            await _createOnBackend(playlist);
          }
        }
        
        await _savePlaylists();
        notifyListeners();
        debugPrint('Synced playlists with backend: ${_playlists.length} total');
      }
    } catch (e) {
      debugPrint('Error syncing playlists with backend: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<String?> _createOnBackend(Playlist playlist) async {
    try {
      final response = await _api.post(
        ApiConstants.playlists,
        {
          'name': playlist.name,
          'message_ids': playlist.sermons.map((s) => s.id).toList(),
        },
      );
      if (response.isSuccess) {
        return response.data['id']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Error creating playlist on backend: $e');
      return null;
    }
  }

  Future<bool> _updateOnBackend(String playlistId, {String? name, List<String>? messageIds}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (messageIds != null) data['message_ids'] = messageIds;
      
      final response = await _api.patch(
        '${ApiConstants.playlists}$playlistId/',
        data,
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error updating playlist on backend: $e');
      return false;
    }
  }

  Future<bool> _deleteFromBackend(String playlistId) async {
    try {
      final response = await _api.delete('${ApiConstants.playlists}$playlistId/');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error deleting playlist from backend: $e');
      return false;
    }
  }

  Future<bool> _addMessageToBackend(String playlistId, String messageId) async {
    try {
      final response = await _api.post(
        '${ApiConstants.playlists}$playlistId/add_message/',
        {'message_id': messageId},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error adding message to playlist on backend: $e');
      return false;
    }
  }

  Future<bool> _removeMessageFromBackend(String playlistId, String messageId) async {
    try {
      final response = await _api.post(
        '${ApiConstants.playlists}$playlistId/remove_message/',
        {'message_id': messageId},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error removing message from playlist on backend: $e');
      return false;
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
    // Create locally first with temporary ID
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    var playlist = Playlist(
      id: tempId,
      name: name,
      createdAt: DateTime.now(),
    );
    
    _playlists.insert(0, playlist);
    await _savePlaylists();
    notifyListeners();
    debugPrint('Created playlist locally: $name');
    
    // Create on backend and update ID
    final backendId = await _createOnBackend(playlist);
    if (backendId != null && backendId != tempId) {
      final index = _playlists.indexWhere((p) => p.id == tempId);
      if (index != -1) {
        playlist = playlist.copyWith(id: backendId);
        _playlists[index] = playlist;
        await _savePlaylists();
        notifyListeners();
      }
    }
    
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePlaylists();
    notifyListeners();
    debugPrint('Deleted playlist: $playlistId');
    
    // Delete from backend
    _deleteFromBackend(playlistId);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(name: newName);
      await _savePlaylists();
      notifyListeners();
      
      // Update on backend
      _updateOnBackend(playlistId, name: newName);
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
        
        // Sync to backend
        _addMessageToBackend(playlistId, sermon.id);
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
      
      // Sync to backend
      _removeMessageFromBackend(playlistId, sermonId);
    }
  }

  bool isInPlaylist(String playlistId, String sermonId) {
    final playlist = getPlaylist(playlistId);
    return playlist?.sermons.any((s) => s.id == sermonId) ?? false;
  }

  List<Playlist> getPlaylistsContaining(String sermonId) {
    return _playlists.where((p) => p.sermons.any((s) => s.id == sermonId)).toList();
  }

  Future<void> refreshFromBackend() async {
    _isLoaded = false;
    _playlists.clear();
    await _loadPlaylists();
    _isLoaded = true;
    await _syncWithBackend();
  }

  Future<void> clearAll() async {
    // Delete all from backend
    for (final playlist in _playlists) {
      await _deleteFromBackend(playlist.id);
    }
    _playlists.clear();
    await _savePlaylists();
    notifyListeners();
  }
}
