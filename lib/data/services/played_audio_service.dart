import 'package:shared_preferences/shared_preferences.dart';

class PlayedAudioService {
  static const String _storageKey = 'played_audio_ids';
  static const String _viewedCategoriesKey = 'viewed_category_ids';
  static PlayedAudioService? _instance;
  
  SharedPreferences? _prefs;
  Set<String> _playedIds = {};
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
    _loadViewedCategories();
  }
  
  void _loadPlayedIds() {
    final stored = _prefs?.getStringList(_storageKey) ?? [];
    _playedIds = stored.toSet();
  }
  
  void _loadViewedCategories() {
    final stored = _prefs?.getStringList(_viewedCategoriesKey) ?? [];
    _viewedCategoryIds = stored.toSet();
  }
  
  Future<void> _savePlayedIds() async {
    await _prefs?.setStringList(_storageKey, _playedIds.toList());
  }
  
  Future<void> _saveViewedCategories() async {
    await _prefs?.setStringList(_viewedCategoriesKey, _viewedCategoryIds.toList());
  }
  
  bool isPlayed(String audioId) {
    return _playedIds.contains(audioId);
  }
  
  Future<void> markAsPlayed(String audioId) async {
    if (_playedIds.contains(audioId)) return;
    _playedIds.add(audioId);
    await _savePlayedIds();
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
  Set<String> get viewedCategoryIds => Set.from(_viewedCategoryIds);
}
