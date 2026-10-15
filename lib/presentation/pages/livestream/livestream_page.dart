import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class LiveStreamPage extends ConsumerStatefulWidget {
  const LiveStreamPage({super.key});

  @override
  ConsumerState<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends ConsumerState<LiveStreamPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  WebViewController? _webViewController;
  WebViewController? _watchLiveController;

  static const String _liveStreamUrl =
      'https://dcitygatechurch.mixlr.com/embed';
  static const String _watchLiveUrl =
      'https://thecitygatechurch.org/tcgc/watchlive_mobile/';

  bool _isStreamLiveLoading = true;
  bool _isWatchLiveLoading = true;
  bool _streamLiveInitialized = false;
  bool _watchLiveInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    // Pulse animation for the glowing live badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final initialSubIndex = ref.read(liveStreamSubTabIndexProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialSubIndex,
    );
    _tabController.addListener(_onTabChanged);

    // Lazy load: initialize corresponding tab's WebView after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialSubIndex == 1) {
        _initializeWatchLiveWebView();
      } else {
        _initializeStreamLiveWebView();
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    HapticFeedback.selectionClick();
    ref.read(liveStreamSubTabIndexProvider.notifier).state = _tabController.index;

    // Lazy load WebView when tab is selected
    if (_tabController.index == 0 && !_streamLiveInitialized) {
      _initializeStreamLiveWebView();
    } else if (_tabController.index == 1 && !_watchLiveInitialized) {
      _initializeWatchLiveWebView();
    }
  }

  void _initializeStreamLiveWebView() {
    if (_streamLiveInitialized) return;
    _streamLiveInitialized = true;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isStreamLiveLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isStreamLiveLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isStreamLiveLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_liveStreamUrl));
    if (mounted) setState(() {});
  }

  void _initializeWatchLiveWebView() {
    if (_watchLiveInitialized) return;
    _watchLiveInitialized = true;
    _watchLiveController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isWatchLiveLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isWatchLiveLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isWatchLiveLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_watchLiveUrl));
    if (mounted) setState(() {});
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    if (_tabController.index == 0) {
      setState(() => _isStreamLiveLoading = true);
      await _webViewController?.reload();
    } else {
      setState(() => _isWatchLiveLoading = true);
      await _watchLiveController?.reload();
    }
  }

  Future<void> _handleShare() async {
    HapticFeedback.lightImpact();
    final isVideo = _tabController.index == 1;
    final streamType = isVideo ? 'Video' : 'Audio';
    final shareUrl = isVideo ? _watchLiveUrl : 'https://dcitygatechurch.mixlr.com';

    await Share.share(
      'Join us live for an impactful service with The City Gate Church ($streamType broadcast)!\n\n'
      'Watch/Listen here: $shareUrl\n\n'
      'Experience worship, God\'s Word, and divine transformation.',
      subject: 'TCGC Live Broadcast',
    );
  }

  Future<void> _handleOpenInBrowser() async {
    HapticFeedback.lightImpact();
    final isVideo = _tabController.index == 1;
    final targetUrl = isVideo ? _watchLiveUrl : 'https://dcitygatechurch.mixlr.com';
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pulseController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();

    // Clear WebView resources to free memory
    _webViewController?.clearCache();
    _watchLiveController?.clearCache();
    _webViewController = null;
    _watchLiveController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetSubIndex = ref.watch(liveStreamSubTabIndexProvider);

    if (_tabController.index != targetSubIndex) {
      _tabController.animateTo(targetSubIndex);
      if (targetSubIndex == 1 && !_watchLiveInitialized) {
        _initializeWatchLiveWebView();
      } else if (targetSubIndex == 0 && !_streamLiveInitialized) {
        _initializeStreamLiveWebView();
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF7F8FA),
      appBar: CustomAppBar(
        title: 'Live Broadcast',
        showBackButton: true,
        lightBackground: !isDark,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
        actions: [
          IconButton(
            tooltip: 'Share Live Broadcast',
            icon: const Icon(Icons.share_outlined, size: 21),
            onPressed: _handleShare,
          ),
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: _handleOpenInBrowser,
          ),
          IconButton(
            tooltip: 'Refresh Stream',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _handleRefresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Live status banner & Segmented Mode Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                children: [
                  _buildLiveStatusRow(isDark),
                  const SizedBox(height: 12),
                  _buildSegmentedSwitcher(isDark),
                ],
              ),
            ),

            // 2. Main Broadcast Stage (TabBarView)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStageView(
                    context: context,
                    isDark: isDark,
                    controller: _webViewController,
                    isLoading: _isStreamLiveLoading,
                    streamTitle: 'Audio Live Stream',
                    streamSubtitle: 'Mixlr High-Quality Audio Broadcast (Low Data)',
                    icon: Icons.headphones_rounded,
                  ),
                  _buildStageView(
                    context: context,
                    isDark: isDark,
                    controller: _watchLiveController,
                    isLoading: _isWatchLiveLoading,
                    streamTitle: 'Watch Video Live',
                    streamSubtitle: 'Sanctuary High-Definition Video Broadcast',
                    icon: Icons.live_tv_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glowing live broadcast indicator + viewer guidance
  Widget _buildLiveStatusRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated Pulsing Red Live Badge
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: _pulseAnimation.value),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: _pulseAnimation.value * 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE ON AIR',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The City Gate Church',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Sunday & Midweek Services',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Sound wave / broadcast icon
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_rounded,
              size: 16,
              color: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Segmented Pill Switcher (Audio vs Video)
  Widget _buildSegmentedSwitcher(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[200],
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey[300]!,
          width: 0.8,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.primaryGold,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGold.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            iconMargin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.headphones_rounded, size: 16),
                SizedBox(width: 8),
                Text('Audio Stream'),
              ],
            ),
          ),
          Tab(
            iconMargin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv_rounded, size: 16),
                SizedBox(width: 8),
                Text('Watch Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Unified Stage View for both Audio and Video
  Widget _buildStageView({
    required BuildContext context,
    required bool isDark,
    required WebViewController? controller,
    required bool isLoading,
    required String streamTitle,
    required String streamSubtitle,
    required IconData icon,
  }) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final borderRadius = Responsive.borderRadius(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Broadcast Header Pill
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streamTitle,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        streamSubtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fast Refresh Icon
                InkWell(
                  onTap: _handleRefresh,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 13, color: AppColors.primaryGold),
                        SizedBox(width: 4),
                        Text(
                          'Reload',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. High-Tech Theater Player Stage
          Container(
            height: Responsive.value(context, mobile: 270.0, tablet: 420.0, desktop: 500.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(borderRadius * 1.2),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: isDark ? 0.35 : 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius * 1.2),
              child: Stack(
                children: [
                  // Active WebView
                  if (controller != null)
                    WebViewWidget(
                      controller: controller,
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                        Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
                      },
                    ),

                  // Modern Shimmer / Loading State
                  if (isLoading || controller == null)
                    Container(
                      color: const Color(0xFF0F1115),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryGold.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGold,
                                  strokeWidth: 2.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Connecting to Live Stream...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The City Gate Church Live Feed',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Quick Engagement Action Bar (Share, Open in Browser)
          _buildQuickActionsBar(context, isDark),

          const SizedBox(height: 16),

          // 4. Church Service Timetable & Information Card
          _buildServiceInfoCard(isDark),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Interactive Quick Actions during live service
  Widget _buildQuickActionsBar(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Share & Invite Button (Primary Gold Accent)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleShare,
            icon: const Icon(Icons.share_rounded, size: 17),
            label: const Text(
              'Invite & Share Broadcast',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // External Browser Button
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: IconButton(
            tooltip: 'Open in Fullscreen Browser',
            icon: const Icon(Icons.open_in_browser_rounded, size: 20, color: AppColors.primaryGold),
            onPressed: _handleOpenInBrowser,
          ),
        ),
      ],
    );
  }

  /// Weekly Timetable & Broadcast Info Card
  Widget _buildServiceInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primaryGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Broadcast Schedule',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildScheduleItem(
            icon: Icons.wb_sunny_rounded,
            title: 'Sunday Celebration Service',
            time: 'Sundays • 8:00 AM & 10:00 AM (WAT)',
            isDark: isDark,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 0.6),
          ),
          _buildScheduleItem(
            icon: Icons.local_fire_department_rounded,
            title: 'Midweek Communion Service',
            time: 'Wednesdays • 6:00 PM (WAT)',
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Data-saving advice banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 16,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Low on data or on the go? Switch to Audio Stream for crystal-clear playback with minimal data consumption.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[300] : const Color(0xFF555555),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem({
    required IconData icon,
    required String title,
    required String time,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
