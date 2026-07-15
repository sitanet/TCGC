import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../pages/wallet/wallet_page.dart';

/// Banner widget to display when a feature is under maintenance
/// Shows the maintenance message and estimated downtime if available
class MaintenanceBanner extends StatelessWidget {
  final String message;
  final int? estimatedDowntimeMinutes;
  final VoidCallback? onRetry;
  final bool isDark;

  const MaintenanceBanner({
    super.key,
    required this.message,
    this.estimatedDowntimeMinutes,
    this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.construction_outlined,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Maintenance Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          if (estimatedDowntimeMinutes != null) ...[
            const SizedBox(height: 12),
            Text(
              'Estimated downtime: ${estimatedDowntimeMinutes}m',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Check Again',
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen maintenance screen shown when feature is disabled
class MaintenanceScreen extends StatefulWidget {
  final String featureName;
  final String message;
  final int? estimatedDowntimeMinutes;
  final VoidCallback? onBackPressed;

  const MaintenanceScreen({
    super.key,
    required this.featureName,
    required this.message,
    this.estimatedDowntimeMinutes,
    this.onBackPressed,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = MediaQuery.of(context).size.width * 0.08;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.featureName.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Construction icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_outlined,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Under Maintenance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                widget.message,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              // Estimated downtime
              if (widget.estimatedDowntimeMinutes != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated downtime: ${widget.estimatedDowntimeMinutes}m',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Check Again button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isRetrying
                      ? null
                      : () async {
                          setState(() => _isRetrying = true);
                          // Wait a moment before popping
                          await Future.delayed(const Duration(seconds: 1));
                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    disabledBackgroundColor:
                        AppColors.primaryGold.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isRetrying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Check Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
