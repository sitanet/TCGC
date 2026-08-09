class Transcript {
  final String id;
  final String title;
  final String? description;
  final String content;
  final String? htmlContent;
  final String? speaker;
  final String? imageUrl;
  final String? pdfUrl;
  final String category;
  final String categoryName;
  final DateTime date;
  final bool isFeatured;
  final bool isServiceTeamOnly;
  final bool isGeneralMarriedOnly;
  final bool isInHouseMarriedOnly;

  const Transcript({
    required this.id,
    required this.title,
    this.description,
    required this.content,
    this.htmlContent,
    this.speaker,
    this.imageUrl,
    this.pdfUrl,
    required this.category,
    this.categoryName = '',
    required this.date,
    this.isFeatured = false,
    this.isServiceTeamOnly = false,
    this.isGeneralMarriedOnly = false,
    this.isInHouseMarriedOnly = false,
  });

  Transcript copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? htmlContent,
    String? speaker,
    String? imageUrl,
    String? pdfUrl,
    String? category,
    String? categoryName,
    DateTime? date,
    bool? isFeatured,
    bool? isServiceTeamOnly,
    bool? isGeneralMarriedOnly,
    bool? isInHouseMarriedOnly,
  }) {
    return Transcript(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      htmlContent: htmlContent ?? this.htmlContent,
      speaker: speaker ?? this.speaker,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      date: date ?? this.date,
      isFeatured: isFeatured ?? this.isFeatured,
      isServiceTeamOnly: isServiceTeamOnly ?? this.isServiceTeamOnly,
      isGeneralMarriedOnly: isGeneralMarriedOnly ?? this.isGeneralMarriedOnly,
      isInHouseMarriedOnly: isInHouseMarriedOnly ?? this.isInHouseMarriedOnly,
    );
  }

  factory Transcript.fromJson(Map<String, dynamic> json) {
    final categoryValue = json['category'];
    final categoryStr = categoryValue?.toString() ?? '';
    final categoryName = json['category_name']?.toString() ?? '';
    
    return Transcript(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      content: json['content'] ?? '',
      htmlContent: json['html_content'],
      speaker: json['speaker'],
      imageUrl: json['image_url'],
      pdfUrl: json['pdf_url'],
      category: categoryStr,
      categoryName: categoryName,
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      isFeatured: json['is_featured'] ?? false,
      isServiceTeamOnly: json['is_service_team_only'] ?? false,
      isGeneralMarriedOnly: json['is_general_married_only'] ?? false,
      isInHouseMarriedOnly: json['is_in_house_married_only'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'html_content': htmlContent,
      'speaker': speaker,
      'image_url': imageUrl,
      'pdf_url': pdfUrl,
      'category': category,
      'category_name': categoryName,
      'date': date.toIso8601String(),
      'is_featured': isFeatured,
      'is_service_team_only': isServiceTeamOnly,
      'is_general_married_only': isGeneralMarriedOnly,
      'is_in_house_married_only': isInHouseMarriedOnly,
    };
  }
}
