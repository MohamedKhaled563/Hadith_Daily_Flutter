class Insight {
  final int hadithNumber;
  final String arabic;
  final String english;

  /// Message type from the source workbook — تأمّل, إرشاد عملي, and so on.
  /// Used as the pill label on the daily-message card.
  final String category;

  final String themes;
  final String keywords;

  const Insight({
    required this.hadithNumber,
    required this.arabic,
    required this.english,
    this.category = 'رسالة اليوم',
    this.themes = '',
    this.keywords = '',
  });

  String get message => arabic;

  factory Insight.fromJson(Map<String, dynamic> json) {
    final category = (json['category'] as String? ?? '').trim();

    return Insight(
      hadithNumber: json['hadithNumber'] as int,
      arabic: json['arabic'] as String? ?? '',
      english: json['english'] as String? ?? '',
      category: category.isEmpty ? 'رسالة اليوم' : category,
      themes: json['themes'] as String? ?? '',
      keywords: json['keywords'] as String? ?? '',
    );
  }
}

class CommunityPost {
  final String id;
  final String authorName;
  final String message;
  final int hadithNumber;
  int likes;
  bool isLiked;
  final DateTime createdAt;

  String get arabic => message;

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.message,
    required this.hadithNumber,
    this.likes = 0,
    this.isLiked = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
