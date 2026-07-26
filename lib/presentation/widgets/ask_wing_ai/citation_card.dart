import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
        // If PDF URL is uploaded, download and save it to the phone
        if (citation.pdfUrl != null && citation.pdfUrl!.isNotEmpty) {
          try {
            // Show start toast
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Downloading message PDF...'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Fetch the bytes
            final response = await http.get(Uri.parse(citation.pdfUrl!));
            if (response.statusCode == 200) {
              // Find the standard phone downloads directory
              Directory? downloadDir;
              if (Platform.isAndroid) {
                downloadDir = Directory('/storage/emulated/0/Download');
                if (!await downloadDir.exists()) {
                  downloadDir = await getExternalStorageDirectory();
                }
              } else {
                downloadDir = await getApplicationDocumentsDirectory();
              }

              if (downloadDir != null) {
                // Sanitize file name
                final safeTitle = citation.sermonTitle.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
                final filePath = '${downloadDir.path}/$safeTitle.pdf';
                final file = File(filePath);
                
                // Write bytes to storage
                await file.writeAsBytes(response.bodyBytes);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved to Downloads: $safeTitle.pdf'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );

                // Open the downloaded local file natively
                final fileUri = Uri.file(filePath);
                if (await canLaunchUrl(fileUri)) {
                  await launchUrl(fileUri, mode: LaunchMode.externalApplication);
                } else {
                  // Fallback to opening the web URL with highlight parameter if file:// launch is restricted
                  final cleanPhrase = _cleanSearchPhrase(citation.textChunk);
                  final searchParam = cleanPhrase.isNotEmpty ? '#search="${Uri.encodeComponent(cleanPhrase)}"' : '';
                  await launchUrl(
                    Uri.parse('${citation.pdfUrl}$searchParam'),
                    mode: LaunchMode.externalApplication,
                  );
                }
                return;
              }
            }
            throw Exception('Failed to fetch file');
          } catch (e) {
            // Fallback to direct web browser download with highlight parameter if local write fails
            final cleanPhrase = _cleanSearchPhrase(citation.textChunk);
            final searchParam = cleanPhrase.isNotEmpty ? '#search="${Uri.encodeComponent(cleanPhrase)}"' : '';
            await launchUrl(
              Uri.parse('${citation.pdfUrl}$searchParam'),
              mode: LaunchMode.externalApplication,
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

  String _cleanSearchPhrase(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    // Clean newlines, carriage returns and double quotes
    final clean = text.replaceAll(RegExp(r'[\r\n"]+'), ' ').trim();
    // Use first 8 words to make a clean, unique phrase search key
    final words = clean.split(RegExp(r'\s+'));
    if (words.length > 8) {
      return words.sublist(0, 8).join(' ');
    }
    return clean;
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