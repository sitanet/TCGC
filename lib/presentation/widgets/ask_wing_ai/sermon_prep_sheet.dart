import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/transcript.dart';

enum SermonPrepFormat {
  sermonOutline('Sermon Outline', Icons.format_list_numbered_rounded),
  bibleStudy('Bible Study', Icons.menu_book_rounded),
  devotional('Short Word / Devotional', Icons.wb_sunny_rounded),
  teachingNotes('Teaching Notes', Icons.school_rounded);

  final String label;
  final IconData icon;
  const SermonPrepFormat(this.label, this.icon);
}

class SermonPrepResult {
  final String prompt;
  final String responseStyle;

  const SermonPrepResult({
    required this.prompt,
    required this.responseStyle,
  });
}

/// Interactive bottom sheet on the Wing AI dashboard allowing users to
/// prepare a message or sermon grounded in church transcript resources.
class SermonPrepSheet extends StatefulWidget {
  final bool isServiceTeamMember;
  final bool isGeneralMarried;
  final bool isInHouseMarried;

  const SermonPrepSheet({
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
      builder: (ctx) => SermonPrepSheet(
        isServiceTeamMember: isServiceTeamMember,
        isGeneralMarried: isGeneralMarried,
        isInHouseMarried: isInHouseMarried,
      ),
    );
  }

  @override
  State<SermonPrepSheet> createState() => _SermonPrepSheetState();
}

class _SermonPrepSheetState extends State<SermonPrepSheet> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final DataService _dataService = DataService();

  SermonPrepFormat _selectedFormat = SermonPrepFormat.sermonOutline;
  List<Transcript> _transcripts = [];
  final Set<String> _selectedIds = <String>{};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTranscripts();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _searchController.dispose();
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
    final topic = _topicController.text.trim();
    final selected =
        _transcripts.where((t) => _selectedIds.contains(t.id)).toList();

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the topic or what you want to prepare about'),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Please prepare a complete ${_selectedFormat.label} for me'
      '${topic.isNotEmpty ? ' on the topic: "$topic"' : ''}.',
    );
    buffer.writeln();
    buffer.writeln('Include:');
    switch (_selectedFormat) {
      case SermonPrepFormat.sermonOutline:
        buffer.writeln(
          '- Catchy sermon title & core theme\n'
          '- Opening hook / introduction\n'
          '- Anchor Scriptures with clear explanations\n'
          '- 3 to 4 structured main points with sub-points & practical illustrations\n'
          '- Closing charge & prayer',
        );
        break;
      case SermonPrepFormat.bibleStudy:
        buffer.writeln(
          '- Study objective & key Bible passages\n'
          '- Verse-by-verse / doctrinal breakdown\n'
          '- Practical life application\n'
          '- 4 discussion questions for small groups & closing prayer',
        );
        break;
      case SermonPrepFormat.devotional:
        buffer.writeln(
          '- Inspiring title\n'
          '- Key Scripture & warm reflection\n'
          '- Actionable takeaway for today\n'
          '- Short heartfelt prayer',
        );
        break;
      case SermonPrepFormat.teachingNotes:
        buffer.writeln(
          '- Doctrinal foundation & key definitions\n'
          '- Supporting Scriptures & CityGate teachings\n'
          '- Structured teaching points with real-life examples\n'
          '- Summary & ministry application',
        );
        break;
    }

    if (selected.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Draw directly from these CityGate transcript resources:');
      for (final t in selected.take(3)) {
        final speaker =
            (t.speaker != null && t.speaker!.isNotEmpty) ? ' by ${t.speaker}' : '';
        buffer.writeln('- "${t.title}"$speaker');
        final excerpt = _cleanText(t.content);
        if (excerpt.isNotEmpty) {
          final capped =
              excerpt.length > 900 ? '${excerpt.substring(0, 900)}...' : excerpt;
          buffer.writeln('  Excerpt: $capped');
        }
      }
    } else {
      buffer.writeln(
        '\nDraw from the relevant CityGate Church sermon transcripts and teachings.',
      );
    }

    Navigator.pop(
      context,
      SermonPrepResult(
        prompt: buffer.toString().trim(),
        responseStyle:
            _selectedFormat == SermonPrepFormat.devotional ? 'simple' : 'advanced',
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
                          colors: [AppColors.primaryGold, Color(0xFFB8860B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prepare Message / Sermon',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Build from CityGate transcript resources',
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
                      'What do you want to prepare about?',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _topicController,
                      autofocus: true,
                      maxLines: 2,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter your topic, scripture, or message focus...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13.5),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Format',
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
                      children: SermonPrepFormat.values.map((fmt) {
                        final selected = _selectedFormat == fmt;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedFormat = fmt),
                          avatar: Icon(
                            fmt.icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppColors.primaryGold,
                          ),
                          label: Text(fmt.label),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : textColor,
                          ),
                          selectedColor: AppColors.primaryGold,
                          backgroundColor: surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primaryGold
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transcript Resources',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          _selectedIds.isEmpty
                              ? 'Auto-match all'
                              : '${_selectedIds.length}/3 selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select up to 3 transcripts to draw from, or leave unselected to search all transcripts.',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: textColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search transcripts by title or minister...',
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
                            'No matching transcripts found.',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._filteredTranscripts.take(30).map((t) {
                        final isSelected = _selectedIds.contains(t.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold.withValues(alpha: 0.12)
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(t.id);
                                } else if (_selectedIds.length < 3) {
                                  _selectedIds.add(t.id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You can select up to 3 transcripts at a time',
                                      ),
                                    ),
                                  );
                                }
                              });
                            },
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.description_outlined,
                              color: isSelected
                                  ? AppColors.primaryGold
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
                      icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                      label: const Text(
                        'Prepare with Wing AI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
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
