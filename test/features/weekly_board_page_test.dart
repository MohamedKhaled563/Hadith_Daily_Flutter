import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
import 'package:hadith_app/features/dashboard/weekly_board_page.dart';

class _FakeModeration implements BoardModeration {
  _FakeModeration({required this.byWeek, this.approved = const []});

  final Map<int, List<ScoreEntry>> byWeek;
  final List<({String authorUid, DateTime reviewedAt})> approved;
  WeeklyBoard? current;
  final List<WeeklyBoard> publishedBoards = [];
  final List<int> asked = [];

  @override
  Future<List<ScoreEntry>> scores(int week) async {
    asked.add(week);
    return byWeek[week] ?? const [];
  }

  @override
  Future<List<({String authorUid, DateTime reviewedAt})>> approvedAround(
    int week,
  ) async =>
      approved;

  @override
  Future<WeeklyBoard?> published() async => current;

  @override
  Future<void> publish(WeeklyBoard board) async {
    publishedBoards.add(board);
    current = board;
  }
}

/// The moderator's Friday tab, against a fake store.
void main() {
  final now = DateTime(2026, 11, 13, 20);
  final week = boardWeekOf('2026-11-07');

  ScoreEntry entry(String uid, String name, int device) =>
      ScoreEntry(uid: uid, week: week, device: device, name: name);

  Future<_FakeModeration> open(
    WidgetTester tester, {
    List<ScoreEntry>? scores,
    List<({String authorUid, DateTime reviewedAt})> approved = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moderation = _FakeModeration(
      byWeek: {
        week: scores ??
            [
              entry('a', 'سارة', 210),
              entry('b', 'فاعل خير', 300),
              entry('c', 'نور', 120),
            ],
        week - 1: [
          ScoreEntry(uid: 'old', week: week - 1, device: 50, name: 'قديم'),
        ],
      },
      approved: approved,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyBoardPage(moderation: moderation, now: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return moderation;
  }

  testWidgets('lists everyone who joined this week, highest first',
      (tester) async {
    await open(tester);

    expect(find.text('أسبوع ٧ – ١٣ نوفمبر'), findsOneWidget);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => ['سارة', 'فاعل خير', 'نور'].contains(d))
        .toList();
    expect(names, ['فاعل خير', 'سارة', 'نور']);
    // The dashboard is a tool, with western digits throughout.
    expect(find.textContaining('انضم 3 قارئ'), findsOneWidget);
    expect(find.textContaining('بأقل من نحو 50'), findsOneWidget);
  });

  testWidgets('approved messages are counted from the messages themselves',
      (tester) async {
    await open(
      tester,
      approved: [
        (authorUid: 'c', reviewedAt: DateTime(2026, 11, 9, 12)),
        (authorUid: 'c', reviewedAt: DateTime(2026, 11, 10, 12)),
        (authorUid: 'c', reviewedAt: DateTime(2026, 10, 30, 12)),
      ],
    );

    // نور: 120 from the phone and two approvals this week, 150.
    expect(find.text('150'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('a hidden name stays off what is published', (tester) async {
    final moderation = await open(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('نشر اللوحة'));
    await tester.pumpAndSettle();
    expect(find.text('نشر لوحة الأسبوع'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'نشر'));
    await tester.pumpAndSettle();

    final board = moderation.publishedBoards.single;
    expect(board.week, week);
    expect(board.points.map((r) => r.name), ['سارة', 'نور']);
    expect(find.text('نُشرت اللوحة'), findsOneWidget);
    expect(find.textContaining('المنشورة الآن: أسبوع ٧ – ١٣ نوفمبر'),
        findsOneWidget);
  });

  testWidgets('cancelling publishes nothing', (tester) async {
    final moderation = await open(tester);

    await tester.tap(find.text('نشر اللوحة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(moderation.publishedBoards, isEmpty);
  });

  testWidgets('last week can be published late', (tester) async {
    final moderation = await open(tester);

    await tester.tap(find.text('الأسبوع الماضي'));
    await tester.pumpAndSettle();

    expect(moderation.asked.last, week - 1);
    expect(find.text('قديم'), findsOneWidget);
    expect(find.text('أسبوع ٣١ أكتوبر – ٦ نوفمبر'), findsOneWidget);
  });

  testWidgets('an empty week has nothing to publish', (tester) async {
    await open(tester, scores: const []);

    expect(find.text('لم ينضم أحد لهذا الأسبوع بعد.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('نشر اللوحة'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
