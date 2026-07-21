import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

class AppRatingService {
  static const String _hasRatedKey = 'has_shown_rating_popup';
  static const String _playCountKey = 'successful_play_count';
  static AppRatingService? _instance;
  
  SharedPreferences? _prefs;
  final InAppReview _inAppReview = InAppReview.instance;
  
  AppRatingService._();
  
  static AppRatingService get instance {
    _instance ??= AppRatingService._();
    return _instance!;
  }
  
  factory AppRatingService() => instance;
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  bool get hasShownRatingPopup => _prefs?.getBool(_hasRatedKey) ?? false;
  
  Future<void> _markRatingShown() async {
    await _prefs?.setBool(_hasRatedKey, true);
  }
  
  int get successfulPlayCount => _prefs?.getInt(_playCountKey) ?? 0;
  
  Future<void> incrementPlayCount() async {
    final count = successfulPlayCount + 1;
    await _prefs?.setInt(_playCountKey, count);
  }
  
  Future<bool> shouldShowRating() async {
    if (hasShownRatingPopup) return false;
    return successfulPlayCount >= 1;
  }
  
  Future<void> showRatingDialog(BuildContext context) async {
    if (hasShownRatingPopup) return;
    
    await _markRatingShown();
    
    if (!context.mounted) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int selectedRating = 0;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(
                Icons.star_rounded,
                size: 48,
                color: AppColors.primaryGold,
              ),
              const SizedBox(height: 12),
              Text(
                'Enjoying TCGC?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We hope you\'re blessed by the messages. Please take a moment to rate us on the Play Store!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 40,
                          color: index < selectedRating 
                              ? AppColors.primaryGold 
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () async {
                      Navigator.pop(dialogContext);
                      await _openPlayStoreRating();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rate Now'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _openPlayStoreRating() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(appStoreId: 'com.tcgc.tcgc');
      }
    } catch (e) {
      debugPrint('Error opening Play Store rating: $e');
    }
  }
}
