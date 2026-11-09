import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
      'https://thecitygatechurch.org/listen-live/?app=1';
  static const String _liveStreamWebUrl =
      'https://thecitygatechurch.org/listen-live/';
  static const String _watchLiveUrl =
      'https://thecitygatechurch.org/watch-live/?app=1';
  static const String _watchLiveWebUrl =
      'https://thecitygatechurch.org/watch-live/';

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
    HapticFeedback.selectionClick();
    ref.read(liveStreamSubTabIndexProvider.notifier).state = _tabController.index;

    // Lazy load WebView when tab is selected
    if (_tabController.index == 0 && !_streamLiveInitialized) {
      _initializeStreamLiveWebView();
    } else if (_tabController.index == 1 && !_watchLiveInitialized) {
      _initializeWatchLiveWebView();
    }
  }

  void _injectAudioStyleCleaner() {
    _webViewController?.runJavaScript('''
      (function() {
        var styleId = 'tcgc-flutter-clean-style';
        if (!document.getElementById(styleId)) {
          var s = document.createElement('style');
          s.id = styleId;
          s.innerHTML = `
            .radio-top-bar, .radio-mode-switcher { display: none !important; }
            .radio-mobile-container { padding-top: 2px !important; min-height: auto !important; }
            html, body { overflow-x: hidden !important; }
          `;
          document.head.appendChild(s);
        }
      })();
    ''');
  }

  void _initializeStreamLiveWebView() {
    if (_streamLiveInitialized) return;
    _streamLiveInitialized = true;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF071534))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isStreamLiveLoading = true);
            _injectAudioStyleCleaner();
          },
          onPageFinished: (url) {
            _injectAudioStyleCleaner();
            if (mounted) setState(() => _isStreamLiveLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isStreamLiveLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            // If user taps "Watch Video" inside web page, smoothly switch to Video tab
            if (request.url.contains('/watch-live')) {
              _tabController.animateTo(1);
              ref.read(liveStreamSubTabIndexProvider.notifier).state = 1;
              if (!_watchLiveInitialized) _initializeWatchLiveWebView();
              return NavigationDecision.prevent;
            }

            // If user taps back to home or church root, switch to Home tab
            if (request.url.endsWith('thecitygatechurch.org/?app=1') ||
                request.url.endsWith('thecitygatechurch.org/')) {
              ref.read(mainTabIndexProvider.notifier).state = 0;
              return NavigationDecision.prevent;
            }

            // External links (Mixlr channel, social media) open in external browser
            if (!request.url.contains('thecitygatechurch.org')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
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
          onNavigationRequest: (NavigationRequest request) {
            // If user taps "Listen Live" inside web page, switch to Audio tab
            if (request.url.contains('/listen-live')) {
              _tabController.animateTo(0);
              ref.read(liveStreamSubTabIndexProvider.notifier).state = 0;
              if (!_streamLiveInitialized) _initializeStreamLiveWebView();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
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
    final shareUrl = isVideo ? _watchLiveWebUrl : _liveStreamWebUrl;

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
    final targetUrl = isVideo ? _watchLiveWebUrl : _liveStreamWebUrl;
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
      backgroundColor: const Color(0xFF071534),
      appBar: CustomAppBar(
        title: 'Live Broadcast',
        showBackButton: true,
        lightBackground: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Home',
          onPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
        ),
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
        actions: [
          IconButton(
            tooltip: 'Share Live Broadcast',
            icon: const Icon(Icons.share_outlined, size: 21, color: Colors.white),
            onPressed: _handleShare,
          ),
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Colors.white),
            onPressed: _handleOpenInBrowser,
          ),
          IconButton(
            tooltip: 'Refresh Stream',
            icon: const Icon(Icons.refresh_rounded, size: 22, color: Colors.white),
            onPressed: _handleRefresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Segmented Mode Switcher (Audio vs Video)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: _buildSegmentedSwitcher(),
            ),

            // Main Broadcast Stage (TabBarView) - Expands fully down without padding/border clipping
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStageView(
                    context: context,
                    controller: _webViewController,
                    isLoading: _isStreamLiveLoading,
                  ),
                  _buildStageView(
                    context: context,
                    controller: _watchLiveController,
                    isLoading: _isWatchLiveLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Segmented Pill Switcher (Audio vs Video) matching TCGC luxury styling
  Widget _buildSegmentedSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xD10C1A3C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF5C84C).withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFF5C84C), Color(0xFFD49F24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF5C84C).withValues(alpha: 0.42),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xBFFFFFFF),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
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
                Icon(Icons.headphones_rounded, size: 17),
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
                Icon(Icons.live_tv_rounded, size: 17),
                SizedBox(width: 8),
                Text('Watch Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Unified Stage View for both Audio and Video - Expanded to full height
  Widget _buildStageView({
    required BuildContext context,
    required WebViewController? controller,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF071534),
      child: Stack(
        children: [
          // Active WebView with EagerGestureRecognizer for instant platform responsiveness
          if (controller != null)
            WebViewWidget(
              controller: controller,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),

          // Modern Shimmer / Loading State
          if (isLoading || controller == null)
            Container(
              color: const Color(0xFF071534),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF5C84C).withValues(alpha: 0.12),
                        border: Border.all(
                          color: const Color(0xFFF5C84C).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF5C84C),
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
    );
  }
}
