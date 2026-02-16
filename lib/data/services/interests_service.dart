import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/sermon.dart';
import 'api_service.dart';

class InterestsService {
  static const String _interestsKey = 'user_interests';
  static const String _interestsCompletedKey = 'interests_completed';
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
    
    interestSermons.shuffle();
    return interestSermons.take(count).toList();
  }
}
