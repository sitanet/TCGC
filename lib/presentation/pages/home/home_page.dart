import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../main.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/interests_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/played_audio_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/beginner_category.dart';

import '../../widgets/resume_playback_sheet.dart';
import '../audio/audio_list_page.dart';
import '../profile/profile_page.dart';
import '../notifications/notifications_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ask_wing_ai/ask_wing_ai_chat_page.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import '../../widgets/ask_wing_ai/ai_consent_dialog.dart';
import '../../../data/services/church_announcement_service.dart';
import '../../widgets/church_announcement_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final DataService _dataService = DataService();
  final InterestsService _interestsService = InterestsService();

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatDateClean(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[date.month - 1];
    return '${date.day} $monthName ${date.year}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '45:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  // Persistent in-memory cache for instant display across tab switches / navigation
  static List<Sermon> _staticSermons = [];
  static List<BeginnerCategory> _staticBeginnerCategories = [];
  static List<Sermon> _staticRecommendedSermons = [];
  static List<Sermon> _staticTrendingSermons = [];

  List<Sermon> _sermons = [];
  List<BeginnerCategory> _beginnerCategories = [];
  List<Sermon> _recommendedSermons = [];
  List<Sermon> _trendingSermons = [];
  bool _isLoading = true;
  late final ScrollController _homeScrollController;
  bool _isScrolledPastHeader = false;

  @override
  void initState() {
    super.initState();
    // 1. Immediately show cached data from memory if previously loaded (instant 0ms)
    if (_staticSermons.isNotEmpty) {
      _sermons = _staticSermons;
      _beginnerCategories = _staticBeginnerCategories;
      _recommendedSermons = _staticRecommendedSermons;
      _trendingSermons = _staticTrendingSermons;
      _isLoading = false;
    }

    _homeScrollController = ScrollController();
    _homeScrollController.addListener(_onHomeScroll);
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
      _loadData();
      _checkChurchAnnouncement();
    });
  }

  Future<void> _initServices() async {
    await _interestsService.initialize();
  }



  Future<void> _checkChurchAnnouncement() async {

    try {

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;



      final announcement =

          await ChurchAnnouncementService().getLatestAnnouncement();

      if (announcement != null && mounted) {

        await ChurchAnnouncementDialog.show(context, announcement);

      }

    } catch (e) {

      debugPrint('Error checking church announcement: ');

    }

  }



  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    // Only show full loading spinner if we have NO cached data at all
    if (_sermons.isEmpty && _staticSermons.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Get user permissions for filtering
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      // Filter function to avoid code duplication
      bool canAccessSermon(Sermon sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }

      // Load sermons and beginner categories from local database / disk cache
      final allSermons = await _dataService.getMessages(
        forceRefresh: forceRefresh,
      );
      final sermons = allSermons.where(canAccessSermon).toList();
      final beginnerCats = await _dataService.getBeginnerCategories(forceRefresh: forceRefresh);

      // If no custom beginner categories are returned from API, automatically group existing sermons into categories
      List<BeginnerCategory> resolvedCategories = beginnerCats;
      if (resolvedCategories.isEmpty && sermons.isNotEmpty) {
        final Map<String, List<Sermon>> grouped = {};
        for (final s in sermons) {
          final catName = s.categoryName.isNotEmpty ? s.categoryName : 'Spiritual Growth';
          grouped.putIfAbsent(catName, () => []).add(s);
        }
        resolvedCategories = grouped.entries.map((e) {
          return BeginnerCategory(
            id: e.value.first.category.isNotEmpty ? e.value.first.category : e.key,
            name: e.key,
            description: 'Foundational teachings on ${e.key}',
            imageUrl: e.value.first.imageUrl,
            sermonCount: e.value.length,
            sermons: e.value,
          );
        }).toList();
      }

      if (mounted) {
        setState(() {
          _sermons = sermons;
          _beginnerCategories = resolvedCategories;
          _isLoading = false; // Show content immediately from database
        });
        _staticSermons = sermons;
        _staticBeginnerCategories = resolvedCategories;
      }

      // Load events and recommended in parallel (offline-first)
      _loadRecommendedAsync(forceRefresh, canAccessSermon);
      _loadTrendingAsync(forceRefresh, canAccessSermon);

      // Automatically refresh latest messages and data from server in background on app launch
      // so user does not need to swipe down to see the latest messages!
      if (!forceRefresh) {
        _refreshHomeDataInBackground();
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Automatically fetches latest messages and content from server in the background
  /// without blocking UI or requiring user to swipe down.
  Future<void> _refreshHomeDataInBackground() async {
    try {
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      bool canAccessSermon(Sermon sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }

      // 1. Fetch fresh messages and beginner categories from server
      final freshSermonsRaw = await _dataService.getMessages(forceRefresh: true);
      final freshBeginnerCats = await _dataService.getBeginnerCategories(forceRefresh: true);

      // Also refresh categories and transcripts in background so newest items are ready immediately
      unawaited(_dataService.getMessageCategories(forceRefresh: true));
      unawaited(_dataService.getTranscripts(forceRefresh: true));

      if (!mounted) return;

      if (freshSermonsRaw.isNotEmpty) {
        final sermons = freshSermonsRaw.where(canAccessSermon).toList();

        List<BeginnerCategory> resolvedCategories = freshBeginnerCats;
        if (resolvedCategories.isEmpty && sermons.isNotEmpty) {
          final Map<String, List<Sermon>> grouped = {};
          for (final s in sermons) {
            final catName = s.categoryName.isNotEmpty ? s.categoryName : 'Spiritual Growth';
            grouped.putIfAbsent(catName, () => []).add(s);
          }
          resolvedCategories = grouped.entries.map((e) {
            return BeginnerCategory(
              id: e.value.first.category.isNotEmpty ? e.value.first.category : e.key,
              name: e.key,
              description: 'Foundational teachings on ${e.key}',
              imageUrl: e.value.first.imageUrl,
              sermonCount: e.value.length,
              sermons: e.value,
            );
          }).toList();
        }

        setState(() {
          _sermons = sermons;
          _beginnerCategories = resolvedCategories;
        });
        _staticSermons = sermons;
        _staticBeginnerCategories = resolvedCategories;
      }

      // Also refresh events and recommended
      _loadRecommendedAsync(true, canAccessSermon);
      _loadTrendingAsync(true, canAccessSermon);
    } catch (e) {
      debugPrint('Background home refresh error: $e');
    }
  }

  // Async loaders that don't block UI


  Future<void> _loadRecommendedAsync(
    bool forceRefresh,
    bool Function(Sermon) canAccessSermon,
  ) async {
    try {
      final allRecommended = await _dataService.getRecommendedMessages(
        forceRefresh: forceRefresh,
      );
      final recommended = allRecommended.where(canAccessSermon).toList();
      if (mounted) {
        setState(() => _recommendedSermons = recommended);
      }
      _staticRecommendedSermons = recommended;
    } catch (e) {
      debugPrint('Recommended load error: $e');
    }
  }

  Future<void> _loadTrendingAsync(
    bool forceRefresh,
    bool Function(Sermon) canAccessSermon,
  ) async {
    try {
      final allTrending = await _dataService.getTrendingMessages(
        forceRefresh: forceRefresh,
      );
      final trending = allTrending.where(canAccessSermon).toList();
      if (mounted) {
        setState(() => _trendingSermons = trending);
      }
      _staticTrendingSermons = trending;
    } catch (e) {
      debugPrint('Trending load error: $e');
    }
  }

  void _onHomeScroll() {
    if (!mounted) return;
    final isScrolledPast = _homeScrollController.offset > 120;
    if (isScrolledPast != _isScrolledPastHeader) {
      setState(() {
        _isScrolledPastHeader = isScrolledPast;
      });
    }
  }

  @override
  void dispose() {
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);

    final statusBarIconBrightness = _isScrolledPastHeader
        ? (isDark ? Brightness.light : Brightness.dark)
        : Brightness.light;
    final statusBarBrightness = _isScrolledPastHeader
        ? (isDark ? Brightness.dark : Brightness.light)
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: AppColors.primaryGold,
          child: SingleChildScrollView(
            controller: _homeScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildBeginnerCategories(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildTrendingMessages(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildYouMightAlsoLike(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildRecentActivities(context, isDark),
                SizedBox(height: spacing * 6),
              ],
            ),
          ),
        ),
        floatingActionButton: GestureDetector(
          onTap: () async {
            final hasConsent = await AIConsentDialog.hasConsented();
            if (!context.mounted) return;
            if (!hasConsent) {
              final granted = await AIConsentDialog.showConsentDialog(context);
              if (!granted || !context.mounted) return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AskWingAICubit>(),
                  child: const AskWingAIChatPage(),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 7),
                Text(
                  'Ask Wing AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    final borderRadius = Responsive.largeBorderRadius(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Responsive sizing
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    // Logo size based on device
    final logoSize = isMobile
        ? 80.0
        : isTablet
        ? 100.0
        : 120.0;

    // Font sizes based on device
    final welcomeFontSize = isMobile
        ? 14.0
        : isTablet
        ? 16.0
        : 18.0;
    final titleFontSize = isMobile
        ? 18.0
        : isTablet
        ? 22.0
        : 26.0;
    final subtitleFontSize = isMobile
        ? 12.0
        : isTablet
        ? 14.0
        : 16.0;
    final nameFontSize = isMobile
        ? 16.0
        : isTablet
        ? 18.0
        : 20.0;

    // Avatar size based on device
    final avatarRadius = isMobile
        ? 24.0
        : isTablet
        ? 30.0
        : 36.0;

    // Padding based on device
    final horizontalPadding = isMobile
        ? 20.0
        : isTablet
        ? 30.0
        : 40.0;
    final bottomPadding = isMobile
        ? 20.0
        : isTablet
        ? 25.0
        : 30.0;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        child: Container(
          width: screenWidth,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/home_page.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(borderRadius),
              bottomRight: Radius.circular(borderRadius),
            ),
          ),
          child: Stack(
            children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: bottomPadding,
                top: statusBarHeight + 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Centered logo and text
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 30.0 : 40.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/tcgc_logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.church,
                                  color: Colors.white,
                                  size: logoSize * 0.5,
                                ),
                              ),
                        ),
                        SizedBox(width: isMobile ? 16 : 24),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                    fontSize: welcomeFontSize,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The CityGate Church',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: titleFontSize,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Where sons are raised',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white54,
                                    fontSize: subtitleFontSize,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Bottom row with name, notification icon and profile picture
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Builder(
                      builder: (context) {
                        final authProvider = ref.watch(
                          authChangeNotifierProvider,
                        );
                        final user = authProvider.user;
                        final displayName = user != null
                            ? '${user.firstName} ${user.lastName}'.trim()
                            : 'Guest';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayName.isNotEmpty ? displayName : 'Welcome',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: nameFontSize,
                                  ),
                            ),
                            // Profile avatar
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilePage(),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: AppColors.primaryGold,
                                backgroundImage:
                                    user?.photoUrl != null &&
                                        user!.photoUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        user.photoUrl!,
                                        maxWidth: 200,
                                        maxHeight: 200,
                                        cacheManager: CustomImageCacheManager.instance,
                                      )
                                    : null,
                                child:
                                    user?.photoUrl == null ||
                                        user!.photoUrl!.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: avatarRadius * 1.2,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Notification icon positioned at top right (overlaid on background)
            Positioned(
              top: statusBarHeight + 12,
              right: horizontalPadding,
              child: Builder(
                builder: (context) {
                  final notificationProvider = ref.watch(
                    notificationChangeNotifierProvider,
                  );
                  final unreadCount = notificationProvider.unreadCount;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                        // Unread badge
                        if (unreadCount > 0)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // [REMOVED] Upcoming Events section removed from Home Page

  Widget _buildBeginnerCategories(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    // 3 rows x 3 columns = 9 compact cards
    final displayedCategories = _beginnerCategories.take(9).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Welcome to CityGate Mobile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: subtitleFontSize,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Essential series to build your spiritual journey',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark.withValues(alpha: 0.8)
                        : AppColors.textSecondaryLight.withValues(alpha: 0.8),
                    fontSize: Responsive.value(context, mobile: 12.5, tablet: 14.0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing * 0.8),
        if (_beginnerCategories.isEmpty && _isLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: Responsive.value(context, mobile: 8.0, tablet: 12.0),
              mainAxisSpacing: Responsive.value(context, mobile: 8.0, tablet: 12.0),
              childAspectRatio: Responsive.value(context, mobile: 0.85, tablet: 0.90, desktop: 0.95),
            ),
            itemCount: 9,
            itemBuilder: (context, index) => _buildCategoryShimmerCard(context, isDark),
          )
        else if (_beginnerCategories.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      color: AppColors.primaryGold.withValues(alpha: 0.7),
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No categories available yet.',
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: Responsive.value(context, mobile: 8.0, tablet: 12.0),
              mainAxisSpacing: Responsive.value(context, mobile: 8.0, tablet: 12.0),
              childAspectRatio: Responsive.value(context, mobile: 0.85, tablet: 0.90, desktop: 0.95),
            ),
            itemCount: displayedCategories.length,
            itemBuilder: (context, index) {
              final cat = displayedCategories[index];
              return _buildBeginnerCategoryCard(context, isDark, cat);
            },
          ),
      ],
    );
  }

  Widget _buildBeginnerCategoryCard(
    BuildContext context,
    bool isDark,
    BeginnerCategory category,
  ) {
    final titleFontSize = Responsive.value(context, mobile: 10.5, tablet: 12.5);
    final badgeFontSize = Responsive.value(context, mobile: 8.5, tablet: 10.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioListPage(
              category: category.name,
              audioItems: category.sermons,
              categories: _beginnerCategories.map((c) => c.name).toList(),
              beginnerCategories: _beginnerCategories,
              isDirectCollection: true,
              headerImageUrl: category.imageUrl,
              headerDescription: category.description,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: isDark ? 0.3 : 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Artwork
              _buildCategoryCardImage(
                category.imageUrl ??
                    (category.sermons.isNotEmpty
                        ? category.sermons.first.imageUrl
                        : null),
                isDark,
              ),

              // Gradient Overlay for Readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.2, 0.6, 1.0],
                  ),
                ),
              ),

              // Top Badge: Message Count
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.6),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    '${category.sermonCount} msg',
                    style: TextStyle(
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              ),

              // Bottom Title (compact)
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryShimmerCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildCategoryCardImage(String? imageUrl, bool isDark) {
    Widget placeholder = Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 40,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: CustomImageCacheManager.instance,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 300,
        memCacheHeight: 300,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildTrendingMessages(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    // Pick 3 most listened / trending messages across all users
    List<Sermon> displayList = _trendingSermons;
    if (displayList.isEmpty) {
      displayList = _recommendedSermons;
    }
    if (displayList.isEmpty) {
      displayList = _sermons;
    }

    final trendingPicks = displayList.take(3).toList();
    if (trendingPicks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trending Messages',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: subtitleFontSize,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryGold.withValues(alpha: 0.15)
                      : const Color(0xFFFDF8EB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                    width: 0.9,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 13,
                      color: AppColors.primaryGold,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Most Listened',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing * 0.9),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: trendingPicks.map((sermon) {
              return _buildMostListenedCard(context, isDark, sermon);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMostListenedCard(BuildContext context, bool isDark, Sermon sermon) {
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final authProvider = ref.watch(authChangeNotifierProvider);
    final user = authProvider.user;
    final isServiceTeamMember = user?.isServiceTeamMember ?? false;
    final isGeneralMarried = user?.isGeneralMarried ?? false;
    final isInHouseMarried = user?.isInHouseMarried ?? false;
    final isLocked =
        (sermon.isServiceTeamOnly && !isServiceTeamMember) ||
        (sermon.isGeneralMarriedOnly && !isGeneralMarried) ||
        (sermon.isInHouseMarriedOnly && !isInHouseMarried);
    final isCurrentlyPlaying =
        audioProvider.currentSermon?.id == sermon.id && audioProvider.isPlaying;

    final imageWidth = Responsive.value(context, mobile: 94.0, tablet: 115.0, desktop: 125.0);
    final imageHeight = Responsive.value(context, mobile: 64.0, tablet: 75.0, desktop: 80.0);
    final titleFontSize = Responsive.value(context, mobile: 14.5, tablet: 16.0);
    final speakerFontSize = Responsive.value(context, mobile: 12.5, tablet: 13.5);
    final playBtnSize = Responsive.value(context, mobile: 42.0, tablet: 46.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 11.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1D2A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (isLocked) {
              _showLockedMessage(context, isDark);
              return;
            }
            ResumePlaybackHelper.handleMessageTap(
              context: context,
              ref: ref,
              sermon: sermon,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              children: [
                // 1. Thumbnail Image
                Container(
                  width: imageWidth,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildSermonImage(sermon, isDark),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Middle Content (Title, Speaker, Duration)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sermon.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF151515),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sermon.speaker?.isNotEmpty == true ? sermon.speaker! : 'The CityGate Church',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: speakerFontSize,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFB0AFC7) : const Color(0xFF535176),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13.5,
                            color: Color(0xFF1B873F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(sermon.duration),
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B873F),
                            ),
                          ),
                          if (isLocked) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.lock,
                              size: 13,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Play Button
                GestureDetector(
                  onTap: () {
                    if (isLocked) {
                      _showLockedMessage(context, isDark);
                      return;
                    }
                    ResumePlaybackHelper.handleMessageTap(
                      context: context,
                      ref: ref,
                      sermon: sermon,
                    );
                  },
                  child: Container(
                    width: playBtnSize,
                    height: playBtnSize,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isCurrentlyPlaying
                          ? const Icon(Icons.pause_rounded, color: Colors.white, size: 22)
                          : isLocked
                              ? const Icon(Icons.lock_rounded, color: Colors.white, size: 18)
                              : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYouMightAlsoLike(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    List<Sermon> displayList = _recommendedSermons;
    if (displayList.isEmpty) {
      displayList = _sermons;
    }

    final recommendedPicks = displayList.take(12).toList();
    if (recommendedPicks.isEmpty) return const SizedBox.shrink();

    final cardWidth = Responsive.value(context, mobile: 140.0, tablet: 180.0, desktop: 200.0);
    final containerHeight = cardWidth + 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            'You Might Also Like',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: subtitleFontSize,
                ),
          ),
        ),
        SizedBox(height: spacing * 0.8),
        SizedBox(
          height: containerHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: recommendedPicks.length,
            itemBuilder: (context, index) {
              final sermon = recommendedPicks[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: _buildCleanSermonCard(
                  context,
                  isDark,
                  sermon,
                  cardWidth,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Clean Sermon Card - artwork thumbnail with title and minister name underneath
  Widget _buildCleanSermonCard(
    BuildContext context,
    bool isDark,
    Sermon sermon,
    double cardWidth,
  ) {
    final authProvider = ref.read(authChangeNotifierProvider);
    final user = authProvider.user;
    final isServiceTeamMember = user?.isServiceTeamMember ?? false;
    final isGeneralMarried = user?.isGeneralMarried ?? false;
    final isInHouseMarried = user?.isInHouseMarried ?? false;
    final isLocked =
        (sermon.isServiceTeamOnly && !isServiceTeamMember) ||
        (sermon.isGeneralMarriedOnly && !isGeneralMarried) ||
        (sermon.isInHouseMarriedOnly && !isInHouseMarried);

    final titleFontSize = Responsive.value(context, mobile: 13.0, tablet: 14.5);
    final speakerFontSize = Responsive.value(context, mobile: 11.5, tablet: 13.0);
    final metaFontSize = Responsive.value(context, mobile: 10.5, tablet: 11.5);

    final categoryCode = sermon.categoryName.isNotEmpty
        ? sermon.categoryName
        : (sermon.category.isNotEmpty ? sermon.category : '');

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showLockedMessage(context, isDark);
          return;
        }
        ResumePlaybackHelper.handleMessageTap(
          context: context,
          ref: ref,
          sermon: sermon,
        );
      },
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Clean Artwork Thumbnail (No overlays on top of the image)
            Container(
              width: cardWidth,
              height: cardWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildSermonImage(sermon, isDark),
              ),
            ),
            const SizedBox(height: 7),

            // 2. Title (under the card)
            Row(
              children: [
                Expanded(
                  child: Text(
                    sermon.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      height: 1.2,
                    ),
                  ),
                ),
                if (isLocked)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.lock,
                      size: 13,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),

            // 3. Minister / Speaker (under the card)
            Text(
              sermon.speaker ?? 'TCGC',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: speakerFontSize,
                fontWeight: FontWeight.normal,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 2),

            // 4. Date • Category (under the card)
            Text(
              sermon.date != null
                  ? (categoryCode.isNotEmpty
                      ? '${_formatDateClean(sermon.date!)} • $categoryCode'
                      : _formatDateClean(sermon.date!))
                  : categoryCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: metaFontSize,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context, bool isDark) {
    final playedService = PlayedAudioService.instance;
    final recentIds = playedService.recentlyPlayedIds;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final isTabletOrLarger = !Responsive.isMobile(context);

    // Filter sermons to those the user actually listened to, in order of playback
    final Map<String, Sermon> sermonMap = {
      for (final s in _sermons) s.id: s
    };

    List<Sermon> listenedSermons = [];
    for (final id in recentIds) {
      final s = sermonMap[id];
      if (s != null) {
        listenedSermons.add(s);
      }
      if (listenedSermons.length >= 4) break;
    }

    // Fallback: If user hasn't listened to any audio yet, gracefully display latest 4 items
    final hasListeningHistory = listenedSermons.isNotEmpty;
    final displaySermons = hasListeningHistory
        ? listenedSermons
        : _sermons.take(4).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasListeningHistory ? 'Recently Listened' : 'Recent Activities',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.subtitleFontSize(context),
                    ),
              ),
              if (hasListeningHistory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (displaySermons.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent activities yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ),
            )
          else if (isTabletOrLarger)
            // 2-column grid layout for Tablets/iPads
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 12,
                mainAxisExtent: 84,
              ),
              itemCount: displaySermons.length,
              itemBuilder: (context, index) {
                return _buildActivityTile(context, isDark, displaySermons[index]);
              },
            )
          else
            // Single column stack for standard phones
            ...displaySermons.map(
              (sermon) => _buildActivityTile(context, isDark, sermon),
            ),
        ],
      ),
    );
  }

  Widget _buildSermonImage(Sermon sermon, bool isDark) {
    Widget placeholder = Container(
      color: AppColors.primaryGold.withValues(alpha: 0.15),
      child: const Icon(Icons.music_note, color: AppColors.primaryGold),
    );

    if (sermon.imageUrl == null || sermon.imageUrl!.isEmpty) {
      return placeholder;
    }
    if (sermon.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: sermon.imageUrl!,
        cacheManager: CustomImageCacheManager.instance,
        fit: BoxFit.cover,
        memCacheWidth: 150,
        memCacheHeight: 150,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) =>
            Container(color: AppColors.primaryGold.withValues(alpha: 0.15)),
        errorWidget: (context, url, error) => placeholder,
      );
    }
    return Image.asset(
      sermon.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildActivityTile(BuildContext context, bool isDark, Sermon sermon) {
    final authProvider = ref.read(authChangeNotifierProvider);
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final downloadService = DownloadService();
    final user = authProvider.user;
    final isServiceTeamMember = user?.isServiceTeamMember ?? false;
    final isGeneralMarried = user?.isGeneralMarried ?? false;
    final isInHouseMarried = user?.isInHouseMarried ?? false;
    final isLocked =
        (sermon.isServiceTeamOnly && !isServiceTeamMember) ||
        (sermon.isGeneralMarriedOnly && !isGeneralMarried) ||
        (sermon.isInHouseMarriedOnly && !isInHouseMarried);
    final isCurrentlyPlaying =
        audioProvider.currentSermon?.id == sermon.id && audioProvider.isPlaying;
    final isPreBuffered = audioProvider.isPreBuffered(sermon.id);
    final isDownloaded = downloadService.isDownloaded(sermon.id);
    final isReadyToPlay = isPreBuffered || isDownloaded;

    final timeAgo = _getTimeAgo(sermon.date);

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showLockedMessage(context, isDark);
          return;
        }
        ResumePlaybackHelper.handleMessageTap(
          context: context,
          ref: ref,
          sermon: sermon,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: _buildSermonImage(sermon, isDark),
                  ),
                ),
                // Wave animation when playing
                if (isCurrentlyPlaying && !isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const _WaveAnimation(),
                    ),
                  ),
                // Ready indicator (pre-buffered or downloaded) - only show when not playing
                if (isReadyToPlay && !isLocked && !isCurrentlyPlaying)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category (bold) - Title (regular gray)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              if (sermon.categoryName.isNotEmpty) ...[
                                TextSpan(
                                  text: sermon.categoryName,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: ' - ',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              TextSpan(
                                text:
                                    '${_formatDate(sermon.date)} - ${sermon.title}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Speaker - Time ago
                  Text(
                    '${sermon.speaker ?? 'Unknown'} - $timeAgo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                          : AppColors.textSecondaryLight.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLockedMessage(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: AppColors.primaryGold),
            const SizedBox(width: 8),
            const Text('Restricted Content'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'This message is only available for Service Team members.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Wave animation widget for playing indicator
class _WaveAnimation extends StatefulWidget {
  const _WaveAnimation();

  @override
  State<_WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<_WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final delay = index * 0.15;
            final animValue = ((_controller.value + delay) % 1.0);
            final height = 8 + (animValue * 12);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
