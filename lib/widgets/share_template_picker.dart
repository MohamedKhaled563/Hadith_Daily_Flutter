import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../services/app_preferences_service.dart';
import '../services/share_template_service.dart';

Future<void> showShareTemplatePicker(BuildContext context, Hadith hadith) async {
  var selected = await AppPreferencesService.instance.getShareStyle();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('اختار شكل المشاركة', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('نفس الحديث، بثلاث شخصيات بصرية مختلفة.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 155,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ShareTemplateService.styles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final key = ShareTemplateService.styles.keys.elementAt(index);
                        final title = ShareTemplateService.styles.values.elementAt(index);
                        final active = key == selected;
                        return GestureDetector(
                          onTap: () => setModalState(() => selected = key),
                          child: Container(
                            width: 240,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: active ? 2 : 1)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Expanded(child: ShareTemplateService.build(hadith: hadith, style: key)),
                                Padding(padding: const EdgeInsets.all(10), child: Text(title, style: Theme.of(context).textTheme.labelLarge)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await AppPreferencesService.instance.setShareStyle(selected);
                      await ShareTemplateService.share(hadith: hadith, style: selected);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('مشاركة'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
