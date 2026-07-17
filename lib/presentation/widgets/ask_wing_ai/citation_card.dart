import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';

/// Card displaying sermon citation
class CitationCard extends StatelessWidget {
  final CitationModel citation;

  const CitationCard({
    Key? key,
    required this.citation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sermon title
          Row(
            children: [
              Icon(
                Icons.book,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  citation.sermonTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
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
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  citation.speakerName ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                citation.estimatedTimestamp ?? citation.timestamp ?? '--:--',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
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
                    Icons.copy,
                    size: 14,
                    color: Colors.grey[600],
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