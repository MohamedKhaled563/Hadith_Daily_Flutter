import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../data/journey/board_service.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/weekly_board.dart';

/// The board's three published lists.
enum BoardList { points, sharing, memo }

/// The weekly board, opened from the journey tab.
///
/// The published lists, the reader's own points against last week (never a
/// rank), and the switch that puts them on the board, which is off until
/// they turn it on.
class WeeklyBoardScreen extends StatefulWidget {
  const WeeklyBoardScreen({super.key, this.displayName});

  /// The reader's own name, offered as one of the two ways to appear.
  /// Defaults to the signed-in account's.
  final String? displayName;

  @override
  State<WeeklyBoardScreen> createState() => _WeeklyBoardScreenState();
}

class _WeeklyBoardScreenState extends State<WeeklyBoardScreen> {
  final _service = WeeklyBoardService();
  bool _loading = true;
  BoardList _list = BoardList.points;

  @override
  void initState() {
    super.initState();
    _service.loadBoard().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'رجوع',
                  onTap: () => Navigator.maybePop(context),
                ),
                Text(
                  'لوحة الأسبوع',
                  style: textTheme.titleMedium?.copyWith(fontSize: 18),
                ),
                const SizedBox(width: CircleIconButton.slot),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _service.board,
                _service.membership,
                JourneyRepository().listenable,
              ]),
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  _BoardCard(
                    board: _service.board.value,
                    loading: _loading,
                    list: _list,
                    onSection: (list) => setState(() => _list = list),
                  ),
                  const SizedBox(height: 14),
                  _OwnPoints(
                    now: JourneyRepository().thisWeekPoints.total,
                    last: JourneyRepository().lastWeekPoints.total,
                  ),
                  const SizedBox(height: 14),
                  _JoinCard(
                    // The account's own name, never the email the app shows
                    // elsewhere when a name is missing: this one is public.
                    displayName: widget.displayName ??
                        (JourneyRepository().isGuest
                            ? null
                            : FirebaseAuth.instance.currentUser?.displayName),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.board,
    required this.loading,
    required this.list,
    required this.onSection,
  });

  final WeeklyBoard? board;
  final bool loading;
  final BoardList list;
  final ValueChanged<BoardList> onSection;

  bool get sharing => list == BoardList.sharing;
  bool get memo => list == BoardList.memo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = TextStyle(
      fontFamily: kSans,
      fontSize: 13,
      height: AppLeading.chrome,
      color: palette.mutedText,
    );
    final board = this.board;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      showWatermark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (board != null) ...[
            Text(
              'أسبوع ${JourneyCopy.boardWeek(board.weekStart)}',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 16,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: palette.goldText,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(JourneyCopy.boardNote, style: muted),
          const SizedBox(height: 12),
          if (board == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      JourneyCopy.boardNotYet,
                      textAlign: TextAlign.center,
                      style: muted.copyWith(fontSize: 14.5),
                    ),
            )
          else ...[
            SegmentedButton<BoardList>(
              segments: const [
                ButtonSegment(value: BoardList.points, label: Text('النقاط')),
                ButtonSegment(
                  value: BoardList.sharing,
                  label: Text('المشاركة'),
                ),
                ButtonSegment(value: BoardList.memo, label: Text('الحفظ')),
              ],
              selected: {list},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onSection(s.first),
            ),
            const SizedBox(height: 10),
            if (memo)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'أسماء بالترتيب فقط، بلا أعداد: ما يحفظه القارئ بينه وبين ربه.',
                  style: muted,
                ),
              ),
            ..._rows(
              context,
              switch (list) {
                BoardList.points => board.points,
                BoardList.sharing => board.sharing,
                BoardList.memo => board.memo,
              },
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<BoardRow> rows) {
    final palette = context.palette;
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            sharing
                ? 'لا رسائل مقبولة في هذا الأسبوع.'
                : memo
                    ? 'لا أسماء في الحفظ هذا الأسبوع.'
                    : 'لا أسماء هذا الأسبوع.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              color: palette.mutedText,
            ),
          ),
        ),
      ];
    }
    return [
      for (final (i, row) in rows.indexed)
        Semantics(
          label: '${toArabicDigits(i + 1)}، ${row.name}'
              '${memo ? '' : '، ${sharing ? arabicMessageCount(row.value) : '${toArabicDigits(row.value)} نقطة'}'}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    toArabicDigits(i + 1),
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.goldText,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14.5,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w600,
                      color: palette.bodyText,
                    ),
                  ),
                ),
                if (!memo)
                  Text(
                    sharing
                        ? arabicMessageCount(row.value)
                        : toArabicDigits(row.value),
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.mutedText,
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// The reader's own week, against the last. No rank: below the first ten,
/// a number would only say how far behind someone is.
class _OwnPoints extends StatelessWidget {
  const _OwnPoints({required this.now, required this.last});

  /// Passed in rather than read here, so the row is rebuilt when they move.
  final int now;
  final int last;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(
      fontFamily: kSans,
      fontSize: 14,
      height: AppLeading.chrome,
      color: palette.mutedText,
    );

    return Semantics(
      label: 'نقاطك هذا الأسبوع ${toArabicDigits(now)}، '
          'والأسبوع الماضي ${toArabicDigits(last)}',
      excludeSemantics: true,
      child: ParchmentCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        showWatermark: false,
        child: Row(
          children: [
            Icon(Icons.eco_rounded, size: 18, color: palette.goldText),
            const SizedBox(width: 6),
            Text('نقاطك هذا الأسبوع', style: style),
            const SizedBox(width: 6),
            Text(
              toArabicDigits(now),
              style: style.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: palette.goldText,
              ),
            ),
            const Spacer(),
            Text('الماضي ${toArabicDigits(last)}', style: style),
          ],
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final service = WeeklyBoardService();
    final journey = JourneyRepository();
    final entry = service.membership.value;
    final joined = entry != null;
    final ownName = displayName?.trim() ?? '';
    final body = TextStyle(
      fontFamily: kSans,
      fontSize: 13.5,
      height: AppLeading.body,
      color: palette.mutedText,
    );

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      showWatermark: false,
      // The switch and radio rows draw their ripple on the nearest Material,
      // which would otherwise be under the card's own background.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (journey.isGuest) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Text(JourneyCopy.boardSignInReason, style: body),
              ),
              TextButton(
                onPressed: () => requireSignIn(
                  context,
                  reason: JourneyCopy.boardSignInReason,
                ),
                child: const Text('سجّل الدخول'),
              ),
            ] else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'الظهور في اللوحة',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.bodyText,
                  ),
                ),
                value: joined,
                onChanged: (on) {
                  if (on) {
                    // Anonymous first: the reader chooses to show their name.
                    service.join(useName: false);
                  } else {
                    service.leave();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  joined ? JourneyCopy.boardOn : JourneyCopy.boardOff,
                  style: body,
                ),
              ),
              if (joined) ...[
                const SizedBox(height: 4),
                RadioGroup<bool>(
                  groupValue: !entry.anonymous,
                  onChanged: (useName) =>
                      service.join(useName: useName ?? false),
                  child: Column(
                    children: [
                      const RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        title: Text('باسم «$kAnonymousName»'),
                      ),
                      if (ownName.isNotEmpty)
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text('باسمي: $ownName'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
