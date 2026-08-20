import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../services/favorites_service.dart';
import '../services/share_service.dart';
import '../widgets/hadith_card.dart';

class HadithDetailsScreen extends StatefulWidget {
  final Hadith hadith;
  const HadithDetailsScreen({super.key, required this.hadith});

  @override
  State<HadithDetailsScreen> createState() => _HadithDetailsScreenState();
}

class _HadithDetailsScreenState extends State<HadithDetailsScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    FavoritesService.instance.isFavorite(widget.hadith.number).then((v) {
      if (mounted) setState(() => _isFavorite = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hadith = widget.hadith;

    return Scaffold(
      appBar: AppBar(
        title: Text(hadith.title),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () async {
              final nowFav =
                  await FavoritesService.instance.toggle(hadith.number);
              setState(() => _isFavorite = nowFav);
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => ShareService.shareWidgetAsImage(
              widget: SizedBox(width: 360, child: HadithCard(hadith: hadith)),
              fileName: 'hadith_${hadith.number}',
              text: '${hadith.title} — ${hadith.text}',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            HadithCard(hadith: hadith),
            if (hadith.explanation.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('الشرح والفوائد', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(hadith.explanation, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
