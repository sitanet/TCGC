import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/event.dart';
import 'failure_page.dart';

class TransactionProcessingPage extends StatefulWidget {
  final String title;
  final String amount;
  final Future<bool> Function() processTransaction;
  final Widget successPage;
  final String? errorMessage;
  final String? Function()? getErrorMessage;

  const TransactionProcessingPage({
    super.key,
    required this.title,
    required this.amount,
    required this.processTransaction,
    required this.successPage,
    this.errorMessage,
    this.getErrorMessage,
  });

  @override
  State<TransactionProcessingPage> createState() =>
      _TransactionProcessingPageState();
}

class _TransactionProcessingPageState extends State<TransactionProcessingPage>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late AnimationController _ringController;
  late AnimationController _slideController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatAnimation;
  late Animation<Offset> _slideAnimation;

  // ── State ──────────────────────────────────────────────────────────────────
  String _statusText = 'Processing your payment...';
  bool _isProcessing = true;
  int _currentStep = 0;
  final List<String> _steps = [
    'Initiating transaction...',
    'Processing your payment...',
    'Verifying transaction...',
    'Almost done...',
  ];

  // ── Events ─────────────────────────────────────────────────────────────────
  List<Event> _events = [];
  final PageController _eventPageController = PageController(
    viewportFraction: 0.80,
  );
  int _currentEventIndex = 0;
  double _currentEventPage = 0;
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startStepAnimation();
    _processPayment();
    _loadEvents();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _eventPageController.addListener(() {
      if (mounted) {
        setState(() => _currentEventPage = _eventPageController.page ?? 0);
      }
    });
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _dataService.getEvents();
      if (mounted && events.isNotEmpty) {
        setState(() => _events = events);
        // Slide in the events section after a short delay
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _slideController.forward();
        });
        _startEventAutoSlide();
      }
    } catch (e) {
      debugPrint('TransactionProcessingPage: events load error: $e');
    }
  }

  void _startEventAutoSlide() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || !_isProcessing || _events.isEmpty) return false;
      if (!_eventPageController.hasClients) return true;
      final next = (_currentEventIndex + 1) % _events.length;
      _eventPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      if (mounted) setState(() => _currentEventIndex = next);
      return _isProcessing;
    });
  }

  void _startStepAnimation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_isProcessing) return false;
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
        _statusText = _steps[_currentStep];
      });
      return _isProcessing;
    });
  }

  Future<void> _processPayment() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _statusText = 'Verifying transaction...');

      final success = await widget.processTransaction();
      if (!mounted) return;

      if (success) {
        setState(() {
          _statusText = 'Payment successful!';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.successPage),
        );
      } else {
        setState(() {
          _statusText = 'Transaction failed';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final errorMsg = widget.getErrorMessage?.call() ?? widget.errorMessage;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FailurePage(
              title: widget.title,
              amount: widget.amount,
              errorMessage: errorMsg,
              onRetry: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Transaction failed';
        _isProcessing = false;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final errorMsg = widget.getErrorMessage?.call() ?? e.toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FailurePage(
            title: widget.title,
            amount: widget.amount,
            errorMessage: errorMsg,
            onRetry: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    _ringController.dispose();
    _slideController.dispose();
    _eventPageController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxWidth = Responsive.maxContentWidth(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final iconSize = Responsive.value(
      context,
      mobile: 120.0,
      tablet: 140.0,
      desktop: 160.0,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFFAFAFA),
        body: SafeArea(
          child: Stack(
            children: [
              // ── Floating background particles ──────────────────────────────
              if (_isProcessing) ..._buildParticles(size),

              // ── Main content ───────────────────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      // Top section — processing animation
                      Expanded(
                        flex: 5,
                        child: _buildProcessingSection(
                          isDark,
                          iconSize,
                          titleFontSize,
                          bodyFontSize,
                        ),
                      ),

                      // Bottom section — events slider (slides up when loaded)
                      if (_events.isNotEmpty)
                        SlideTransition(
                          position: _slideAnimation,
                          child: _buildEventsSection(isDark),
                        ),

                      const SizedBox(height: 16),
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

  // ── Processing section ─────────────────────────────────────────────────────
  Widget _buildProcessingSection(
    bool isDark,
    double iconSize,
    double titleFontSize,
    double bodyFontSize,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated icon
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _isProcessing ? _floatAnimation.value : 0),
            child: child,
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isProcessing ? _pulseAnimation.value : 1.0,
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ..._buildRings(iconSize),
                // Glow
                Container(
                  width: iconSize * 1.4,
                  height: iconSize * 1.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryGold.withValues(alpha: 0.35),
                        AppColors.primaryGold.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Main circle
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD700),
                        AppColors.primaryGold,
                        Color(0xFFB8860B),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.25),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: _isProcessing
                      ? RotationTransition(
                          turns: _rotationController,
                          child: const Icon(
                            Icons.sync_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          builder: (_, v, __) => Transform.scale(
                            scale: v,
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Status text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            _statusText,
            key: ValueKey(_statusText),
            style: TextStyle(
              fontSize: titleFontSize * 0.85,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 12),

        // Amount with shimmer
        AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (_, __) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: const [
                Color(0xFFFFD700),
                AppColors.primaryGold,
                Color(0xFFFFD700),
              ],
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            child: Text(
              '₦${widget.amount}',
              style: TextStyle(
                fontSize: titleFontSize * 1.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Giving type
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: bodyFontSize,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Progress bar
        if (_isProcessing) _buildProgressBar(isDark),
      ],
    );
  }

  // ── Events section ────────────────────────────────────────────────────────
  Widget _buildEventsSection(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Card takes ~75% of screen width, capped at 280 so it never overflows
    final cardWidth = (screenWidth * 0.75).clamp(160.0, 280.0);
    final cardHeight = cardWidth * 0.75; // 4:3 aspect ratio

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin top border line
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          color: AppColors.primaryGold.withValues(alpha: 0.18),
        ),
        const SizedBox(height: 14),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Upcoming Events',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Dot indicators
              Row(
                children: List.generate(
                  _events.length.clamp(0, 6),
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: i == _currentEventIndex % _events.length ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentEventIndex % _events.length
                          ? AppColors.primaryGold
                          : AppColors.primaryGold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Cards PageView — sized to card dimensions
        SizedBox(
          height: cardHeight + 16,
          child: PageView.builder(
            controller: _eventPageController,
            onPageChanged: (index) =>
                setState(() => _currentEventIndex = index),
            itemCount: _events.length * 100,
            itemBuilder: (context, index) {
              final event = _events[index % _events.length];
              final double distance = (_currentEventPage - index).abs();
              final double scale = (1 - (distance * 0.15)).clamp(0.85, 1.0);
              final double opacity = (1 - (distance * 0.3)).clamp(0.6, 1.0);

              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: opacity,
                    child: _buildEventCard(
                      event,
                      isDark,
                      cardWidth,
                      cardHeight,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom tagline
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  'Securing your transaction...',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(
    Event event,
    bool isDark,
    double cardWidth,
    double cardHeight,
  ) {
    return GestureDetector(
      onTap: () => _showEventImageZoom(event),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildEventImage(event.imageUrl),
              // Gradient overlay at bottom for title
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
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

  void _showEventImageZoom(Event event) {
    final screenSize = MediaQuery.of(context).size;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: screenSize.width - 32,
          height: (screenSize.width - 32) * 0.75,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildEventImage(event.imageUrl),
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0D1522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 600,
        memCacheHeight: 340,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF0D1522)],
            ),
          ),
        ),
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<Widget> _buildRings(double size) {
    return List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _ringController,
        builder: (_, __) {
          final progress = (_ringController.value + i * 0.33) % 1.0;
          final scale = 1.0 + progress * 0.5;
          final opacity = (1.0 - progress).clamp(0.0, 0.4);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size * 1.2,
              height: size * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: opacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildParticles(Size screenSize) {
    return List.generate(12, (i) {
      final rng = math.Random(i);
      final x = rng.nextDouble() * screenSize.width;
      final y = rng.nextDouble() * screenSize.height;
      final sz = 4.0 + rng.nextDouble() * 8;
      return AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final dy = math.sin(_floatController.value * math.pi * 2 + i) * 20;
          final dx = math.cos(_floatController.value * math.pi * 2 + i) * 10;
          return Positioned(
            left: x + dx,
            top: y + dy,
            child: Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                shape: i % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: i % 2 == 0 ? null : BorderRadius.circular(2),
                color: AppColors.primaryGold.withValues(
                  alpha: 0.15 + rng.nextDouble() * 0.2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildProgressBar(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (_, __) => ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.3),
                    AppColors.primaryGold,
                    AppColors.primaryGold.withValues(alpha: 0.3),
                  ],
                  stops: [
                    (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                    _shimmerAnimation.value.clamp(0.0, 1.0),
                    (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
