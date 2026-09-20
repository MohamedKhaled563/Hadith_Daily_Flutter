import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/app_loading_overlay.dart';

/// The imperative overlay absorbs every tap on the screen, so a caller that
/// throws before reaching `hideAppLoadingOverlay` leaves the reader holding a
/// phone that appears frozen with no way out. The deadline does not fix that
/// bug — it stops it being unrecoverable.

Widget _host(void Function(BuildContext) onTap) => MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onTap(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

Finder get _scrim => find.text('جارٍ التحميل…');

void main() {
  testWidgets('an overlay nobody hides removes itself', (tester) async {
    await tester.pumpWidget(_host((c) => showAppLoadingOverlay(
          c,
          maxDuration: const Duration(seconds: 5),
        )));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(_scrim, findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(_scrim, findsOneWidget, reason: 'it must not leave early');

    await tester.pump(const Duration(seconds: 2));
    expect(_scrim, findsNothing);
  });

  testWidgets('hiding it cancels the deadline', (tester) async {
    // Otherwise a stale timer from an earlier cycle tears down a *later*
    // overlay showing under the same key.
    await tester.pumpWidget(_host((c) => showAppLoadingOverlay(
          c,
          maxDuration: const Duration(seconds: 5),
        )));

    await tester.tap(find.text('go'));
    await tester.pump();
    hideAppLoadingOverlay();
    await tester.pump();
    expect(_scrim, findsNothing);

    // Show again, well inside the first deadline's window.
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
      _scrim,
      findsOneWidget,
      reason: 'the first cycle\'s timer must not take this one down',
    );

    hideAppLoadingOverlay();
    await tester.pump();
  });
}
