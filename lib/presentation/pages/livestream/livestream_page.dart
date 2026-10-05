import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
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
      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStreamLive(context, isDark),
                _buildWatchLive(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.largeBorderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: spacing * 0.625,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Colors.transparent,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primaryGold,
        unselectedLabelColor: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: bodyFontSize,
        ),
        tabs: const [
          Tab(text: 'Stream Live'),
          Tab(text: 'Watch Live'),
        ],
      ),
    );
  }

  Widget _buildWatchLive(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Column(
      children: [
        // Compact header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: spacing * 0.5,
          ),
          child: Row(
            children: [
              Icon(
                Icons.live_tv_rounded,
                color: AppColors.primaryGold,
                size: iconSize * 0.83,
              ),
              SizedBox(width: spacing * 0.5),
              Text(
                'Watch Live Service',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: bodyFontSize,
                ),
              ),
              const Spacer(),
              _buildLiveIndicator(),
            ],
          ),
        ),
        // WebView takes most of the space
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  if (_watchLiveController != null)
                    WebViewWidget(
                      controller: _watchLiveController!,
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<VerticalDragGestureRecognizer>(
                              () => VerticalDragGestureRecognizer(),
                            ),
                            Factory<HorizontalDragGestureRecognizer>(
                              () => HorizontalDragGestureRecognizer(),
                            ),
                          },
                    ),
                  if (_isWatchLiveLoading || _watchLiveController == null)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGold,
                        strokeWidth: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Compact refresh button
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            spacing * 0.5,
            horizontalPadding,
            spacing * 0.75,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _watchLiveController?.reload(),
              icon: Icon(Icons.refresh_rounded, size: iconSize * 0.75),
              label: Text('Refresh', style: TextStyle(fontSize: bodyFontSize)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGold,
                side: const BorderSide(color: AppColors.primaryGold, width: 1),
                padding: EdgeInsets.symmetric(vertical: spacing * 0.625),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius * 0.83),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamLive(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Column(
      children: [
        // Compact header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: spacing * 0.5,
          ),
          child: Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                color: AppColors.primaryGold,
                size: iconSize * 0.83,
              ),
              SizedBox(width: spacing * 0.5),
              Text(
                'Stream Live Service',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: bodyFontSize,
                ),
              ),
              const Spacer(),
              _buildLiveIndicator(),
            ],
          ),
        ),
        // WebView takes most of the space
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  if (_webViewController != null)
                    WebViewWidget(
                      controller: _webViewController!,
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<VerticalDragGestureRecognizer>(
                              () => VerticalDragGestureRecognizer(),
                            ),
                            Factory<HorizontalDragGestureRecognizer>(
                              () => HorizontalDragGestureRecognizer(),
                            ),
                          },
                    ),
                  if (_isStreamLiveLoading || _webViewController == null)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGold,
                        strokeWidth: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Compact refresh button
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            spacing * 0.5,
            horizontalPadding,
            spacing * 0.75,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _webViewController?.reload(),
              icon: Icon(Icons.refresh_rounded, size: iconSize * 0.75),
              label: Text('Refresh', style: TextStyle(fontSize: bodyFontSize)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGold,
                side: const BorderSide(color: AppColors.primaryGold, width: 1),
                padding: EdgeInsets.symmetric(vertical: spacing * 0.625),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius * 0.83),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
