import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../theme/app_theme.dart';
import 'share_service.dart';

class ShareTemplateService {
  static const styles = <String, String>{
    'cream': 'الورق الكريمي',
    'forest': 'الأخضر الهادئ',
    'midnight': 'المساء',
  };

  static Widget build({required Hadith hadith, required String style}) {
    final dark = style == 'midnight';
    final forest = style == 'forest';
    final background = dark
        ? const Color(0xFF142019)
        : forest
            ? const Color(0xFF315A46)
            : const Color(0xFFF7F2E8);
    final foreground = dark || forest ? const Color(0xFFF5F1E8) : AppColors.ink;
    final accent = dark || forest ? const Color(0xFFD5B37A) : AppColors.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 1080,
        padding: const EdgeInsets.fromLTRB(80, 70, 80, 70),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(34),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'حديثك اليوم',
              style: const TextStyle(fontFamily: 'sans-serif', fontSize: 34, fontWeight: FontWeight.w700).copyWith(color: accent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 38),
            Text(
              hadith.text,
              style: TextStyle(fontFamily: 'serif', fontSize: 58, height: 1.75, color: foreground),
              textAlign: TextAlign.center,
            ),
            if (hadith.source != null) ...[
              const SizedBox(height: 32),
              Center(child: Container(width: 80, height: 2, color: accent.withValues(alpha: 0.55))),
              const SizedBox(height: 18),
              Text(
                hadith.source!,
                style: TextStyle(fontSize: 28, color: foreground.withValues(alpha: 0.72)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 44),
            Text(
              'Hadith Daily',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: foreground.withValues(alpha: 0.45)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> share({required Hadith hadith, required String style}) {
    return ShareService.shareWidgetAsImage(
      widget: build(hadith: hadith, style: style),
      fileName: 'hadith_${hadith.number}_$style',
      text: '${hadith.title} — ${hadith.text}',
    );
  }
}
