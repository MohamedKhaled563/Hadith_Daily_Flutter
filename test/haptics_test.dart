import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/core/widgets/like_counter.dart';

/// The app had no haptic feedback anywhere. These assert that the platform
/// call actually fires — the sensation itself is not testable, but "did we
/// ask the OS" is, and that is the part that regresses silently.

/// Records every haptic/system-sound call made through SystemChannels.platform.
class _HapticRecorder {
  final calls = <String>[];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate' ||
            call.method == 'SystemSound.play') {
          calls.add('${call.method}:${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('changing tabs asks for feedback', (tester) async {
    final haptics = _HapticRecorder()..install(tester);
    var tapped = -1;

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          bottomNavigationBar: BottomNavigation(
            currentIndex: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(haptics.calls, isNotEmpty,
        reason: 'moving between tabs should give a selection tick');
  });

  testWidgets('re-tapping the current tab stays silent', (tester) async {
    final haptics = _HapticRecorder()..install(tester);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          bottomNavigationBar: BottomNavigation(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();

    expect(haptics.calls, isEmpty,
        reason: 'you did not go anywhere, so nothing should buzz');
  });

  testWidgets('liking asks for feedback', (tester) async {
    final haptics = _HapticRecorder()..install(tester);
    var liked = false;

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Center(
            child: LikeCounter(
              likes: 3,
              isLiked: false,
              onTap: () => liked = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(LikeCounter));
    await tester.pumpAndSettle();

    expect(liked, isTrue);
    expect(haptics.calls, isNotEmpty);
  });
}
