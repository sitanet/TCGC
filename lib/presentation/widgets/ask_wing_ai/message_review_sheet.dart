import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/transcript.dart';
import 'sermon_prep_sheet.dart' show SermonPrepResult;

enum MessageReviewStyle {
  easyBreakdown('Easy Breakdown', Icons.lightbulb_outline_rounded, 'simple'),
  keyTakeaways('Key Takeaways', Icons.checklist_rounded, 'short'),
  deepStudy('Deep Study', Icons.menu_book_rounded, 'advanced');

  final String label;
  final IconData icon;
  final String responseStyle;
  const MessageReviewStyle(this.label, this.icon, this.responseStyle);
}

/// Interactive bottom sheet on the Wing AI dashboard allowing users to pick
/// a church message transcript and have Wing AI break down what the minister
/// taught in an easy-to-understand manner.
class MessageReviewSheet extends StatefulWidget {
  final bool isServiceTeamMember;
  final bool isGeneralMarried;
  final bool isInHouseMarried;

  const MessageReviewSheet({
    super.key,
    this.isServiceTeamMember = false,
    this.isGeneralMarried = false,
    this.isInHouseMarried = false,
  });

  static Future<SermonPrepResult?> show(
    BuildContext context, {
    bool isServiceTeamMember = false,
    bool isGeneralMarried = false,
    bool isInHouseMarried = false,
  }) {
    return showModalBottomSheet<SermonPrepResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MessageReviewSheet(
        isServiceTeamMember: isServiceTeamMember,
        isGeneralMarried: isGeneralMarried,
        isInHouseMarried: isInHouseMarried,
      ),
    );
  }

  @override
  State<MessageReviewSheet> createState() => _MessageReviewSheetState();
}

class _MessageReviewSheetState extends State<MessageReviewSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final DataService _dataService = DataService();

  List<Transcript> _transcripts = [];
  Transcript? _selectedTranscript;
  MessageReviewStyle _selectedStyle = MessageReviewStyle.easyBreakdown;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTranscripts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  Future<void> _loadTranscripts() async {
    try {
      final all = await _dataService.getTranscripts();
      final filtered = all.where((t) {
        if (t.isServiceTeamOnly && !widget.isServiceTeamMember) return false;
        if (t.isGeneralMarriedOnly && !widget.isGeneralMarried) return false;
        if (t.isInHouseMarriedOnly && !widget.isInHouseMarried) return false;
        return true;
      }).toList();
      if (mounted) {
        setState(() {
          _transcripts = filtered;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Transcript> get _filteredTranscripts {
    if (_searchQuery.trim().isEmpty) return _transcripts;
    final q = _searchQuery.toLowerCase().trim();
    return _transcripts.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.speaker?.toLowerCase().contains(q) ?? false) ||
          t.categoryName.toLowerCase().contains(q);
    }).toList();
  }

  String _cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _submit() {
    final transcript = _selectedTranscript;
    if (transcript == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a message transcript to review'),
        ),
      );
      return;
    }

    final focus = _focusController.text.trim();
    final speakerLabel =
        (transcript.speaker != null && transcript.speaker!.isNotEmpty)
            ? ' by ${transcript.speaker}'
            : '';

    final buffer = StringBuffer();
    buffer.writeln(
      'Please review the message "${transcript.title}"$speakerLabel and break down what the minister is saying in a clear, easy-to-understand manner.',
    );
    if (focus.isNotEmpty) {
      buffer.writeln('\nSpecial focus / question from me: $focus');
    }
    buffer.writeln();
    buffer.writeln('Please organize the review clearly with:');
    buffer.writeln('- What the message is mainly about (in plain, simple words)');
    buffer.writeln('- Step-by-step breakdown of the minister\'s key points');
    buffer.writeln('- Relatable everyday examples to make each point easy to grasp');
    buffer.writeln('- Key Bible verses shared and what they mean');
    buffer.writeln('- Practical steps I can apply to my life today');

    final body = _cleanText(transcript.content);
    if (body.isNotEmpty) {
      final excerpt = body.length > 2600 ? '${body.substring(0, 2600)}...' : body;
      buffer.writeln('\nMessage Transcript Content:\n$excerpt');
    }

    Navigator.pop(
      context,
      SermonPrepResult(
        prompt: buffer.toString().trim(),
        responseStyle: _selectedStyle.responseStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF171A21) : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF212630) : const Color(0xFFF6F5F0);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message Review',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Break down a transcript for easy understanding',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: subColor),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Text(
                      'Select a Message Transcript',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: textColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search messages by title or minister...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: subColor),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredTranscripts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No message transcripts found.',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._filteredTranscripts.take(30).map((t) {
                        final isSelected = _selectedTranscript?.id == t.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () =>
                                setState(() => _selectedTranscript = t),
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.description_outlined,
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : subColor,
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (t.speaker != null && t.speaker!.isNotEmpty)
                                  t.speaker!,
                                if (t.categoryName.isNotEmpty) t.categoryName,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: subColor),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Text(
                      'How should Wing AI break it down?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MessageReviewStyle.values.map((style) {
                        final selected = _selectedStyle == style;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedStyle = style),
                          avatar: Icon(
                            style.icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF3B82F6),
                          ),
                          label: Text(style.label),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : textColor,
                          ),
                          selectedColor: const Color(0xFF3B82F6),
                          backgroundColor: surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Specific Question or Part to Explain (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _focusController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: textColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'e.g., Explain what the minister meant about...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Submit button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.auto_stories_rounded, size: 19),
                      label: const Text(
                        'Review Message with Wing AI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
