import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import 'citation_card.dart';

/// Message bubble for chat messages
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

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
        Container(
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
                color: primaryColor.withOpacity(0.2),
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
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: primaryColor,
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
                color: Colors.black.withOpacity(0.03),
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
                text: message.content,
                isNewMessage: DateTime.now().difference(message.createdAt).inSeconds < 15,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 15, 
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8),
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

              // Processing time footer
              if (message.processingTimeMs != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 14,
                        color: primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Responded in ${(message.processingTimeMs! / 1000).toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Citations (Sources list)
        if (message.citations != null && message.citations!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 13,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SOURCES:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.7,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ...message.citations!.map((citation) => CitationCard(
                  citation: citation,
                )),
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
  final String text;
  final MarkdownStyleSheet styleSheet;
  final bool isNewMessage;
  final Duration speed;

  const TypewriterMarkdown({
    Key? key,
    required this.text,
    required this.styleSheet,
    required this.isNewMessage,
    this.speed = const Duration(milliseconds: 30),
  }) : super(key: key);

  @override
  State<TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<TypewriterMarkdown> {
  String _displayedText = '';
  late List<String> _words;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isNewMessage && widget.text.isNotEmpty) {
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
      if (widget.isNewMessage && widget.text.isNotEmpty) {
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
    return MarkdownBody(
      data: _displayedText,
      styleSheet: widget.styleSheet,
    );
  }
}
