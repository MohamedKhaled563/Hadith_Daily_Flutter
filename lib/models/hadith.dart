class Hadith {
  final int number;
  final String title;
  final String text;
  final String? source;
  final String explanation;

  const Hadith({
    required this.number,
    required this.title,
    required this.text,
    required this.source,
    required this.explanation,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      number: json['number'] as int,
      title: json['title'] as String,
      text: json['text'] as String,
      source: json['source'] as String?,
      explanation: (json['explanation'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'text': text,
      'source': source,
      'explanation': explanation,
    };
  }
}
