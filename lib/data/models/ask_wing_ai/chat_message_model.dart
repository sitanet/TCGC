import 'package:equatable/equatable.dart';

/// Represents a message in the Ask Wing AI chat interface
class ChatMessageModel extends Equatable {
  final String id;
  final String content;
  final ChatMessageType type; // 'user' or 'ai'
  final DateTime timestamp;
  final List<CitationModel> citations; // For AI responses
  final int? processingTimeMs; // For AI responses
  final String? errorMessage; // For error cases

  const ChatMessageModel({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.citations = const [],
    this.processingTimeMs,
    this.errorMessage,
  });

  /// Create a copy with modified fields
  ChatMessageModel copyWith({
    String? id,
    String? content,
    ChatMessageType? type,
    DateTime? timestamp,
    List<CitationModel>? citations,
    int? processingTimeMs,
    String? errorMessage,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      citations: citations ?? this.citations,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'citations': citations.map((c) => c.toJson()).toList(),
      'processing_time_ms': processingTimeMs,
      'error_message': errorMessage,
    };
  }

  /// Create from JSON response
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? json['message_id'] ?? '',
      content: json['content'] ?? json['response'] ?? '',
      type: ChatMessageType.fromValue(json['type'] ?? 'user'),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      citations: (json['citations'] as List<dynamic>?)
              ?.map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      processingTimeMs: json['processing_time_ms'],
      errorMessage: json['error_message'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        type,
        timestamp,
        citations,
        processingTimeMs,
        errorMessage,
      ];
}

/// Enum for message types
enum ChatMessageType {
  user('user'),
  ai('ai');

  final String value;
  const ChatMessageType(this.value);

  factory ChatMessageType.fromValue(String value) {
    return ChatMessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ChatMessageType.user,
    );
  }
}

/// Represents a citation in an AI response
class CitationModel extends Equatable {
  final String sermonId;
  final String sermonTitle;
  final String speakerName;
  final String? timestamp; // MM:SS format
  final double similarityScore;

  const CitationModel({
    required this.sermonId,
    required this.sermonTitle,
    required this.speakerName,
    this.timestamp,
    this.similarityScore = 1.0,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sermon_id': sermonId,
      'sermon_title': sermonTitle,
      'speaker_name': speakerName,
      'timestamp': timestamp,
      'similarity_score': similarityScore,
    };
  }

  /// Create from JSON
  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      sermonId: json['sermon_id'] ?? '',
      sermonTitle: json['sermon_title'] ?? '',
      speakerName: json['speaker_name'] ?? '',
      timestamp: json['timestamp'],
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [
        sermonId,
        sermonTitle,
        speakerName,
        timestamp,
        similarityScore,
      ];
}
