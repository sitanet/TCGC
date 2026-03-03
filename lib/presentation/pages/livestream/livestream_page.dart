import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class LiveStreamPage extends ConsumerStatefulWidget {
  const LiveStreamPage({super.key});

  @override
  ConsumerState<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends ConsumerState<LiveStreamPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WebViewController _webViewController;
  late WebViewController _watchLiveController;
  
  static const String _liveStreamUrl = 'https://waystre.am/embed/dcitygatechurch';
  static const String _watchLiveUrl = 'https://thecitygatechurch.org/tcgc/watchlive_mobile/';
  
  bool _isWatchLiveLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeWebView();
    _initializeWatchLiveWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(_liveStreamUrl));
  }

  void _initializeWatchLiveWebView() {
    _watchLiveController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isWatchLiveLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isWatchLiveLoading = false);
          },
          onWebResourceError: (error) {
            setState(() => _isWatchLiveLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_watchLiveUrl));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: spacing * 0.625),
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
        unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: bodyFontSize),
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: spacing * 0.5),
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
            margin: EdgeInsets.fromLTRB(borderRadius, 0, borderRadius, spacing * 0.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  WebViewWidget(
                    controller: _watchLiveController,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                      ),
                      Factory<HorizontalDragGestureRecognizer>(
                        () => HorizontalDragGestureRecognizer(),
                      ),
                    },
                  ),
                  if (_isWatchLiveLoading)
                    Container(
                      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGold,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Compact refresh button
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, spacing * 0.75),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _watchLiveController.reload(),
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: spacing * 0.5),
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
            margin: EdgeInsets.fromLTRB(borderRadius, 0, borderRadius, spacing * 0.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: WebViewWidget(
                controller: _webViewController,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                  Factory<HorizontalDragGestureRecognizer>(
                    () => HorizontalDragGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
        ),
        // Compact refresh button
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, spacing * 0.75),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _webViewController.reload(),
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
