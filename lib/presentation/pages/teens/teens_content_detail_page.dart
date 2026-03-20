import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/teens_content.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import '../audio/audio_player_page.dart';

String _stripHtmlTags(String htmlText) {
  return htmlText
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class TeensContentDetailPage extends StatefulWidget {
  final TeensContent content;
  final Color accentColor;

  const TeensContentDetailPage({
    super.key,
    required this.content,
    required this.accentColor,
  });

  @override
  State<TeensContentDetailPage> createState() => _TeensContentDetailPageState();
}

class _TeensContentDetailPageState extends State<TeensContentDetailPage> {
  TeensContent get content => widget.content;
  Color get accentColor => widget.accentColor;

  void _shareContent() {
    final plainText = _stripHtmlTags(content.description);
    
    // Get first 50 words
    final words = plainText.split(RegExp(r'\s+'));
    final excerpt = words.take(50).join(' ');
    final hasMore = words.length > 50;
    
    final shareText = '''
*${content.title}*

$excerpt${hasMore ? '... Read more' : ''}

Category: ${content.category}

Download Citygate Mobile: https://play.google.com/store/apps/details?id=com.tcgc.tcgc
''';
    Share.share(shareText, subject: content.title);
  }

  void _playAudio(BuildContext context) {
    if (content.audioUrl == null || content.audioUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio available for this content'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert TeensContent to Sermon for the audio player
    final sermon = Sermon(
      id: 'teens_${content.id}',
      title: content.title,
      description: content.description,
      imageUrl: content.thumbnailUrl,
      audioUrl: content.audioUrl,
      category: content.category,
      categoryName: content.category,
      date: content.date,
      duration: content.duration ?? Duration.zero,
    );

    // Navigate to audio player page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioPlayerPage(sermon: sermon),
      ),
    );
  }

  Future<void> _downloadTranscript(BuildContext context) async {
    if (content.transcript == null || content.transcript!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              const Text('Preparing transcript...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Generate PDF
      final pdf = pw.Document();
      final plainText = _stripHtmlForPdf(content.transcript!);
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                content.title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Text('Category: ${content.category}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(width: 20),
                pw.Text('Date: ${_formatDate(content.date)}', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Text(
              plainText,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Downloaded from Citygate Mobile',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      );

      // Save PDF file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${_sanitizeFileName(content.title)}_transcript.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${content.title} - Transcript',
        text: 'Transcript from Citygate Mobile',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Transcript ready to share!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _stripHtmlForPdf(String htmlText) {
    String text = htmlText
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</?ul[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?ol[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&mdash;', '-')
        .replaceAll('&ndash;', '-')
        .replaceAll('&hellip;', '...')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase()
        .substring(0, name.length > 50 ? 50 : name.length);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: content.category,
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _shareContent,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context),
            _buildContent(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage() {
    Widget placeholder = Container(
      height: 220,
      width: double.infinity,
      color: accentColor.withOpacity(0.2),
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: accentColor,
      ),
    );

    if (content.thumbnailUrl == null || content.thumbnailUrl!.isEmpty) {
      return placeholder;
    }
    if (content.thumbnailUrl!.startsWith('http')) {
      return Image.network(
        content.thumbnailUrl!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.asset(
      content.thumbnailUrl!,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        _buildThumbnailImage(),
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  content.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stripHtmlTags(content.title),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaInfo(context, isDark),
          const SizedBox(height: 24),
          _buildDescription(context, isDark),
          const SizedBox(height: 32),
          _buildActionButtons(context, isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.cardDark : Colors.grey[100];
    
    // Check if content contains HTML tags
    final isHtml = content.description.contains('<') && content.description.contains('>');
    
    if (isHtml) {
      return Html(
        data: content.description,
        style: {
          "body": Style(
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.7),
            color: secondaryColor,
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "h1": Style(
            fontSize: FontSize(28),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 16, top: 24),
          ),
          "h2": Style(
            fontSize: FontSize(24),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 12, top: 20),
          ),
          "h3": Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 10, top: 16),
          ),
          "p": Style(
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.7),
            color: secondaryColor,
            margin: Margins.only(bottom: 12),
          ),
          "strong": Style(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          "em": Style(
            fontStyle: FontStyle.italic,
          ),
          "blockquote": Style(
            backgroundColor: bgColor,
            padding: HtmlPaddings.all(16),
            margin: Margins.symmetric(vertical: 16),
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 4,
              ),
            ),
            fontStyle: FontStyle.italic,
            color: textColor,
          ),
          "ul": Style(
            margin: Margins.only(bottom: 12, left: 8),
          ),
          "ol": Style(
            margin: Margins.only(bottom: 12, left: 8),
          ),
          "li": Style(
            margin: Margins.only(bottom: 6),
            lineHeight: const LineHeight(1.6),
          ),
          "a": Style(
            color: accentColor,
            textDecoration: TextDecoration.underline,
          ),
        },
        onLinkTap: (url, _, __) async {
          if (url != null) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      );
    } else {
      // Plain text - render normally
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            content.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: secondaryColor,
                  height: 1.6,
                ),
          ),
        ],
      );
    }
  }

  Widget _buildMetaInfo(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Speaker info (if available)
        if (content.speaker != null && content.speaker!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minister',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content.speaker!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Other meta info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetaItem(
                context,
                isDark,
                Icons.calendar_today_outlined,
                'Date',
                _formatDate(content.date),
              ),
              Container(
                height: 40,
                width: 1,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              _buildMetaItem(
                context,
                isDark,
                Icons.access_time_outlined,
                'Duration',
                content.duration != null
                    ? _formatDuration(content.duration!)
                    : 'N/A',
              ),
              Container(
                height: 40,
                width: 1,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              _buildMetaItem(
                context,
                isDark,
                Icons.category_outlined,
                'Type',
                _getContentType(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem(BuildContext context, bool isDark, IconData icon,
      String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: accentColor,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    final hasTranscript = content.transcript != null && content.transcript!.isNotEmpty;
    
    return Column(
      children: [
        // Download Transcript Button
        if (hasTranscript)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _downloadTranscript(context),
              icon: Icon(Icons.download_rounded, color: accentColor),
              label: Text(
                'Download Transcript',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (hasTranscript) const SizedBox(height: 12),
        // Listen to Audio Button
        if (content.audioUrl != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _playAudio(context),
              icon: Icon(Icons.headphones, color: accentColor),
              label: Text(
                'Listen to Audio',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (content.audioUrl != null) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareContent,
            icon: Icon(Icons.share_outlined, color: accentColor),
            label: Text(
              'Share Content',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours}h ${minutes}m';
    }
    return '${duration.inMinutes} min';
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getContentType() {
    if (content.videoUrl != null) return 'Video';
    if (content.audioUrl != null) return 'Audio';
    return 'Article';
  }
}
