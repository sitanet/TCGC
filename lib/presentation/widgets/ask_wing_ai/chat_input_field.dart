import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/services/connectivity_service.dart';

import 'ai_consent_dialog.dart';



/// Elegant chat input field with network awareness, voice input (speech-to-text), and animated send button
class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmit;
  final bool enabled;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> with SingleTickerProviderStateMixin {
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  StreamSubscription<bool>? _connectivitySubscription;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _initConnectivity();
    _initSpeech();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (errorNotification) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
          debugPrint('Speech recognition error: ${errorNotification.errorMsg}');
        },
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('Speech recognition init error: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!_isConnected) {
      _showNoNetworkToast(context);
      return;
    }

    if (!widget.enabled) {
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    if (!_speechAvailable) {
      final reinit = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (errorNotification) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
        },
      );
      if (!reinit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice recognition is not available or microphone permission was denied.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      _speechAvailable = true;
    }

    setState(() {
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            setState(() {
              widget.controller.text = words;
              widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: words.length),
              );
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error starting speech listen: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _initConnectivity() {
    _connectivityService.initialize();
    _isConnected = _connectivityService.isConnected;

    // Check live connectivity
    _connectivityService.checkConnectivity().then((connected) {
      if (mounted && _isConnected != connected) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    _connectivitySubscription = _connectivityService.connectionStream.listen((connected) {
      if (mounted && _isConnected != connected) {
        setState(() {
          _isConnected = connected;
        });
        if (!connected) {
          _showNoNetworkToast(context);
        }
      }
    });
  }



  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _showNoNetworkToast(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No internet connection. Please check your network and try again.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _getHintText() {
    if (_isListening) {
      return 'Listening to your voice...';
    }

    if (!widget.enabled) {
      return 'Daily limit reached (15/15) • Please wait until tomorrow';
    }
    return 'Search messages or ask Wing AI...';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isListening) {
      _speech.stop();
    }
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isActive = _hasText && widget.enabled && _isConnected;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            // ── Text field ──
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isListening
                        ? const Color(0xFFE5A93C)
                        : (!_isConnected
                            ? Colors.red.withValues(alpha: 0.5)
                            : (_isFocused
                                ? primaryColor.withValues(alpha: 0.6)
                                : (isDark ? Colors.grey[700]! : Colors.grey[300]!))),
                    width: (_isFocused || _isListening) ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: _getHintText(),
                          hintStyle: TextStyle(
                            color: _isListening
                                ? const Color(0xFFE5A93C)
                                : (!_isConnected
                                    ? Colors.red[300]
                                    : (isDark ? Colors.grey[500] : Colors.grey[400])),
                            fontSize: 14,
                            fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(
                            left: 18,
                            right: 8,
                            top: 14,
                            bottom: 14,
                          ),
                        ),
                        onSubmitted: widget.enabled ? (text) => _handleSubmit() : null,
                      ),
                    ),
                    // Voice Mic Button inside the text field
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ScaleTransition(
                        scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Material(
                          color: _isListening
                              ? const Color(0xFFE5A93C).withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _toggleListening,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isListening
                                    ? const Color(0xFFE5A93C)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Send button ──
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 48 : 44,
                height: isActive ? 48 : 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: isActive
                      ? LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!_isConnected) {
                        _showNoNetworkToast(context);
                      } else if (isActive) {
                        _handleSubmit();
                      }
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: Icon(
                        !_isConnected ? Icons.wifi_off_rounded : Icons.send_rounded,
                        color: isActive
                            ? Colors.white
                            : (isDark ? Colors.grey[500] : Colors.grey[500]),
                        size: isActive ? 22 : 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 1),
          child: GestureDetector(
            onTap: () {
              AIConsentDialog.showConsentDialog(context, isInformationalOnly: true);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'AI Data Privacy & Protection • Tap for Notice',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  void _handleSubmit() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && widget.enabled) {
      widget.onSubmit(text);
    }
  }
}
