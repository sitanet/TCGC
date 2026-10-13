import 'package:shared_preferences/shared_preferences.dart';

class PlayedAudioService {
  static const String _storageKey = 'played_audio_ids';
  static const String _recentAudioKey = 'recently_played_audio_ids';
  static const String _viewedCategoriesKey = 'viewed_category_ids';
  static PlayedAudioService? _instance;
  
  SharedPreferences? _prefs;
  Set<String> _playedIds = {};
  List<String> _recentlyPlayedIds = [];
  Set<String> _viewedCategoryIds = {};
  
  PlayedAudioService._();
  
  static PlayedAudioService get instance {
    _instance ??= PlayedAudioService._();
    return _instance!;
  }
  
  factory PlayedAudioService() => instance;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadPlayedIds();
    _loadRecentAudioIds();
    _loadViewedCategories();
  }
  
  void _loadPlayedIds() {
    final stored = _prefs?.getStringList(_storageKey) ?? [];
    _playedIds = stored.toSet();
  }

  void _loadRecentAudioIds() {
    _recentlyPlayedIds = _prefs?.getStringList(_recentAudioKey) ?? [];
  }
  
  void _loadViewedCategories() {
    final stored = _prefs?.getStringList(_viewedCategoriesKey) ?? [];
    _viewedCategoryIds = stored.toSet();
  }
  
  Future<void> _savePlayedIds() async {
    await _prefs?.setStringList(_storageKey, _playedIds.toList());
  }

  Future<void> _saveRecentAudioIds() async {
    await _prefs?.setStringList(_recentAudioKey, _recentlyPlayedIds);
  }
  
  Future<void> _saveViewedCategories() async {
    await _prefs?.setStringList(_viewedCategoriesKey, _viewedCategoryIds.toList());
  }
  
  bool isPlayed(String audioId) {
    return _playedIds.contains(audioId);
  }
  
  Future<void> markAsPlayed(String audioId) async {
    if (!_playedIds.contains(audioId)) {
      _playedIds.add(audioId);
      await _savePlayedIds();
    }
    // Update ordered recently played list (most recent first, max 20)
    _recentlyPlayedIds.remove(audioId);
    _recentlyPlayedIds.insert(0, audioId);
    if (_recentlyPlayedIds.length > 20) {
      _recentlyPlayedIds = _recentlyPlayedIds.sublist(0, 20);
    }
    await _saveRecentAudioIds();
  }
  
  bool isCategoryViewed(String categoryId) {
    return _viewedCategoryIds.contains(categoryId);
  }
  
  Future<void> markCategoryViewed(String categoryId) async {
    if (_viewedCategoryIds.contains(categoryId)) return;
    _viewedCategoryIds.add(categoryId);
    await _saveViewedCategories();
  }
  
  Set<String> get playedIds => Set.from(_playedIds);
  List<String> get recentlyPlayedIds => List.unmodifiable(_recentlyPlayedIds);
  Set<String> get viewedCategoryIds => Set.from(_viewedCategoryIds);
}
