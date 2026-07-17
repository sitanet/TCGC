import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/interests_service.dart';
import '../../../data/services/download_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/event.dart';
import '../audio/audio_player_page.dart';
import '../profile/profile_page.dart';
import '../support/complaint_page.dart';
import '../notifications/notifications_page.dart';
import '../ask_wing_ai/ask_wing_ai_chat_page.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_cubit.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final DataService _dataService = DataService();
  final InterestsService _interestsService = InterestsService();
  late final PageController _eventsPageController;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  List<Sermon> _sermons = [];
  List<Event> _events = [];
  List<Sermon> _pickedInterestSermons = [];
  List<Sermon> _recommendedSermons = [];
  bool _isLoading = true;
  int _currentEventIndex = 0;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _eventsPageController = PageController(
      viewportFraction: 0.52,
      initialPage: 0,
    );
    _eventsPageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _eventsPageController.page ?? 0;
        });
      }
    });
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
      _loadData();
      _startEventAutoSlide();
    });
  }

  Future<void> _initServices() async {
    await _interestsService.initialize();
  }

  void _startEventAutoSlide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _events.isNotEmpty && _eventsPageController.hasClients) {
        final nextIndex = (_currentEventIndex + 1) % _events.length;
        _eventsPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        _startEventAutoSlide();
      }
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

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

      // Load sermons first (most important for home page)
      final allSermons = await _dataService.getMessages(
        forceRefresh: forceRefresh,
      );
      final sermons = allSermons.where(canAccessSermon).toList();

      if (mounted) {
        final pickedInterests = _interestsService
            .getRandomMessagesFromInterests(sermons, count: 3);
        setState(() {
          _sermons = sermons;
          _pickedInterestSermons = pickedInterests;
          _isLoading = false; // Show content immediately
        });
      }

      // Load events and recommended in parallel (non-blocking)
      _loadEventsAsync(forceRefresh);
      _loadRecommendedAsync(forceRefresh, canAccessSermon);
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Async loaders that don't block UI
  Future<void> _loadEventsAsync(bool forceRefresh) async {
    try {
      final events = await _dataService.getEvents(forceRefresh: forceRefresh);
      if (mounted) setState(() => _events = events);
    } catch (e) {
      debugPrint('Events load error: $e');
    }
  }

  Future<void> _loadRecommendedAsync(
    bool forceRefresh,
    bool Function(Sermon) canAccessSermon,
  ) async {
    try {
      final allRecommended = await _dataService.getRecommendedMessages(
        forceRefresh: forceRefresh,
      );
      final recommended = allRecommended.where(canAccessSermon).toList();
      if (mounted) setState(() => _recommendedSermons = recommended);
    } catch (e) {
      debugPrint('Recommended load error: $e');
    }
  }

  @override
  void dispose() {
    _eventsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White status bar icons
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: AppColors.primaryGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildUpcomingEvents(context, isDark),
                if (_pickedInterestSermons.isNotEmpty) ...[
                  SizedBox(height: spacing * 1.5),
                  _buildPickedInterests(context, isDark),
                ],
                if (_recommendedSermons.isNotEmpty) ...[
                  SizedBox(height: spacing * 1.5),
                  _buildRecommendedMessages(context, isDark),
                ],
                SizedBox(height: spacing * 1.5),
                _buildRecentActivities(context, isDark),
                SizedBox(height: spacing * 6),
              ],
            ),
          ),
        ),
        floatingActionButton: GestureDetector(
          onTap: () {
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ask Wing AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

    return ClipRRect(
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
    );
  }

  Widget _buildUpcomingEvents(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    const cardSize = 184.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            'Upcoming Events',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w600,
              fontSize: subtitleFontSize,
            ),
          ),
        ),
        SizedBox(height: spacing),
        if (_isLoading)
          SizedBox(
            height: cardSize,
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              height: cardSize,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: Responsive.iconSize(context) * 2,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    SizedBox(height: spacing * 0.75),
                    Text(
                      'No upcoming events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: bodyFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: cardSize + 40,
            child: PageView.builder(
              controller: _eventsPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentEventIndex = index;
                });
              },
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                final double distance = (_currentPage - index).abs();
                final double scale = (1 - (distance * 0.2)).clamp(0.8, 1.0);
                final double opacity = (1 - (distance * 0.3)).clamp(0.6, 1.0);

                return Center(
                  child: Transform.scale(
                    scale: scale,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: opacity,
                      child: _buildEventCard(context, isDark, event),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, bool isDark, Event event) {
    const cardSize = 184.0;
    const cornerRadius = 10.0;

    return GestureDetector(
      onTap: () => _showEventImageZoom(context, event),
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildEventImage(event.imageUrl),
              // Gradient overlay at bottom for text
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventImageZoom(BuildContext context, Event event) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _EventImageZoomDialog(event: event),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    Widget placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0D1522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 400,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF0D1522)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        errorWidget: (context, url, error) => placeholder,
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildPickedInterests(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Icon(
                Icons.star,
                color: AppColors.primaryGold,
                size: Responsive.iconSize(context) * 0.9,
              ),
              SizedBox(width: spacing * 0.5),
              Text(
                'Picked for You',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600,
                  fontSize: subtitleFontSize,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: _pickedInterestSermons
                .map((sermon) => _buildActivityTile(context, isDark, sermon))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedMessages(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Icon(
                Icons.thumb_up,
                color: AppColors.primaryGold,
                size: Responsive.iconSize(context) * 0.9,
              ),
              SizedBox(width: spacing * 0.5),
              Text(
                'Recommended',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600,
                  fontSize: subtitleFontSize,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: _recommendedSermons
                .map((sermon) => _buildActivityTile(context, isDark, sermon))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivities(BuildContext context, bool isDark) {
    final recentSermons = _sermons.take(10).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activities',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (recentSermons.isEmpty)
            Center(
              child: Text(
                'No recent activities',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ...recentSermons.map(
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
        fit: BoxFit.cover,
        memCacheWidth: 150,
        memCacheHeight: 150,
        fadeInDuration: const Duration(milliseconds: 100),
        fadeOutDuration: const Duration(milliseconds: 100),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudioPlayerPage(sermon: sermon)),
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

class _EventImageZoomDialog extends StatefulWidget {
  final Event event;

  const _EventImageZoomDialog({required this.event});

  @override
  State<_EventImageZoomDialog> createState() => _EventImageZoomDialogState();
}

class _EventImageZoomDialogState extends State<_EventImageZoomDialog> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Zoomable image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              child:
                  widget.event.imageUrl != null &&
                      widget.event.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.event.imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 300,
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.event,
                          size: 64,
                          color: Colors.white30,
                        ),
                      ),
                    )
                  : Container(
                      height: 300,
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.event,
                        size: 64,
                        color: Colors.white30,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Event details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: AppColors.primaryGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.event.schedule,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.event.location != null &&
                    widget.event.location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primaryGold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.event.location!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
