import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _favoritesKey = 'favorite_sermons';
  final ApiService _api = ApiService();
  List<Sermon> _favorites = [];
  bool _isLoaded = false;
  bool _isSyncing = false;

  List<Sermon> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadFavorites();
    _isLoaded = true;
    // Sync with backend in background
    _syncWithBackend();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_favoritesKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        _favorites = json.map((j) => Sermon.fromJson(j)).toList();
        debugPrint('Loaded ${_favorites.length} favorites from local storage');
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _favorites.map((s) => s.toJson()).toList();
      await prefs.setString(_favoritesKey, jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future<void> _syncWithBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      // Fetch favorites from backend
      final response = await _api.get(ApiConstants.favorites);
      if (response.isSuccess) {
        final List<dynamic> data = response.dataList;
        final backendFavorites = data.map((j) => Sermon.fromJson(j['message'] ?? j)).toList();
        
        // Merge: keep local ones not in backend, add backend ones not in local
        final localIds = _favorites.map((s) => s.id).toSet();
        final backendIds = backendFavorites.map((s) => s.id).toSet();
        
        // Add backend favorites not in local
        for (final sermon in backendFavorites) {
          if (!localIds.contains(sermon.id)) {
            _favorites.add(sermon);
          }
        }
        
        // Upload local favorites not in backend
        for (final sermon in _favorites) {
          if (!backendIds.contains(sermon.id)) {
            await _addToBackend(sermon.id);
          }
        }
        
        await _saveFavorites();
        notifyListeners();
        debugPrint('Synced favorites with backend: ${_favorites.length} total');
      }
    } catch (e) {
      debugPrint('Error syncing favorites with backend: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> _addToBackend(String messageId) async {
    try {
      final response = await _api.post(
        ApiConstants.favorites,
        {'message_id': messageId},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error adding favorite to backend: $e');
      return false;
    }
  }

  Future<bool> _removeFromBackend(String messageId) async {
    try {
      final response = await _api.delete('${ApiConstants.favorites}$messageId/');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error removing favorite from backend: $e');
      return false;
    }
  }

  bool isFavorite(String sermonId) {
    return _favorites.any((s) => s.id == sermonId);
  }

  Future<void> addFavorite(Sermon sermon) async {
    if (!isFavorite(sermon.id)) {
      _favorites.insert(0, sermon);
      await _saveFavorites();
      notifyListeners();
      debugPrint('Added to favorites: ${sermon.title}');
      
      // Sync to backend
      _addToBackend(sermon.id);
    }
  }

  Future<void> removeFavorite(String sermonId) async {
    _favorites.removeWhere((s) => s.id == sermonId);
    await _saveFavorites();
    notifyListeners();
    debugPrint('Removed from favorites: $sermonId');
    
    // Sync to backend
    _removeFromBackend(sermonId);
  }

  Future<void> toggleFavorite(Sermon sermon) async {
    if (isFavorite(sermon.id)) {
      await removeFavorite(sermon.id);
    } else {
      await addFavorite(sermon);
    }
  }

  Future<void> refreshFromBackend() async {
    await _syncWithBackend();
  }

  Future<void> clearAll() async {
    // Clear from backend
    for (final sermon in _favorites) {
      await _removeFromBackend(sermon.id);
    }
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }
}
