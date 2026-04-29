class Ebook {
  final String id;
  final String title;
  final String? description;
  final String? author;
  final String? coverImageUrl;
  final String? fileUrl;
  final String category;
  final String categoryName;
  final int? pages;
  final bool isFeatured;
  final bool isFree;
  final bool isServiceTeamOnly;
  final bool isGeneralMarriedOnly;
  final bool isInHouseMarriedOnly;
  final DateTime date;

  const Ebook({
    required this.id,
    required this.title,
    this.description,
    this.author,
    this.coverImageUrl,
    this.fileUrl,
    required this.category,
    this.categoryName = '',
    this.pages,
    this.isFeatured = false,
    this.isFree = true,
    this.isServiceTeamOnly = false,
    this.isGeneralMarriedOnly = false,
    this.isInHouseMarriedOnly = false,
    required this.date,
  });

  factory Ebook.fromJson(Map<String, dynamic> json) {
    return Ebook(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      author: json['author'],
      coverImageUrl: json['cover_image_url'],
      fileUrl: json['file_download_url'] ?? json['file_url'],
      category: json['category']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      pages: json['pages'],
      isFeatured: json['is_featured'] ?? false,
      isFree: json['is_free'] ?? true,
      isServiceTeamOnly: json['is_service_team_only'] ?? false,
      isGeneralMarriedOnly: json['is_general_married_only'] ?? false,
      isInHouseMarriedOnly: json['is_in_house_married_only'] ?? false,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
  }
}
