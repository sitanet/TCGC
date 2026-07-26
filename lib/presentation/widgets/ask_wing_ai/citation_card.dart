import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../pages/audio/transcript_list_page.dart';

/// Card displaying sermon citation
class CitationCard extends StatelessWidget {
  final CitationModel citation;

  const CitationCard({
    Key? key,
    required this.citation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () async {
        // If PDF URL is uploaded, launch it natively on the device (maintains custom design)
        if (citation.pdfUrl != null && citation.pdfUrl!.isNotEmpty) {
          final uri = Uri.parse(citation.pdfUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            // Fallback to internal webview if launching fails
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TranscriptViewPage(
                  overrideUrl: citation.pdfUrl,
                  overrideTitle: citation.sermonTitle,
                ),
              ),
            );
          }
        } else {
          // Fallback to HTML transcript page
          final url = 'https://tcgc.thecitygatechurch.org/transcript/${citation.sermonId}/';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TranscriptViewPage(
                overrideUrl: url,
                overrideTitle: citation.sermonTitle,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : primaryColor.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sermon title
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 15,
                color: primaryColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  citation.sermonTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),

          // Speaker and timestamp
          Row(
            children: [
              if (citation.speakerName != null) ...[
                Icon(
                  Icons.person_pin_outlined,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  citation.speakerName ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.schedule_outlined,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                citation.estimatedTimestamp ?? citation.timestamp ?? '--:--',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              // Copy button
              InkWell(
                onTap: () => _copyToClipboard(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.content_copy_outlined,
                    size: 14,
                    color: primaryColor.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),

          // Excerpt (if available and not too long)
          if ((citation.textChunk?.isNotEmpty ?? false) && (citation.textChunk?.length ?? 0) < 150) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '"${citation.textChunk ?? ''}"',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[800],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Similarity score (for debugging/transparency)
          if (citation.similarityScore > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 12,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${(citation.similarityScore * 100).toInt()}% match',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

  void _copyToClipboard(BuildContext context) {
    final text = citation.formattedCitation;
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Citation copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}