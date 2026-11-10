import 'dart:convert';
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

    // Pause native live audio when user switches to video tab
    if (_tabController.index == 1) {
      final currentSermon = ref.read(audioPlayerChangeNotifierProvider).currentSermon;
      if (currentSermon?.id == 'livestream') {
        ref.read(audioPlayerChangeNotifierProvider).pause();
      }
    }

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
        var existing = document.getElementById(styleId);
        if (existing) existing.remove();

        var s = document.createElement('style');
        s.id = styleId;
        s.innerHTML = `
          .radio-top-bar, .radio-mode-switcher { display: none !important; }
          .radio-mobile-container {
            padding-top: 4px !important;
            padding-bottom: 24px !important;
            min-height: auto !important;
            max-width: 500px !important;
            margin: 0 auto !important;
          }
          html, body {
            background-color: #FFFFFF !important;
            background: #FFFFFF !important;
            overflow-x: hidden !important;
            color: #0F172A !important;
          }
          .radio-page-shell {
            background: linear-gradient(180deg, #FFFFFF 0%, #FAFAF8 40%, #F5F3EC 100%) !important;
            color: #0F172A !important;
            min-height: 100vh !important;
          }
          .radio-page-shell::before {
            background-image: radial-gradient(rgba(198, 179, 106, 0.18) 1.2px, transparent 1.2px) !important;
            opacity: 0.8 !important;
          }
          .radio-top-ribbon-glow {
            background: radial-gradient(ellipse at center, rgba(245, 200, 76, 0.22) 0%, rgba(201, 147, 32, 0.08) 50%, transparent 70%) !important;
          }
          .radio-artwork-container {
            margin: 6px auto 14px !important;
          }
          .radio-artwork-card {
            border: 2.5px solid #F0D788 !important;
            border-radius: 22px !important;
            box-shadow: 0 12px 32px rgba(198, 179, 106, 0.22), 0 4px 12px rgba(0, 0, 0, 0.08) !important;
            overflow: hidden !important;
          }
          .radio-program-title {
            color: #0F172A !important;
            font-weight: 800 !important;
            font-size: 16px !important;
            line-height: 1.35 !important;
            text-shadow: none !important;
            text-align: center !important;
            padding: 0 10px !important;
          }
          .radio-meta-row {
            margin: 10px auto !important;
          }
          .radio-live-badge.is-off-air {
            background: #F1F5F9 !important;
            border: 1px solid #CBD5E1 !important;
            color: #64748B !important;
          }
          .radio-live-badge:not(.is-off-air) {
            background: #FEF2F2 !important;
            border: 1px solid #FCA5A5 !important;
            color: #DC2626 !important;
          }
          .radio-meta-sep {
            color: #CBD5E1 !important;
          }
          .radio-listeners-badge {
            background: #F0FDF4 !important;
            border: 1px solid #BBF7D0 !important;
            color: #166534 !important;
            font-weight: 600 !important;
          }
          .radio-timer-row {
            margin: 4px auto 14px !important;
          }
          .radio-timer-clock {
            color: #334155 !important;
            font-weight: 700 !important;
            font-size: 15px !important;
            letter-spacing: 1px !important;
          }
          .radio-actions-row {
            gap: 12px !important;
            margin-bottom: 18px !important;
          }
          .radio-action-pill {
            background: #FFFFFF !important;
            border: 1.2px solid #E2E8F0 !important;
            color: #334155 !important;
            box-shadow: 0 3px 8px rgba(0, 0, 0, 0.05) !important;
            font-weight: 600 !important;
          }
          .radio-action-round {
            background: #FFFFFF !important;
            border: 1.2px solid #E2E8F0 !important;
            box-shadow: 0 3px 8px rgba(0, 0, 0, 0.05) !important;
          }
          .radio-action-round svg {
            stroke: #334155 !important;
          }
          .radio-visualizer {
            margin: 14px auto 20px !important;
          }
          .radio-visualizer .v-bar {
            background: linear-gradient(180deg, #D4AF37 0%, #B8861B 100%) !important;
            box-shadow: 0 0 6px rgba(212, 175, 55, 0.45) !important;
            border-radius: 3px !important;
          }
          .radio-controls-row {
            gap: 24px !important;
            margin: 10px auto 24px !important;
          }
          .radio-ctrl-btn {
            background: #F8FAFC !important;
            border: 1.2px solid #E2E8F0 !important;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.04) !important;
          }
          .radio-ctrl-btn svg {
            stroke: #1E293B !important;
          }
          .radio-main-play-btn {
            background: linear-gradient(135deg, #F5C84C 0%, #D49F24 100%) !important;
            box-shadow: 0 10px 28px rgba(212, 159, 36, 0.5), 0 3px 8px rgba(0, 0, 0, 0.1) !important;
            border: 3.5px solid #FFFFFF !important;
          }
          .radio-main-play-btn svg {
            fill: #FFFFFF !important;
          }
          .radio-drawer {
            background: #FFFFFF !important;
            color: #0F172A !important;
            border-top: 1px solid #E2E8F0 !important;
            box-shadow: 0 -8px 30px rgba(0, 0, 0, 0.08) !important;
          }
          .radio-drawer-title {
            color: #0F172A !important;
            font-weight: 700 !important;
          }
          .radio-drawer-close {
            color: #64748B !important;
          }
        `;
        document.head.appendChild(s);
      })();
    ''');
  }


  void _injectStreamBridge() {
    _webViewController?.runJavaScript('''
      (function() {
        function attachBridge() {
          var audioPlayer = document.getElementById('nativeAudioPlayer');
          var playBtn = document.getElementById('radioPlayBtn');
          if (!audioPlayer && !playBtn) {
            setTimeout(attachBridge, 300);
            return;
          }
          if (window._flutterStreamBridgeInstalled) return;
          window._flutterStreamBridgeInstalled = true;

          // Mute HTML5 audio element so sound plays exclusively via Flutter's native background AudioService
          if (audioPlayer) {
            audioPlayer.muted = true;
            audioPlayer.volume = 0;
          }

          function sendPlayMessage() {
            var titleEl = document.getElementById('radioProgramTitle');
            var artEl = document.getElementById('radioArtworkImg');
            var title = titleEl ? titleEl.textContent.trim() : 'Live Broadcast';
            var art = artEl ? artEl.src : '';
            var streamUrl = (typeof currentStreamUrl !== 'undefined' && currentStreamUrl) ? currentStreamUrl : (audioPlayer ? audioPlayer.src : '');

            if (window.FlutterLiveStream) {
              window.FlutterLiveStream.postMessage(JSON.stringify({
                action: 'play',
                streamUrl: streamUrl,
                title: title,
                artworkUrl: art
              }));
            }

            // Silence and pause HTML5 audio so it does not download duplicate data
            // or trigger browser-level pause when screen blanks / phone locks
            if (audioPlayer) {
              try {
                audioPlayer.muted = true;
                audioPlayer.pause();
              } catch(e) {}
            }
          }

          function sendPauseMessage() {
            if (window.FlutterLiveStream) {
              window.FlutterLiveStream.postMessage(JSON.stringify({
                action: 'pause'
              }));
            }
          }

          if (playBtn) {
            playBtn.addEventListener('click', function() {
              setTimeout(function() {
                var isPlayingNow = typeof isPlaying !== 'undefined' ? isPlaying : false;
                if (isPlayingNow) {
                  sendPlayMessage();
                } else {
                  sendPauseMessage();
                }
              }, 120);
            });
          }

          // If the webpage starts play directly
          if (audioPlayer) {
            audioPlayer.addEventListener('play', function() {
              sendPlayMessage();
            });
            // NOTE: We intentionally do NOT listen to audioPlayer 'pause' event here.
            // When the Android screen blanks or activity pauses, the WebView freezes
            // and automatically pauses HTML5 <audio>, which would erroneously pause
            // Flutter's background native AudioService.
          }
        }
        attachBridge();
      })();
    ''');
  }

  void _handleStreamBridgeMessage(String jsonStr) async {
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final action = data['action'] as String?;

      if (action == 'play') {
        var streamUrl = data['streamUrl'] as String?;
        if (streamUrl == null || streamUrl.trim().isEmpty) {
          streamUrl = 'https://listen.mixlr.com/d0f784be72d6e96ef254f2a5b696a9bd';
        }
        final title = data['title'] as String? ?? 'Live Broadcast';
        final artworkUrl = data['artworkUrl'] as String?;

        try {
          await ref.read(audioPlayerChangeNotifierProvider).playLiveStream(
            streamUrl,
            title: title,
            artworkUrl: artworkUrl,
          );
        } catch (e) {
          debugPrint('Live stream native play failed: $e, falling back to web audio');
          // Fallback: unmute web audio player so user still hears audio if native stream fails
          _webViewController?.runJavaScript(
            "var a = document.getElementById('nativeAudioPlayer'); if (a) { a.muted = false; a.play(); }"
          );
        }
      } else if (action == 'pause') {
        final currentSermon = ref.read(audioPlayerChangeNotifierProvider).currentSermon;
        if (currentSermon?.id == 'livestream') {
          await ref.read(audioPlayerChangeNotifierProvider).pause();
        }
      }
    } catch (e) {
      debugPrint('Error handling stream bridge message: $e');
    }
  }

  void _initializeStreamLiveWebView() {
    if (_streamLiveInitialized) return;
    _streamLiveInitialized = true;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterLiveStream',
        onMessageReceived: (JavaScriptMessage message) {
          _handleStreamBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isStreamLiveLoading = true);
            _injectAudioStyleCleaner();
            _injectStreamBridge();
          },
          onPageFinished: (url) {
            _injectAudioStyleCleaner();
            _injectStreamBridge();
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
      ..setBackgroundColor(Colors.white)
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
      final audioState = ref.read(audioPlayerChangeNotifierProvider);
      if (audioState.isPlaying && audioState.currentSermon?.id == 'livestream') {
        _webViewController?.runJavaScript(
          "if (typeof setPlaybackState === 'function' && typeof isPlaying !== 'undefined' && !isPlaying) setPlaybackState(true);"
        );
      }
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
    ref.listen(audioPlayerChangeNotifierProvider, (previous, next) {
      if (next.currentSermon?.id == 'livestream') {
        if (previous?.isPlaying != next.isPlaying) {
          if (next.isPlaying) {
            _webViewController?.runJavaScript(
              "if (typeof setPlaybackState === 'function' && typeof isPlaying !== 'undefined' && !isPlaying) setPlaybackState(true);"
            );
          } else {
            _webViewController?.runJavaScript(
              "if (typeof setPlaybackState === 'function' && typeof isPlaying !== 'undefined' && isPlaying) setPlaybackState(false);"
            );
          }
        }
      }
    });

    final targetSubIndex = ref.watch(liveStreamSubTabIndexProvider);

    if (_tabController.index != targetSubIndex) {
      _tabController.animateTo(targetSubIndex);
      if (targetSubIndex == 1 && !_watchLiveInitialized) {
        _initializeWatchLiveWebView();
      } else if (targetSubIndex == 0 && !_streamLiveInitialized) {
        _initializeStreamLiveWebView();
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : const Color(0xFF151515);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: CustomAppBar(
        title: 'Live Broadcast',
        showBackButton: true,
        lightBackground: !isDark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fgColor),
          tooltip: 'Back to Home',
          onPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
        ),
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
        actions: [
          IconButton(
            tooltip: 'Share Live Broadcast',
            icon: Icon(Icons.share_outlined, size: 21, color: fgColor),
            onPressed: _handleShare,
          ),
          IconButton(
            tooltip: 'Open in Browser',
            icon: Icon(Icons.open_in_new_rounded, size: 20, color: fgColor),
            onPressed: _handleOpenInBrowser,
          ),
          IconButton(
            tooltip: 'Refresh Stream',
            icon: Icon(Icons.refresh_rounded, size: 22, color: fgColor),
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
              child: _buildSegmentedSwitcher(isDark),
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
                    isDark: isDark,
                  ),
                  _buildStageView(
                    context: context,
                    controller: _watchLiveController,
                    isLoading: _isWatchLiveLoading,
                    isDark: isDark,
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
  Widget _buildSegmentedSwitcher(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFE5B038), Color(0xFFC69224)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC69224).withValues(alpha: 0.38),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? const Color(0xBFFFFFFF) : const Color(0xFF64748B),
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
    required bool isDark,
  }) {
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    return Container(
      width: double.infinity,
      color: bgColor,
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
              color: bgColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGold.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.35),
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
                    Text(
                      'Connecting to Live Stream...',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The City Gate Church Live Feed',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontSize: 12.5,
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
