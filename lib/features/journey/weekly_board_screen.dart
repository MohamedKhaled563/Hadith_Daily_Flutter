import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/board_service.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/weekly_board.dart';

/// The board's three published lists.
enum BoardList {
  points('النقاط'),
  sharing('المشاركة'),
  memo('الحفظ');

  const BoardList(this.label);

  final String label;
}

/// The weekly board, opened from the journey tab.
///
/// The published lists, then one card that is the reader's own: their
/// points against last week (never a rank), and whether they are on the
/// board, under a nickname they choose.
class WeeklyBoardScreen extends StatefulWidget {
  const WeeklyBoardScreen({super.key, this.displayName});

  /// Kept for callers that pass the account's name; the nickname field
  /// offers it when the reader has no nickname yet.
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
                Semantics(
                  header: true,
                  child: Text(
                    'لوحة الأسبوع',
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
                    onList: (list) => setState(() => _list = list),
                  ),
                  const SizedBox(height: 14),
                  _YouCard(
                    now: JourneyRepository().thisWeekPoints.total,
                    last: JourneyRepository().lastWeekPoints.total,
                    suggested: widget.displayName,
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
    required this.onList,
  });

  final WeeklyBoard? board;
  final bool loading;
  final BoardList list;
  final ValueChanged<BoardList> onList;

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
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      showWatermark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            board == null
                ? 'تُنشر كل جمعة'
                : 'أسبوع ${JourneyCopy.boardWeek(board.weekStart)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 17,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w800,
              color: palette.goldText,
            ),
          ),
          const SizedBox(height: 2),
          Text(JourneyCopy.boardNote,
              textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 14),
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
            _ListTabs(selected: list, onSelected: onList),
            const SizedBox(height: 12),
            if (list == BoardList.memo)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'أسماء بالترتيب فقط، بلا أعداد: ما يحفظه القارئ بينه وبين ربه.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            AnimatedSwitcher(
              duration: context.motion(AppDurations.content),
              child: _Rows(
                key: ValueKey(list),
                list: list,
                rows: switch (list) {
                  BoardList.points => board.points,
                  BoardList.sharing => board.sharing,
                  BoardList.memo => board.memo,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The three lists as pills in one track, the chosen one lifted.
class _ListTabs extends StatelessWidget {
  const _ListTabs({required this.selected, required this.onSelected});

  final BoardList selected;
  final ValueChanged<BoardList> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (final list in BoardList.values)
            Expanded(
              child: TapTarget(
                onTap: () {
                  AppHaptics.selection();
                  onSelected(list);
                },
                semanticLabel: list.label,
                selected: list == selected,
                pressScale: 1,
                child: AnimatedContainer(
                  duration: context.motion(AppDurations.control),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: list == selected
                        ? palette.surface
                        : palette.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: list == selected
                        ? [
                            BoxShadow(
                              color:
                                  palette.ornamentGold.withValues(alpha: .25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    list.label,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight:
                          list == selected ? FontWeight.w800 : FontWeight.w600,
                      color: list == selected
                          ? palette.goldText
                          : palette.mutedText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({super.key, required this.list, required this.rows});

  final BoardList list;
  final List<BoardRow> rows;

  bool get _sharing => list == BoardList.sharing;
  bool get _memo => list == BoardList.memo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          _sharing
              ? 'لا رسائل مقبولة في هذا الأسبوع.'
              : _memo
                  ? 'لا أسماء في الحفظ هذا الأسبوع.'
                  : 'لا أسماء هذا الأسبوع.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            color: palette.mutedText,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final (i, row) in rows.indexed)
          _Row(
            rank: i + 1,
            name: row.name,
            value: _memo
                ? null
                : _sharing
                    ? arabicMessageCount(row.value)
                    : toArabicDigits(row.value),
            spoken: _memo
                ? null
                : _sharing
                    ? arabicMessageCount(row.value)
                    : '${toArabicDigits(row.value)} نقطة',
          ),
      ],
    );
  }
}

/// One name on a list. The first three wear a medal colour; the rest a
/// plain number.
class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    this.value,
    this.spoken,
  });

  final int rank;
  final String name;
  final String? value;
  final String? spoken;

  static const _medals = [
    AppColors.gold,
    AppColors.medalSilver,
    AppColors.medalBronze,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final medal = rank <= 3 ? _medals[rank - 1] : null;

    return Semantics(
      label:
          '${toArabicDigits(rank)}، $name${spoken == null ? '' : '، $spoken'}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: medal == null
              ? palette.surface.withValues(alpha: 0)
              : medal.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medal ?? palette.surfaceSunken,
              ),
              child: Text(
                toArabicDigits(rank),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color:
                      medal == null ? palette.goldText : AppColors.darkEmerald,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 15,
                  height: AppLeading.chrome,
                  fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                  color: palette.bodyText,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: medal == null ? palette.mutedText : palette.goldText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The reader's own card: points against last week (no rank: below the
/// first ten, a number would only say how far behind someone is), and
/// their place on the board, under a nickname.
class _YouCard extends StatelessWidget {
  const _YouCard({required this.now, required this.last, this.suggested});

  /// Passed in rather than read here, so the card is rebuilt when they move.
  final int now;
  final int last;
  final String? suggested;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final service = WeeklyBoardService();
    final journey = JourneyRepository();
    final entry = service.membership.value;
    final body = TextStyle(
      fontFamily: kSans,
      fontSize: 13.5,
      height: AppLeading.body,
      color: palette.mutedText,
    );

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'نقاطك هذا الأسبوع ${toArabicDigits(now)}، '
                'والأسبوع الماضي ${toArabicDigits(last)}',
            excludeSemantics: true,
            child: Row(
              children: [
                Icon(Icons.eco_rounded, size: 20, color: palette.goldText),
                const SizedBox(width: 6),
                Text(
                  'نقاطك هذا الأسبوع',
                  style: body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.bodyText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  toArabicDigits(now),
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: palette.goldText,
                  ),
                ),
                const Spacer(),
                Text('الماضي ${toArabicDigits(last)}', style: body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.cardBorder),
          const SizedBox(height: 12),
          if (journey.isGuest) ...[
            Text(JourneyCopy.boardSignInReason, style: body),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => requireSignIn(
                  context,
                  reason: JourneyCopy.boardSignInReason,
                ),
                child: const Text('سجّل الدخول'),
              ),
            ),
          ] else if (entry == null) ...[
            Text(JourneyCopy.boardOff, style: body),
            const SizedBox(height: 10),
            AppButton(
              text: 'اظهر في اللوحة',
              icon: Icons.emoji_events_outlined,
              onPressed: () => _pickNickname(context, suggested: suggested),
            ),
          ] else ...[
            if (entry.anonymous)
              Text(
                JourneyCopy.boardPickNickname,
                style: body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.goldText,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'تظهر باسم '),
                    TextSpan(
                      text: '«${entry.name}»',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: palette.bodyText,
                      ),
                    ),
                  ],
                ),
                style: body.copyWith(fontSize: 14.5),
              ),
            const SizedBox(height: 4),
            Text(JourneyCopy.boardOn, style: body),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickNickname(
                    context,
                    current: entry.anonymous ? null : entry.name,
                    suggested: suggested,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(entry.anonymous ? 'اختر اسماً' : 'غيّر الاسم'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: service.leave,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.mutedText,
                  ),
                  child: const Text('اخرج من اللوحة'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks for a nickname, then puts the reader on the board under it.
Future<void> _pickNickname(
  BuildContext context, {
  String? current,
  String? suggested,
}) async {
  final service = WeeklyBoardService();
  final first = current ??
      (cleanNickname(suggested ?? '').isNotEmpty &&
              nicknameProblem(suggested!) == null
          ? cleanNickname(suggested)
          : service.suggestedNickname);
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NicknameSheet(initial: first),
  );
  if (name != null) service.join(nickname: name);
}

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet({required this.initial});

  final String initial;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final problem = nicknameProblem(_controller.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context, cleanNickname(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اسمك في اللوحة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 18,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w900,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            JourneyCopy.boardNicknameHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13.5,
              height: AppLeading.body,
              color: palette.mutedText,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: kNicknameMax,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'الاسم المستعار',
              errorText: _problem,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(text: 'احفظ', onPressed: _save),
        ],
      ),
    );
  }
}
