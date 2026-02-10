import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/event.dart';
import '../audio/audio_player_page.dart';
import '../profile/profile_page.dart';
import '../support/complaint_page.dart';

String _stripHtmlTags(String htmlText) {
  return htmlText
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DataService _dataService = DataService();
  final PageController _eventsPageController = PageController();
  
  List<Sermon> _sermons = [];
  List<Event> _events = [];
  bool _isLoading = true;
  int _currentEventIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startEventAutoSlide();
  }

  void _startEventAutoSlide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _events.isNotEmpty) {
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sermons = await _dataService.getMessages();
      final events = await _dataService.getEvents();
      if (mounted) {
        setState(() {
          _sermons = sermons;
          _events = events;
          _isLoading = false;
        });
        
        // Pre-cache images in background
        _preCacheImages(sermons, events);
      }
    } catch (e) {
      print('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _preCacheImages(List<Sermon> sermons, List<Event> events) {
    for (final sermon in sermons) {
      if (sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty) {
        CachedNetworkImageProvider(sermon.imageUrl!).resolve(ImageConfiguration.empty);
      }
    }
    for (final event in events) {
      if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
        CachedNetworkImageProvider(event.imageUrl!).resolve(ImageConfiguration.empty);
      }
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(context, isDark),
              SizedBox(height: spacing * 1.5),
              _buildUpcomingEvents(context, isDark),
              SizedBox(height: spacing * 1.5),
              _buildRecentActivities(context, isDark),
              SizedBox(height: spacing * 6),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ComplaintPage(),
            ),
          );
        },
        backgroundColor: AppColors.primaryGold,
        child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: Responsive.iconSize(context)),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    final borderRadius = Responsive.largeBorderRadius(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    // Logo size based on device
    final logoSize = isMobile ? 80.0 : isTablet ? 100.0 : 120.0;
    
    // Font sizes based on device
    final welcomeFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final titleFontSize = isMobile ? 18.0 : isTablet ? 22.0 : 26.0;
    final subtitleFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final nameFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    
    // Avatar size based on device
    final avatarRadius = isMobile ? 24.0 : isTablet ? 30.0 : 36.0;
    
    // Padding based on device
    final horizontalPadding = isMobile ? 20.0 : isTablet ? 30.0 : 40.0;
    final bottomPadding = isMobile ? 20.0 : isTablet ? 25.0 : 30.0;

    return Container(
      width: screenWidth,  // Always full width
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D0A0A),
            Color(0xFF1A0505),
            Color(0xFF0D0202),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Centered logo and text
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 30.0 : 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/tcgc_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.church, color: Colors.white, size: logoSize * 0.5),
                      ),
                    ),
                    SizedBox(width: isMobile ? 16 : 24),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                  fontSize: welcomeFontSize,
                                ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'The CityGate Church',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: titleFontSize,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Where sons are raised',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                                fontSize: subtitleFontSize,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bottom row with name and profile picture
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final user = authProvider.user;
                    final displayName = user != null
                        ? '${user.firstName} ${user.lastName}'.trim()
                        : 'Guest';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : 'Welcome',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: nameFontSize,
                              ),
                        ),
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
                            backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                                ? NetworkImage(user.photoUrl!)
                                : null,
                            child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                                ? Icon(Icons.person, color: Colors.white, size: avatarRadius * 1.2)
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
      ),
    );
  }

  Widget _buildUpcomingEvents(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final eventCardHeight = Responsive.eventCardHeight(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

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
            height: eventCardHeight,
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              height: eventCardHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(Responsive.borderRadius(context)),
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
          Column(
            children: [
              SizedBox(
                height: eventCardHeight,
                child: PageView.builder(
                  controller: _eventsPageController,
                  itemCount: _events.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentEventIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return _buildEventCard(context, isDark, event);
                  },
                ),
              ),
              if (_events.length > 1) ...[
                SizedBox(height: spacing * 0.75),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _events.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: spacing * 0.25),
                      width: _currentEventIndex == index ? spacing * 1.5 : spacing * 0.5,
                      height: spacing * 0.5,
                      decoration: BoxDecoration(
                        color: _currentEventIndex == index
                            ? AppColors.primaryGold
                            : (isDark ? Colors.grey[700] : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(spacing * 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, bool isDark, Event event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildEventImage(event.imageUrl),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
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
                            event.schedule,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
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
            ...recentSermons.map((sermon) => _buildActivityTile(
                  context,
                  isDark,
                  sermon,
                )),
        ],
      ),
    );
  }

  Widget _buildSermonImage(Sermon sermon, bool isDark) {
    Widget placeholder = Container(
      color: AppColors.primaryGold.withValues(alpha: 0.15),
      child: const Icon(
        Icons.music_note,
        color: AppColors.primaryGold,
      ),
    );
    
    if (sermon.imageUrl == null || sermon.imageUrl!.isEmpty) {
      return placeholder;
    }
    if (sermon.imageUrl!.startsWith('http')) {
      return Image.network(
        sermon.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.asset(
      sermon.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    bool isDark,
    Sermon sermon,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerPage(sermon: sermon),
          ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: _buildSermonImage(sermon, isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      children: [
                        TextSpan(text: sermon.title),
                        TextSpan(
                          text: ' - ${sermon.category}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stripHtmlTags(sermon.description),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
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
}
