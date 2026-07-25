import 'package:equatable/equatable.dart';

/// Represents a message in the Ask Wing AI chat interface
class ChatMessageModel extends Equatable {
  final int id;
  final String sessionId;
  final String content;
  final MessageType messageType; // 'user' or 'ai'
  final DateTime createdAt;
  final List<CitationModel>? citations; // For AI responses
  final int? processingTimeMs; // For AI responses

  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.messageType,
    required this.createdAt,
    this.citations,
    this.processingTimeMs,
  });

  /// Check if message is from user
  bool get isUserMessage => messageType == MessageType.user;
  
  /// Check if message has an error
  bool get hasError => false; // TODO: Add error field if needed
  
  /// Create a copy with modified fields
  ChatMessageModel copyWith({
    int? id,
    String? sessionId,
    String? content,
    MessageType? messageType,
    DateTime? createdAt,
    List<CitationModel>? citations,
    int? processingTimeMs,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      citations: citations ?? this.citations,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'message_type': messageType.value,
      'created_at': createdAt.toIso8601String(),
      'citations': citations?.map((c) => c.toJson()).toList(),
      'processing_time_ms': processingTimeMs,
    };
  }

  /// Create from JSON response
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? json['message_id'] ?? 0,
      sessionId: json['session_id'] ?? '',
      content: json['content'] ?? json['response'] ?? '',
      messageType: MessageType.fromValue(json['message_type'] ?? json['type'] ?? 'user'),
      createdAt: DateTime.parse(json['created_at'] ?? json['timestamp'] ?? DateTime.now().toIso8601String()),
      citations: (json['citations'] as List<dynamic>?)
              ?.map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
              .toList(),
      processingTimeMs: json['processing_time_ms'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        content,
        messageType,
        createdAt,
        citations,
        processingTimeMs,
      ];
}

/// Enum for message types
enum MessageType {
  user('user'),
  ai('ai');

  final String value;
  const MessageType(this.value);

  factory MessageType.fromValue(String value) {
    return MessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MessageType.user,
    );
  }
}

/// Represents a citation in an AI response
class CitationModel extends Equatable {
  final String sermonId;
  final String sermonTitle;
  final String? speakerName;
  final String? timestamp; // MM:SS format
  final double similarityScore;
  final String? textChunk; // For excerpt display
  final String? estimatedTimestamp; // Alias for timestamp

  const CitationModel({
    required this.sermonId,
    required this.sermonTitle,
    this.speakerName,
    this.timestamp,
    this.similarityScore = 1.0,
    this.textChunk,
    this.estimatedTimestamp,
  });

  /// Formatted citation text for display/copying
  String get formattedCitation {
    final parts = [sermonTitle];
    if (speakerName != null && speakerName!.isNotEmpty) {
      parts.add('by $speakerName');
    }
    if (timestamp != null && timestamp!.isNotEmpty) {
      parts.add('at $timestamp');
    }
    return parts.join(' ');
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sermon_id': sermonId,
      'sermon_title': sermonTitle,
      'speaker_name': speakerName,
      'timestamp': timestamp ?? estimatedTimestamp,
      'similarity_score': similarityScore,
      'text_chunk': textChunk,
      'estimated_timestamp': estimatedTimestamp ?? timestamp,
    };
  }

  /// Create from JSON
  factory CitationModel.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'] ?? json['estimated_timestamp'];
    return CitationModel(
      sermonId: (json['sermon_id'] ?? '').toString(),
      sermonTitle: json['sermon_title'] ?? '',
      speakerName: json['speaker_name'],
      timestamp: timestamp,
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 1.0,
      textChunk: json['text_chunk'] as String?,
      estimatedTimestamp: timestamp,
    );
  }

  @override
  List<Object?> get props => [
        sermonId,
        sermonTitle,
        speakerName,
        timestamp,
        similarityScore,
        textChunk,
        estimatedTimestamp,
      ];
}
