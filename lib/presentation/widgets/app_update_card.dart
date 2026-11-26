import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/data_service.dart' show AppUpdateInfo;

/// Upgraded, brand-aligned app update card screen shown when a newer
/// application version is available or required.
class AppUpdateScreen extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final Future<void> Function() onUpdateNow;
  final VoidCallback onClose;

  const AppUpdateScreen({
    super.key,
    required this.updateInfo,
    required this.onUpdateNow,
    required this.onClose,
  });

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen>
    with SingleTickerProviderStateMixin {
  bool _isLaunching = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateTap() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      await widget.onUpdateNow();
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  String get _storeButtonLabel {
    if (kIsWeb) return 'Update Now';
    if (Platform.isAndroid) return 'Update on Google Play';
    if (Platform.isIOS) return 'Update on App Store';
    return 'Update Now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = widget.updateInfo;
    final isForced = info.forceUpdate;

    final cardGradient = isDark
        ? const [Color(0xFF231D12), Color(0xFF15120D)]
        : const [Color(0xFFFFFDF8), Color(0xFFF6EDD9)];
    final subtleSurface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.75);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bodyColor =
        isDark ? const Color(0xFFC8C5BC) : const Color(0xFF5A5A55);
    final accentColor = isForced ? AppColors.sardine : AppColors.primaryGold;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.62),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: cardGradient,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.45 : 0.4),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: status pill + optional close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isForced
                                      ? Icons.verified_user_rounded
                                      : Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isForced ? 'REQUIRED UPDATE' : 'NEW UPDATE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isForced)
                            IconButton(
                              onPressed: widget.onClose,
                              tooltip: 'Close',
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                padding: const EdgeInsets.all(8),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // CityGate emblem with subtle pulse ring
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.35),
                                  width: 1.6,
                                ),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/tcgc_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.rocket_launch_rounded,
                                    size: 40,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isForced
                                        ? const [
                                            AppColors.jasper,
                                            AppColors.sardine,
                                          ]
                                        : const [
                                            Color(0xFFF3C65F),
                                            AppColors.primaryGold,
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1C170F)
                                        : const Color(0xFFFFFDF8),
                                    width: 2.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 16,
                                  color: isForced ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title & subtitle
                      Text(
                        isForced ? 'Update Required' : 'New Version Available',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: -0.4,
                              color: titleColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isForced
                            ? 'Please upgrade to the latest version to keep enjoying CityGate Mobile.'
                            : 'A fresher, faster CityGate Mobile experience is ready for you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: bodyColor,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Version comparison pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: subtleSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (info.currentVersion.isNotEmpty) ...[
                              Text(
                                'v${info.currentVersion}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: bodyColor,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 15,
                                  color: accentColor,
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'v${info.latestVersion}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isForced) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sardine.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.sardine.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.sardine,
                                size: 17,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This update is required to continue using the app.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFFFB4A2)
                                        : AppColors.jasper,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Primary Update CTA
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                                    colors: isForced
                                        ? const [
                                            AppColors.jasper,
                                            AppColors.sardine,
                                          ]
                                        : const [
                                            Color(0xFFF3C65F),
                                            AppColors.primaryGold,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed:
                                      _isLaunching ? null : _handleUpdateTap,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLaunching
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              isForced
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.download_rounded,
                                              color: isForced
                                                  ? Colors.white
                                                  : Colors.black,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _storeButtonLabel,
                                              style: TextStyle(
                                                color: isForced
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              if (!isForced) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: TextButton(
                                    onPressed: widget.onClose,
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      'Remind Me Later',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: bodyColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
  }
}
