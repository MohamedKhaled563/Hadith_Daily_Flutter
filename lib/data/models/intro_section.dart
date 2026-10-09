/// One of the readings shown ahead of the forty hadiths — الإمام النووي's own
/// introduction to the book, and his biography. Generated into
/// `assets/data/nawawi_intro.json` by `tool/import_hadiths_v2.py`.
class IntroSection {
  final String key;
  final String title;
  final List<IntroBlock> blocks;

  const IntroSection({
    required this.key,
    required this.title,
    required this.blocks,
  });

  factory IntroSection.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    return IntroSection(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      blocks: rawBlocks is List
          ? rawBlocks
              .map((e) => IntroBlock.fromJson(e as Map<String, dynamic>))
              .where((b) => b.text.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

enum IntroBlockType { heading, paragraph, bullet }

class IntroBlock {
  final IntroBlockType type;
  final String text;

  const IntroBlock({required this.type, required this.text});

  factory IntroBlock.fromJson(Map<String, dynamic> json) {
    return IntroBlock(
      type: switch (json['type']) {
        'heading' => IntroBlockType.heading,
        'bullet' => IntroBlockType.bullet,
        _ => IntroBlockType.paragraph,
      },
      text: (json['text'] as String? ?? '').trim(),
    );
  }
}
