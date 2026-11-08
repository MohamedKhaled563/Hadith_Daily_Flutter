import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_points.dart';
import '../../data/journey/weekly_board.dart';

/// What the board tab reads and writes.
abstract class BoardModeration {
  /// Everyone on the board for [week].
  Future<List<ScoreEntry>> scores(int week);

  /// Approved messages reviewed around [week], a day either side, so a reader
  /// in another time zone is not cut off. [approvalsInWeek] trims them.
  Future<List<({String authorUid, DateTime reviewedAt})>> approvedAround(
    int week,
  );

  Future<WeeklyBoard?> published();

  Future<void> publish(WeeklyBoard board);
}

class FirestoreBoardModeration implements BoardModeration {
  FirestoreBoardModeration([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // One equality filter, so no composite index is needed.
  @override
  Future<List<ScoreEntry>> scores(int week) async {
    final snap =
        await _db.collection('scores').where('week', isEqualTo: week).get();
    return [
      for (final doc in snap.docs) ScoreEntry.fromJson(doc.id, doc.data())
    ];
  }

  // A range on reviewedAt alone, with the status checked here: adding the
  // status to the query would need a composite index.
  @override
  Future<List<({String authorUid, DateTime reviewedAt})>> approvedAround(
    int week,
  ) async {
    final start = DateTime.parse(boardWeekStart(week));
    final snap = await _db
        .collection('communityMessages')
        .where(
          'reviewedAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(start.subtract(const Duration(days: 1))),
        )
        .where(
          'reviewedAt',
          isLessThan: Timestamp.fromDate(start.add(const Duration(days: 8))),
        )
        .get();
    return [
      for (final doc in snap.docs)
        if (doc.data()['status'] == 'approved' &&
            doc.data()['authorUid'] is String &&
            doc.data()['reviewedAt'] is Timestamp)
          (
            authorUid: doc.data()['authorUid'] as String,
            reviewedAt: (doc.data()['reviewedAt'] as Timestamp).toDate(),
          ),
    ];
  }

  @override
  Future<WeeklyBoard?> published() async {
    final snap = await _db.collection('settings').doc('weeklyBoard').get();
    final data = snap.data();
    if (data == null) return null;
    final at = data['publishedAt'];
    return WeeklyBoard.fromJson({
      ...data,
      'publishedAt': at is Timestamp ? at.toDate() : null,
    });
  }

  @override
  Future<void> publish(WeeklyBoard board) =>
      _db.collection('settings').doc('weeklyBoard').set({
        ...board.toJson(),
        'publishedAt': FieldValue.serverTimestamp(),
      });
}

/// The Friday job: see who joined this week, hide anything that should not
/// be there, publish the first ten. Points come from the readers' phones and
/// are capped by the rules; approved messages are counted here, from the
/// messages a moderator approved, so nobody can award those to themselves.
class WeeklyBoardPage extends StatefulWidget {
  const WeeklyBoardPage({super.key, this.moderation, this.now});

  final BoardModeration? moderation;

  /// For tests. Defaults to the clock.
  final DateTime Function()? now;

  @override
  State<WeeklyBoardPage> createState() => _WeeklyBoardPageState();
}

class _WeeklyBoardPageState extends State<WeeklyBoardPage> {
  late final BoardModeration _moderation =
      widget.moderation ?? FirestoreBoardModeration();

  late final int _thisWeek =
      boardWeekOfDay(journeyDayKey((widget.now ?? DateTime.now)()));
  late int _week = _thisWeek;

  List<BoardCandidate>? _ranked;
  WeeklyBoard? _published;
  final Set<String> _hidden = {};
  Object? _error;
  bool _loading = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final week = _week;
      final results = await Future.wait([
        _moderation.scores(week),
        _moderation.approvedAround(week),
        _moderation.published(),
      ]);
      if (!mounted || week != _week) return;
      final scores = results[0] as List<ScoreEntry>;
      final approved =
          results[1] as List<({String authorUid, DateTime reviewedAt})>;
      setState(() {
        _ranked = rankCandidates(
          week: week,
          scores: scores,
          approvals: approvalsInWeek(approved, week),
        );
        _published = results[2] as WeeklyBoard?;
        _hidden.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final ranked = _ranked;
    if (ranked == null) return;
    final board = publishBoard(week: _week, ranked: ranked, hidden: _hidden);
    final replacing = _published;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نشر لوحة الأسبوع'),
        content: Text(
          'ستظهر ${board.points.length} أسماء في النقاط و'
          '${board.sharing.length} في المشاركة و${board.memo.length} في الحفظ '
          '(أسماء بلا أرقام) لكل القراء'
          '${replacing == null ? '' : '، وتحل محل لوحة أسبوع ${JourneyCopy.boardWeek(replacing.weekStart)}'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نشر'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      await _moderation.publish(board);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نُشرت اللوحة')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر النشر: $error')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                      value: _thisWeek, label: const Text('هذا الأسبوع')),
                  ButtonSegment(
                    value: _thisWeek - 1,
                    label: const Text('الأسبوع الماضي'),
                  ),
                ],
                selected: {_week},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _week = s.first);
                  _load();
                },
              ),
              Text(
                'أسبوع ${JourneyCopy.boardWeek(boardWeekStart(_week))}',
                style: textTheme.titleMedium,
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_published != null)
            Text(
              'المنشورة الآن: أسبوع ${JourneyCopy.boardWeek(_published!.weekStart)}',
              style: textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          if (_error != null)
            Text('تعذّر التحميل: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (ranked == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              'انضم ${ranked.length} قارئ هذا الأسبوع.'
              '${ranked.length < kBoardReadyAt ? ' تبدو اللوحة فارغة بأقل من نحو $kBoardReadyAt قارئاً، والنشر متاح على أي حال.' : ''}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'النقاط من هواتف القراء، بحد ${PointRules.deviceWeekCap} أسبوعياً. '
              'الرسائل المقبولة تُحسب هنا، ${PointRules.approved} نقطة لكل واحدة '
              'حتى ${PointRules.approvedPerWeek}. أخفِ أي اسم لا يصلح قبل النشر.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (ranked.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('لم ينضم أحد لهذا الأسبوع بعد.')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('من الهاتف'), numeric: true),
                    DataColumn(label: Text('مقبولة'), numeric: true),
                    DataColumn(label: Text('الحفظ'), numeric: true),
                    DataColumn(label: Text('المجموع'), numeric: true),
                    DataColumn(label: Text('إخفاء')),
                  ],
                  rows: [
                    for (final (i, c) in ranked.take(30).indexed)
                      DataRow(
                        color: _hidden.contains(c.uid)
                            ? WidgetStatePropertyAll(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              )
                            : null,
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(c.name)),
                          DataCell(Text('${c.device}')),
                          DataCell(Text('${c.approved}')),
                          DataCell(Text('${c.memo}')),
                          DataCell(Text('${c.score}')),
                          DataCell(
                            Checkbox(
                              value: _hidden.contains(c.uid),
                              onChanged: (hide) => setState(() {
                                if (hide ?? false) {
                                  _hidden.add(c.uid);
                                } else {
                                  _hidden.remove(c.uid);
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: ranked.isEmpty || _publishing ? null : _publish,
                icon: const Icon(Icons.publish_rounded),
                label: const Text('نشر اللوحة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
