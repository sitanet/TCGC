import 'package:flutter/material.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';

/// Widget to display a citation with sermon details
class CitationWidget extends StatelessWidget {
  final CitationModel citation;
  final VoidCallback? onTap;

  const CitationWidget({
    Key? key,
    required this.citation,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 3.0,
            ),
          ),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sermon title
            Text(
              citation.sermonTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4.0),
            // Speaker name
            Text(
              'by ${citation.speakerName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
              ),
            ),
            // Timestamp if available
            if (citation.timestamp != null) ...[
              const SizedBox(height: 4.0),
              Wrap(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'at ${citation.timestamp}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
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
}

/// Widget to display multiple citations
class CitationsBlock extends StatelessWidget {
  final List<CitationModel> citations;
  final VoidCallback? onCitationTap;

  const CitationsBlock({
    Key? key,
    required this.citations,
    this.onCitationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8.0),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: citations.length,
            itemBuilder: (context, index) {
              return CitationWidget(
                citation: citations[index],
                onTap: onCitationTap,
              );
            },
          ),
        ],
      ),
    );
  }
}
