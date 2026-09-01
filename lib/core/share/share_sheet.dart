import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/botanical_sheet.dart';
import 'share_card.dart';
import 'share_service.dart';

/// Shows the poster the reader is about to send, then hands it to the system
/// share sheet.
///
/// Previewing matters here: the image is the message once it leaves the app, so
/// seeing it beforehand is the difference between sharing confidently and
/// hoping for the best.
Future<void> showShareSheet({
  required BuildContext context,
  required String message,
  String? hadithTitle,
  String? hadithNumber,
  String? attribution,
  String? category,
}) {
  return showBotanicalSheet<void>(
    context: context,
    title: 'مشاركة البطاقة 🌿',
    subtitle: 'ستُرسل كصورة تحمل هوية التطبيق',
    child: Builder(
      builder: (sheetContext) {
        final palette = sheetContext.palette;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scaled-down view of the exact poster that will be sent.
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppElevation.card,
                  ),
                  child: SizedBox(
                    width: ShareCard.width * 0.62,
                    height: ShareCard.height * 0.62,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ShareCard(
                        message: message,
                        hadithTitle: hadithTitle,
                        hadithNumber: hadithNumber,
                        attribution: attribution,
                        category: category,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            AppButton(
              text: 'مشاركة الصورة',
              icon: Icons.ios_share_rounded,
              onPressed: () async {
                Navigator.pop(sheetContext);
                showAppLoadingOverlay(context, message: 'جارٍ تجهيز البطاقة…');
                try {
                  await ShareService.shareMessage(
                    context: context,
                    message: message,
                    hadithTitle: hadithTitle,
                    hadithNumber: hadithNumber,
                    attribution: attribution,
                    category: category,
                  );
                } finally {
                  hideAppLoadingOverlay();
                }
              },
            ),

            const SizedBox(height: 10),

            AppButton(
              text: 'نسخ النص',
              isSecondary: true,
              icon: Icons.copy_rounded,
              onPressed: () {
                final buffer = StringBuffer('« $message »');
                if (hadithTitle != null && hadithTitle.trim().isNotEmpty) {
                  buffer.write('\n\n📌 ');
                  buffer.write(
                    hadithNumber == null
                        ? hadithTitle
                        : 'الحديث $hadithNumber: $hadithTitle',
                  );
                }
                buffer.write('\n🌿 من تطبيق «طيّب قلبك»');

                Clipboard.setData(ClipboardData(text: buffer.toString()));
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ النص بنجاح 🌿')),
                );
              },
            ),

            const SizedBox(height: 12),

            Text(
              'شارك عبر أي تطبيق مثبت لديك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11.5,
                height: AppLeading.body,
                fontWeight: FontWeight.w600,
                color: palette.mutedText,
              ),
            ),
          ],
        );
      },
    ),
  );
}
