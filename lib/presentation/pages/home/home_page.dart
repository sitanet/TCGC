import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/event.dart';
import '../audio/audio_player_page.dart';
import '../profile/edit_profile_page.dart';
import '../support/complaint_page.dart';
import '../notifications/notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScrollController _eventsScrollController;
  double _scrollOffset = 0;
  final DataService _dataService = DataService();
  
  List<Sermon> _sermons = [];
  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _eventsScrollController = ScrollController();
    _eventsScrollController.addListener(_onScroll);
    _loadData();
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
      }
    } catch (e) {
      print('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _eventsScrollController.removeListener(_onScroll);
    _eventsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _eventsScrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBanner(context, isDark),
            const SizedBox(height: 24),
            _buildUpcomingEvents(context, isDark),
            const SizedBox(height: 24),
            _buildRecentActivities(context, isDark),
            const SizedBox(height: 100),
          ],
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
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2D0A0A),
            Color(0xFF1A0505),
            Color(0xFF0D0202),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/tcgc_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.church, color: Colors.white, size: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The CityGate Church',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Where sons are raised',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Consumer<AuthProvider>(
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
                            ),
                      ),
                      Row(
                        children: [
                          Consumer<NotificationProvider>(
                            builder: (context, notificationProvider, _) {
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
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Text(
                                            unreadCount > 99 ? '99+' : '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfilePage(),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryGold,
                              child: const Icon(Icons.person, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents(BuildContext context, bool isDark) {
    final double baseItemWidth = 120.0;
    final double activeItemWidth = 160.0;
    final double baseItemHeight = 120.0;
    final double activeItemHeight = 160.0;
    final double spacing = 12.0;

    final defaultColors = [
      const Color(0xFF1A2744),
      const Color(0xFFF5E6C8),
      const Color(0xFF1A1A2E),
      const Color(0xFF2D0A0A),
      const Color(0xFF0A2D1A),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Upcoming Events',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'No upcoming events',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ),
          )
        else
          SizedBox(
            height: activeItemHeight + 20,
            child: ListView.builder(
              controller: _eventsScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                final isFirst = index == 0;
                final isLast = index == _events.length - 1;
                
                final itemStart = (index * (baseItemWidth + spacing)) + 20;
                final itemCenter = itemStart + (baseItemWidth / 2);
                final viewportCenter = _scrollOffset + (MediaQuery.of(context).size.width / 2);
                final distance = (itemCenter - viewportCenter).abs();
                
                final threshold = baseItemWidth * 0.6;
                final isCenter = distance < threshold;
                
                final currentWidth = isCenter ? activeItemWidth : baseItemWidth;
                final currentHeight = isCenter ? activeItemHeight : baseItemHeight;
                final scale = isCenter ? 1.0 : 0.75;
                
                return _buildEventCard(
                  context,
                  isDark,
                  event.title,
                  event.imageUrl,
                  defaultColors[index % defaultColors.length],
                  width: currentWidth,
                  height: currentHeight,
                  scale: scale,
                  isFirst: isFirst,
                  isLast: isLast,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    bool isDark,
    String title,
    String? imagePath,
    Color color, {
    double width = 120.0,
    double height = 140.0,
    double scale = 1.0,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final double leftMargin = isFirst ? 0 : 6;
    final double rightMargin = isLast ? 0 : 6;

    Widget buildImage() {
      Widget placeholder = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.event,
            size: 30,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      );

      if (imagePath == null || imagePath.isEmpty) {
        return placeholder;
      }

      if (imagePath.startsWith('http')) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      }

      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      margin: EdgeInsets.only(
        left: leftMargin,
        right: rightMargin,
        top: (180.0 - height) / 2,
        bottom: (180.0 - height) / 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1 + (0.15 * scale)),
            blurRadius: 8 + (8 * scale),
            offset: Offset(0, 4 + (4 * scale)),
            spreadRadius: scale > 0.9 ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 10,
              right: 10,
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: scale > 0.9 ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context, bool isDark) {
    final recentSermons = _sermons.take(2).toList();

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
                    sermon.description,
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
