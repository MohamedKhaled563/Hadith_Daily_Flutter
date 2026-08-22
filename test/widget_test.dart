import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HadithApp());

    // Verify that the app launches with expected title or components
    expect(find.byType(HadithApp), findsOneWidget);
  });
}
