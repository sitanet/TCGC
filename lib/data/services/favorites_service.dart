import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _favoritesKey = 'favorite_sermons';
  List<Sermon> _favorites = [];
  bool _isLoaded = false;

  List<Sermon> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;

  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadFavorites();
    _isLoaded = true;
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_favoritesKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        _favorites = json.map((j) => Sermon.fromJson(j)).toList();
        debugPrint('Loaded ${_favorites.length} favorites');
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

  bool isFavorite(String sermonId) {
    return _favorites.any((s) => s.id == sermonId);
  }

  Future<void> addFavorite(Sermon sermon) async {
    if (!isFavorite(sermon.id)) {
      _favorites.insert(0, sermon);
      await _saveFavorites();
      notifyListeners();
      debugPrint('Added to favorites: ${sermon.title}');
    }
  }

  Future<void> removeFavorite(String sermonId) async {
    _favorites.removeWhere((s) => s.id == sermonId);
    await _saveFavorites();
    notifyListeners();
    debugPrint('Removed from favorites: $sermonId');
  }

  Future<void> toggleFavorite(Sermon sermon) async {
    if (isFavorite(sermon.id)) {
      await removeFavorite(sermon.id);
    } else {
      await addFavorite(sermon);
    }
  }

  Future<void> clearAll() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }
}
