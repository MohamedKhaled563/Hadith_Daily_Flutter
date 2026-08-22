class Insight {
  final int hadithNumber;
  final String arabic;
  final String english;

  const Insight({
    required this.hadithNumber,
    required this.arabic,
    required this.english,
  });

  String get message => arabic;
  String get category => 'رسالة اليوم';

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      hadithNumber: json['hadithNumber'] as int,
      arabic: json['arabic'] as String? ?? '',
      english: json['english'] as String? ?? '',
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
