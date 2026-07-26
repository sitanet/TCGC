import 'package:flutter/material.dart';
import '../../../data/models/ask_wing_ai/ask_wing_ai_response_model.dart';

/// Rate limit indicator shown in AppBar
class RateLimitIndicator extends StatelessWidget {
  final RateLimitModel status;

  const RateLimitIndicator({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        label: Text(status.dailyRemaining.toString()),
        backgroundColor: _getBadgeColor(),
        child: const Icon(Icons.bolt_outlined),
      ),
      onPressed: () => _showRateLimitDialog(context),
      tooltip: 'Credits remaining',
    );
  }

  Color _getBadgeColor() {
    if (status.isAtLimit) return Colors.red;
    if (status.isNearLimit) return Colors.orange;
    return Colors.amber[700]!;
  }

  void _showRateLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily AI Credits Quota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.flash_on_outlined,
              label: 'Credits Used',
              value: '${status.dailyUsed} / ${status.dailyLimit}',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.bolt,
              label: 'Remaining Credits',
              value: status.dailyRemaining.toString(),
              color: _getBadgeColor(),
            ),
            if (status.resetTime != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'Resets',
                value: _formatResetTime(status.resetTime!),
                color: Colors.grey,
              ),
            ],
            const SizedBox(height: 16),
            // Progress bar
            LinearProgressIndicator(
              value: status.usagePercentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_getBadgeColor()),
            ),
            const SizedBox(height: 8),
            Text(
              '${(status.usagePercentage * 100).toInt()}% used',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Text(
                'Note: Standard questions cost 1 credit. Complex questions requiring detailed responses or large documents may cost 2 or 3 credits.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatResetTime(DateTime resetTime) {
    final now = DateTime.now();
    final difference = resetTime.difference(now);

    if (difference.inHours > 0) {
      return 'in ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'Soon';
    }
  }
}
