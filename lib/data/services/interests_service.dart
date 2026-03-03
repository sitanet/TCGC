import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';
import 'api_service.dart';

class InterestsService {
  static const String _interestsKey = 'user_interests';
  static const String _interestsCompletedKey = 'interests_completed';
  static const String _dailyPicksKey = 'daily_picks';
  static const String _dailyPicksDateKey = 'daily_picks_date';
  static InterestsService? _instance;
  
  SharedPreferences? _prefs;
  List<String> _selectedCategoryIds = [];
  bool _interestsCompleted = false;
  final ApiService _api = ApiService();
  
  InterestsService._();
  
  static InterestsService get instance {
    _instance ??= InterestsService._();
    return _instance!;
  }
  
  factory InterestsService() => instance;
  
  List<String> get selectedCategoryIds => _selectedCategoryIds;
  bool get interestsCompleted => _interestsCompleted;
  bool get hasSelectedInterests => _selectedCategoryIds.isNotEmpty;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadInterests();
  }
  
  void _loadInterests() {
    final data = _prefs?.getString(_interestsKey);
    if (data != null) {
      try {
        final List<dynamic> json = jsonDecode(data);
        _selectedCategoryIds = json.cast<String>();
      } catch (e) {
        _selectedCategoryIds = [];
      }
    }
    _interestsCompleted = _prefs?.getBool(_interestsCompletedKey) ?? false;
  }
  
  Future<void> saveInterests(List<String> categoryIds) async {
    _selectedCategoryIds = categoryIds;
    await _prefs?.setString(_interestsKey, jsonEncode(categoryIds));
    await _prefs?.setBool(_interestsCompletedKey, true);
    _interestsCompleted = true;
    
    // Also save to backend
    await _saveToBackend(categoryIds);
  }
  
  Future<bool> _saveToBackend(List<String> categoryIds) async {
    try {
      final response = await _api.post(
        'user/interests/',
        {'category_ids': categoryIds},
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
  
  Future<List<String>?> loadFromBackend() async {
    try {
      final response = await _api.get('user/interests/');
      if (response.isSuccess) {
        final List<dynamic> data = response.data['category_ids'] ?? [];
        final categoryIds = data.cast<String>();
        if (categoryIds.isNotEmpty) {
          _selectedCategoryIds = categoryIds;
          await _prefs?.setString(_interestsKey, jsonEncode(categoryIds));
          await _prefs?.setBool(_interestsCompletedKey, true);
          _interestsCompleted = true;
        }
        return categoryIds;
      }
    } catch (e) {
      // Silently fail - will use local data
    }
    return null;
  }
  
  bool isCategorySelected(String categoryId) {
    return _selectedCategoryIds.contains(categoryId);
  }
  
  Future<void> clearInterests() async {
    _selectedCategoryIds = [];
    _interestsCompleted = false;
    await _prefs?.remove(_interestsKey);
    await _prefs?.remove(_interestsCompletedKey);
  }
  
  List<Sermon> getRandomMessagesFromInterests(List<Sermon> allSermons, {int count = 3}) {
    if (_selectedCategoryIds.isEmpty) return [];
    
    final interestSermons = allSermons.where((sermon) {
      return _selectedCategoryIds.contains(sermon.category) ||
             _selectedCategoryIds.any((id) => sermon.categoryName.toLowerCase() == id.toLowerCase());
    }).toList();
    
    if (interestSermons.isEmpty) return [];
    
    // Check if we have valid daily picks cached
    final todayStr = _getTodayString();
    final cachedDateStr = _prefs?.getString(_dailyPicksDateKey);
    
    if (cachedDateStr == todayStr) {
      // Try to load cached picks
      final cachedPicksJson = _prefs?.getString(_dailyPicksKey);
      if (cachedPicksJson != null) {
        try {
          final List<dynamic> cachedIds = jsonDecode(cachedPicksJson);
          final cachedSermons = <Sermon>[];
          for (final id in cachedIds) {
            final sermon = interestSermons.where((s) => s.id == id).firstOrNull;
            if (sermon != null) {
              cachedSermons.add(sermon);
            }
          }
          // Return cached if we have enough valid sermons
          if (cachedSermons.length >= count || cachedSermons.length == interestSermons.length) {
            return cachedSermons.take(count).toList();
          }
        } catch (e) {
          // Invalid cache, will generate new picks
        }
      }
    }
    
    // Generate new random picks for today
    interestSermons.shuffle();
    final picks = interestSermons.take(count).toList();
    
    // Cache the picks
    final pickIds = picks.map((s) => s.id).toList();
    _prefs?.setString(_dailyPicksKey, jsonEncode(pickIds));
    _prefs?.setString(_dailyPicksDateKey, todayStr);
    
    return picks;
  }
  
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  Future<void> clearDailyPicks() async {
    await _prefs?.remove(_dailyPicksKey);
    await _prefs?.remove(_dailyPicksDateKey);
  }
}
