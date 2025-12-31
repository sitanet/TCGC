import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';

class AudioPlayerPage extends StatefulWidget {
  final Sermon sermon;

  const AudioPlayerPage({super.key, required this.sermon});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool isPlaying = false;
  double currentPosition = 0.3;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(title: widget.sermon.category),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            _buildAlbumArt(isDark),
            const SizedBox(height: 32),
            _buildSongInfo(context),
            const SizedBox(height: 32),
            _buildProgressBar(isDark),
            const SizedBox(height: 24),
            _buildControls(isDark),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(bool isDark) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildAlbumImage(isDark),
      ),
    );
  }

  Widget _buildAlbumImage(bool isDark) {
    if (widget.sermon.imageUrl == null || widget.sermon.imageUrl!.isEmpty) {
      return _buildPlaceholderArt(isDark);
    }
    if (widget.sermon.imageUrl!.startsWith('http')) {
      return Image.network(
        widget.sermon.imageUrl!,
        fit: BoxFit.cover,
        width: 280,
        height: 280,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(isDark),
      );
    }
    return Image.asset(
      widget.sermon.imageUrl!,
      fit: BoxFit.cover,
      width: 280,
      height: 280,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(isDark),
    );
  }

  Widget _buildPlaceholderArt(bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGold.withOpacity(0.3),
                isDark ? AppColors.cardDark : AppColors.surfaceLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.music_note,
            size: 80,
            color: AppColors.primaryGold.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSongInfo(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.sermon.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.sermon.category,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primaryGold,
            inactiveTrackColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            thumbColor: AppColors.primaryGold,
            overlayColor: AppColors.primaryGold.withOpacity(0.2),
          ),
          child: Slider(
            value: currentPosition,
            onChanged: (value) {
              setState(() {
                currentPosition = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(
                  minutes: (widget.sermon.duration.inMinutes * currentPosition).toInt(),
                )),
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(widget.sermon.duration),
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.skip_previous,
            size: 36,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () {
            setState(() {
              isPlaying = !isPlaying;
            });
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.skip_next,
            size: 36,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
