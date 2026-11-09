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
  static List<Sermon> _staticCitygateSongs = [];

  List<Sermon> _sermons = [];
  List<BeginnerCategory> _beginnerCategories = [];
  List<Sermon> _recommendedSermons = [];
  List<Sermon> _trendingSermons = [];
  List<Sermon> _citygateSongs = [];
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
      _citygateSongs = _staticCitygateSongs;
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
      _loadCitygateSongsAsync(forceRefresh, canAccessSermon);

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
      _loadCitygateSongsAsync(true, canAccessSermon);
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

  Future<void> _loadCitygateSongsAsync(
    bool forceRefresh,
    bool Function(Sermon) canAccessSermon,
  ) async {
    try {
      final allSongs = await _dataService.getCitygateSongs(
        forceRefresh: forceRefresh,
      );
      final songs = allSongs.where(canAccessSermon).toList();
      if (mounted) {
        setState(() => _citygateSongs = songs);
      }
      _staticCitygateSongs = songs;
    } catch (e) {
      debugPrint('Citygate songs load error: $e');
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
                _buildCitygateSongs(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildYouMightAlsoLike(context, isDark),
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

    final cardWidth = Responsive.value(context, mobile: 94.0, tablet: 115.0, desktop: 125.0);
    final artworkHeight = Responsive.value(context, mobile: 64.0, tablet: 76.0, desktop: 82.0);
    final textBlockHeight = Responsive.value(context, mobile: 38.0, tablet: 42.0, desktop: 44.0);
    final rowSpacing = Responsive.value(context, mobile: 10.0, tablet: 12.0, desktop: 14.0);
    final cardItemHeight = artworkHeight + 5.0 + textBlockHeight;
    final containerHeight = (cardItemHeight * 2) + rowSpacing + 2.0;

    final categories = _beginnerCategories;
    final columnCount = (categories.length / 2).ceil();

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
                    'Are you new to this space',
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
          SizedBox(
            height: containerHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCategoryShimmerCard(context, isDark, cardWidth, artworkHeight, textBlockHeight),
                      SizedBox(height: rowSpacing),
                      _buildCategoryShimmerCard(context, isDark, cardWidth, artworkHeight, textBlockHeight),
                    ],
                  ),
                );
              },
            ),
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
          SizedBox(
            height: containerHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: columnCount,
              itemBuilder: (context, colIndex) {
                final topIndex = colIndex * 2;
                final bottomIndex = topIndex + 1;
                final topCategory = categories[topIndex];
                final bottomCategory =
                    bottomIndex < categories.length ? categories[bottomIndex] : null;

                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBeginnerCategoryCard(
                        context,
                        isDark,
                        topCategory,
                        cardWidth,
                        artworkHeight,
                        textBlockHeight,
                      ),
                      SizedBox(height: rowSpacing),
                      if (bottomCategory != null)
                        _buildBeginnerCategoryCard(
                          context,
                          isDark,
                          bottomCategory,
                          cardWidth,
                          artworkHeight,
                          textBlockHeight,
                        )
                      else
                        SizedBox(width: cardWidth, height: cardItemHeight),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBeginnerCategoryCard(
    BuildContext context,
    bool isDark,
    BeginnerCategory category,
    double cardWidth,
    double artworkHeight,
    double textBlockHeight,
  ) {
    final titleFontSize = Responsive.value(context, mobile: 11.0, tablet: 12.5);
    final countFontSize = Responsive.value(context, mobile: 9.5, tablet: 10.5);

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
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Clean Artwork (No text or dark overlay on top)
            Container(
              width: cardWidth,
              height: artworkHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: isDark ? 0.25 : 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: _buildCategoryCardImage(
                  category.imageUrl ??
                      (category.sermons.isNotEmpty
                          ? category.sermons.first.imageUrl
                          : null),
                  isDark,
                ),
              ),
            ),
            const SizedBox(height: 5),

            // 2. Title & Message Count Underneath the Card
            SizedBox(
              height: textBlockHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      height: 1.15,
                    ),
                  ),
                  if (category.sermonCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${category.sermonCount} msg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: countFontSize,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShimmerCard(
    BuildContext context,
    bool isDark,
    double cardWidth,
    double artworkHeight,
    double textBlockHeight,
  ) {
    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cardWidth,
            height: artworkHeight,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: cardWidth * 0.8,
            height: 10,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: cardWidth * 0.45,
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
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

    // Pick strictly at most 4 most listened / trending messages (deduplicated)
    List<Sermon> displayList = _trendingSermons;
    if (displayList.isEmpty) {
      displayList = _recommendedSermons;
    }
    if (displayList.isEmpty) {
      displayList = _sermons;
    }

    final seenIds = <String>{};
    final List<Sermon> uniquePicks = [];
    for (final s in displayList) {
      if (seenIds.add(s.id)) {
        uniquePicks.add(s);
      }
      if (uniquePicks.length == 4) break;
    }
    final trendingPicks = uniquePicks;
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
                    'Most Listened Messages',
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
                      'Top Audio',
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

    final imageWidth = Responsive.value(context, mobile: 90.0, tablet: 110.0, desktop: 120.0);
    final imageHeight = Responsive.value(context, mobile: 72.0, tablet: 82.0, desktop: 88.0);
    final titleFontSize = Responsive.value(context, mobile: 13.0, tablet: 14.5);
    final speakerFontSize = Responsive.value(context, mobile: 11.5, tablet: 12.5);
    final playBtnSize = Responsive.value(context, mobile: 40.0, tablet: 44.0);

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
                        maxLines: 2,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: speakerFontSize,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFB0AFC7) : const Color(0xFF535176),
                          height: 1.2,
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

  Widget _buildCitygateSongs(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    List<Sermon> songList = _citygateSongs;
    if (songList.isEmpty) {
      final songKeywords = ['song', 'worship', 'praise', 'choir', 'hymn', 'music', 'sound'];
      songList = _sermons.where((s) {
        final title = s.title.toLowerCase();
        final cat = s.category.toLowerCase();
        final catName = s.categoryName.toLowerCase();
        final desc = s.description.toLowerCase();
        return songKeywords.any((kw) =>
            title.contains(kw) ||
            cat.contains(kw) ||
            catName.contains(kw) ||
            desc.contains(kw));
      }).toList();
    }
    if (songList.isEmpty) {
      songList = _sermons;
    }

    final songsPicks = songList.take(12).toList();
    if (songsPicks.isEmpty) return const SizedBox.shrink();

    final cardWidth = Responsive.value(context, mobile: 140.0, tablet: 180.0, desktop: 200.0);
    final containerHeight = cardWidth + 72.0;

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
                    Icons.music_note_rounded,
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Citygate Songs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                      Icons.library_music_rounded,
                      size: 13,
                      color: AppColors.primaryGold,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Worship & Praise',
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
        SizedBox(height: spacing * 0.8),
        SizedBox(
          height: containerHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: songsPicks.length,
            itemBuilder: (context, index) {
              final sermon = songsPicks[index];
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
              categoryCode.isNotEmpty
                  ? '${_formatDateClean(sermon.date)} • $categoryCode'
                  : _formatDateClean(sermon.date),
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
