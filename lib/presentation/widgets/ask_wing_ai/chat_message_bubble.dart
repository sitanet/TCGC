import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import 'citation_card.dart';

/// Message bubble for chat messages
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final String? question;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    this.question,
  }) : super(key: key);

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareMessage(BuildContext context) {
    final buffer = StringBuffer();
    
    // 1. Question
    if (question != null && question!.trim().isNotEmpty) {
      buffer.writeln('❓ Question:');
      buffer.writeln(question!.trim());
      buffer.writeln();
    }
    
    // 2. Full Wing AI Response
    buffer.writeln('🦅 Wing AI Response (The CityGate Church):');
    buffer.writeln(message.content.trim());
    buffer.writeln();
    
    // 3. Complete Citations & Message Sources (if any)
    if (message.citations != null && message.citations!.isNotEmpty) {
      buffer.writeln('📚 Sermon Sources & Citations:');
      for (final citation in message.citations!) {
        final title = citation.sermonTitle.isNotEmpty ? citation.sermonTitle : 'Sermon Teaching';
        final speaker = citation.speakerName != null && citation.speakerName!.isNotEmpty 
            ? 'by ${citation.speakerName}' 
            : '';
        final timestamp = citation.timestamp != null && citation.timestamp!.isNotEmpty 
            ? '(${citation.timestamp})' 
            : '';
        buffer.writeln('• "$title" $speaker $timestamp'.trim());
      }
      buffer.writeln();
    }
    
    // 4. Footer & Church App Tag
    buffer.writeln('— Shared from The CityGate Church App (Ask Wing AI)');
    buffer.writeln('🌐 https://thecitygatechurch.org');

    Share.share(
      buffer.toString(),
      subject: question != null && question!.isNotEmpty
          ? 'Wing AI: $question'
          : 'Insight from Wing AI (The CityGate Church)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: message.isUserMessage
            ? _buildUserMessage(context)
            : _buildAIMessage(context),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onDoubleTap: () => _copyToClipboard(context),
          onLongPress: () => _copyToClipboard(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withBlue(primaryColor.blue + 30).withGreen(primaryColor.green + 10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            _formatTimestamp(message.createdAt),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bubbleBg = isDark ? Colors.grey[900] : Colors.white;
    final borderBg = isDark ? Colors.grey[850] : Colors.grey[100];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wing AI Header Row
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE5A93C),
                      primaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.flutter_dash,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Wing AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        
        // AI Main Bubble
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI response with typewriter animated typing support
              TypewriterMarkdown(
                messageId: message.id,
                text: message.content,
                isNewMessage: DateTime.now().difference(message.createdAt).inSeconds < 15,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 15, 
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.8),
                    height: 1.45,
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  listBullet: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                  ),
                ),
              ),

              // Processing time & copy/share footer
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (message.processingTimeMs != null)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.done_all,
                              size: 13,
                              color: primaryColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${(message.processingTimeMs! / 1000).toStringAsFixed(1)}s' +
                                (message.creditsCost != null
                                    ? ' • ${message.creditsCost} ${message.creditsCost == 1 ? 'prompt' : 'prompts'}'
                                    : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy Response Button
                        InkWell(
                          onTap: () => _copyToClipboard(context),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_outlined,
                                  size: 12,
                                  color: primaryColor.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Share Response Button (includes Question + Response)
                        InkWell(
                          onTap: () => _shareMessage(context),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share_outlined,
                                  size: 12,
                                  color: primaryColor.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),


        // Timestamp
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 6),
          child: Text(
            _formatTimestamp(message.createdAt),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Custom Widget to simulate Typing (typewriter) animation for Markdown content
class TypewriterMarkdown extends StatefulWidget {
  final String? messageId;
  final String text;
  final MarkdownStyleSheet styleSheet;
  final bool isNewMessage;
  final Duration speed;

  const TypewriterMarkdown({
    Key? key,
    this.messageId,
    required this.text,
    required this.styleSheet,
    required this.isNewMessage,
    this.speed = const Duration(milliseconds: 30),
  }) : super(key: key);

  @override
  State<TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<TypewriterMarkdown> with AutomaticKeepAliveClientMixin {
  // Global set to ensure a message is ONLY animated once and NEVER re-generates on scroll
  static final Set<String> _animatedMessageIds = {};

  String _displayedText = '';
  late List<String> _words;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final msgKey = widget.messageId ?? widget.text.hashCode.toString();
    final alreadyAnimated = _animatedMessageIds.contains(msgKey);

    if (widget.isNewMessage && widget.text.isNotEmpty && !alreadyAnimated) {
      _animatedMessageIds.add(msgKey);
      // Split text into words, keeping whitespace
      _words = widget.text.split(RegExp(r'(?<=\s)|(?=\s)'));
      _startTyping();
    } else {
      _displayedText = widget.text;
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < _words.length) {
        if (mounted) {
          setState(() {
            _displayedText += _words[_currentIndex];
            _currentIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TypewriterMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      final msgKey = widget.messageId ?? widget.text.hashCode.toString();
      final alreadyAnimated = _animatedMessageIds.contains(msgKey);

      if (widget.isNewMessage && widget.text.isNotEmpty && !alreadyAnimated) {
        _animatedMessageIds.add(msgKey);
        setState(() {
          _displayedText = '';
          _currentIndex = 0;
        });
        _words = widget.text.split(RegExp(r'(?<=\s)|(?=\s)'));
        _startTyping();
      } else {
        setState(() {
          _displayedText = widget.text;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final processedText = _preProcessMarkdown(_displayedText);
    return MarkdownBody(
      data: processedText,
      styleSheet: widget.styleSheet,
    );
  }

  String _preProcessMarkdown(String text) {
    final RegExp regExp = RegExp(
      r'```mermaid\s*([\s\S]*?)```',
      multiLine: true,
    );
    
    return text.replaceAllMapped(regExp, (match) {
      try {
        final mermaidCode = match.group(1)?.trim() ?? '';
        if (mermaidCode.isEmpty) return '';
        
        // Convert to base64 representation for mermaid.ink
        final bytes = utf8.encode(mermaidCode);
        final base64Str = base64.encode(bytes);
        
        return '\n\n![Theological Concept Diagram](https://mermaid.ink/img/$base64Str)\n\n';
      } catch (_) {
        return match.group(0) ?? '';
      }
    });
  }
}
