class Insight {
  final int hadithNumber;
  final String arabic;
  final String english;

  /// Message type from the source workbook — تأمّل, إرشاد عملي, and so on.
  /// Used as the pill label on the daily-message card.
  final String category;

  final String themes;
  final String keywords;

  /// Firestore doc id this insight was loaded from, and which collection
  /// ('dailyMessages' | 'communityMessages') it lives in — empty when the
  /// insight has no backing doc (e.g. a bundled/local-only or notification
  /// insight), which is what tells the like button there's nothing to
  /// persist a like against.
  final String id;
  final String sourceCollection;

  const Insight({
    required this.hadithNumber,
    required this.arabic,
    required this.english,
    this.category = 'رسالة اليوم',
    this.themes = '',
    this.keywords = '',
    this.id = '',
    this.sourceCollection = '',
  });

  String get message => arabic;

  bool get isLikeable => id.isNotEmpty && sourceCollection.isNotEmpty;

  factory Insight.fromJson(Map<String, dynamic> json) {
    final category = (json['category'] as String? ?? '').trim();

    return Insight(
      hadithNumber: json['hadithNumber'] as int,
      arabic: json['arabic'] as String? ?? '',
      english: json['english'] as String? ?? '',
      category: category.isEmpty ? 'رسالة اليوم' : category,
      themes: json['themes'] as String? ?? '',
      keywords: json['keywords'] as String? ?? '',
      id: json['id'] as String? ?? '',
      sourceCollection: json['sourceCollection'] as String? ?? '',
    );
  }
}

class CommunityPost {
  final String id;
  final String authorName;
  final String message;
  final int hadithNumber;
  int likes;
  final DateTime createdAt;

  String get arabic => message;

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.message,
    required this.hadithNumber,
    this.likes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
