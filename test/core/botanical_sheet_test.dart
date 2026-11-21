import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/botanical_sheet.dart';

/// QA PT-017: on a phone with the three-button navigation bar, «إرسال
/// الاقتراح» at the foot of «تواصل معنا واقترح» was half under the bar.
/// `useSafeArea` keeps only the top and sides clear, so the sheet has to
/// make room at the bottom itself.

const _bar = 48.0;

Future<void> _openSheet(WidgetTester tester, {required double bar}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(bottom: bar * 3);
  tester.view.viewPadding = FakeViewPadding(bottom: bar * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showBotanicalSheet<void>(
                context: context,
                title: 'تواصل معنا واقترح',
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('إرسال الاقتراح'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _screenHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

void main() {
  testWidgets('the last button sits above the navigation bar', (tester) async {
    await _openSheet(tester, bar: _bar);

    final button = tester.getRect(find.byType(FilledButton));
    expect(button.bottom, lessThanOrEqualTo(_screenHeight(tester) - _bar));
  });

  testWidgets('without a bar the sheet keeps its own gap only', (tester) async {
    await _openSheet(tester, bar: 0);

    final button = tester.getRect(find.byType(FilledButton));
    expect(_screenHeight(tester) - button.bottom, closeTo(24, 1));
  });
}
