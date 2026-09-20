import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/services/daily_tip_service.dart';

/// One row in the delivery pool — either a dailyMessages doc ("رسائل
/// اليوم", added by staff) or an approved communityMessages doc
/// ("مشاركات المجتمع", submitted by app users and approved from the
/// pending queue). Unified for display — see DailyTipService, which draws
/// from exactly this same pool.
class _PoolEntry {
  _PoolEntry({
    required this.ref,
    required this.text,
    required this.hadithNumber,
    required this.timesShown,
    required this.likeCount,
    required this.source,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String text;
  final int hadithNumber;
  final int timesShown;
  final int likeCount;
  final String source; // 'dailyMessages' | 'communityMessages'
}

enum _SourceFilter { all, daily, community }

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Controls both halves of daily delivery.
///
/// **How many** messages a day carries lives in
/// `settings/dailyMessageConfig.messagesPerDay` and is set from the card at
/// the top of this page. Every device reads it (DailyTipService) and draws
/// that many messages once per local day, keeping them frozen for the rest
/// of the day.
///
/// **Which** messages, optionally: `settings/dailyMessageSchedule`'s `days`
/// map, keyed by yyyy-MM-dd, holds a list of up to `messagesPerDay` pins per
/// date. Pinning fewer than the full count is normal — the unpinned slots
/// are filled randomly per device. Scheduling today's date takes effect
/// immediately, a future date just waits its turn, and an expired date
/// simply stops matching "today", so there is nothing to revert.
class DailyMessageSchedulePage extends StatefulWidget {
  const DailyMessageSchedulePage({super.key});

  @override
  State<DailyMessageSchedulePage> createState() =>
      _DailyMessageSchedulePageState();
}

class _DailyMessageSchedulePageState extends State<DailyMessageSchedulePage> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _search = '';
  _SourceFilter _filter = _SourceFilter.all;

  late Future<List<_PoolEntry>> _poolFuture = _loadPool();
  List<_PoolEntry>? _entries;

  final _deletingPaths = <String>{};
  final _schedulingPaths = <String>{};

  DocumentReference<Map<String, dynamic>> get _scheduleRef =>
      _db.collection('settings').doc('dailyMessageSchedule');

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('settings').doc('dailyMessageConfig');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_PoolEntry>> _loadPool() async {
    final entries = <_PoolEntry>[];

    final dm = await _db.collection('dailyMessages').get();
    for (final doc in dm.docs) {
      final data = doc.data();
      entries.add(
        _PoolEntry(
          ref: doc.reference,
          text: (data['arabic'] as String?)?.trim() ?? '',
          hadithNumber: data['hadithNumber'] as int? ?? 0,
          timesShown: (data['timesShown'] as num?)?.toInt() ?? 0,
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
          source: 'dailyMessages',
        ),
      );
    }

    final cm = await _db
        .collection('communityMessages')
        .where('status', isEqualTo: 'approved')
        .get();
    for (final doc in cm.docs) {
      final data = doc.data();
      entries.add(
        _PoolEntry(
          ref: doc.reference,
          text: (data['message'] as String?)?.trim() ?? '',
          hadithNumber: data['hadithNumber'] as int? ?? 0,
          timesShown: (data['timesShown'] as num?)?.toInt() ?? 0,
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
          source: 'communityMessages',
        ),
      );
    }

    entries.sort((a, b) => a.hadithNumber.compareTo(b.hadithNumber));
    return entries;
  }

  void _reload() {
    setState(() {
      _entries = null;
      _poolFuture = _loadPool();
    });
  }

  /// This whole page is admin-only (dashboard_app.dart never gives a
  /// moderator this tab), so there's no extra role check needed here —
  /// unlike notificationMessages' per-item delete, which lives on a page
  /// both roles can open.
  Future<void> _delete(_PoolEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة نهائياً؟'),
        content: Text(
          entry.text.length > 120 ? '${entry.text.substring(0, 120)}…' : entry.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingPaths.add(entry.ref.path));
    try {
      await entry.ref.delete();
      if (!mounted) return;
      setState(() {
        _entries?.removeWhere((e) => e.ref.path == entry.ref.path);
        _deletingPaths.remove(entry.ref.path);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingPaths.remove(entry.ref.path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحذف: $e')),
      );
    }
  }

  /// The configured count, or 1 when the doc hasn't been written yet — the
  /// same default DailyTipService falls back to.
  Future<int> _messagesPerDay() async {
    final snap = await _configRef.get();
    final value = (snap.data()?['messagesPerDay'] as num?)?.toInt();
    if (value == null || value < 1) return 1;
    return value > DailyTipService.maxMessagesPerDay
        ? DailyTipService.maxMessagesPerDay
        : value;
  }

  Future<void> _setMessagesPerDay(int value) async {
    try {
      await _configRef.set({
        'messagesPerDay': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حفظ العدد: $e')),
      );
    }
  }

  Future<void> _scheduleMessage(_PoolEntry entry) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'اختر يوم عرض هذه الرسالة',
      confirmText: 'تحديد',
      cancelText: 'إلغاء',
    );
    if (picked == null || !mounted) return;
    final dateKey = _dateKey(picked);

    // Validate against what's already pinned before touching anything, so a
    // full day or a duplicate is explained rather than silently dropped by
    // the transaction below.
    final perDay = await _messagesPerDay();
    final scheduleSnap = await _scheduleRef.get();
    final days = scheduleSnap.data()?['days'] as Map<String, dynamic>?;
    final existing = DailyTipService.normaliseScheduledDay(days?[dateKey]);
    if (!mounted) return;

    if (existing.any((e) => e['messageId'] == entry.ref.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هذه الرسالة محددة بالفعل ليوم $dateKey')),
      );
      return;
    }

    if (existing.length >= perDay) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('يوم $dateKey مكتمل'),
          content: Text(
            'محدَّد لهذا اليوم ${existing.length} من $perDay رسائل. '
            'أزل إحدى الرسائل المحددة، أو ارفع "عدد رسائل اليوم" من أعلى '
            'الصفحة، ثم أعد المحاولة.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _schedulingPaths.add(entry.ref.path));
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_scheduleRef);
        final liveDays = snap.data()?['days'] as Map<String, dynamic>?;
        final current = DailyTipService.normaliseScheduledDay(
          liveDays?[dateKey],
        );
        if (current.any((e) => e['messageId'] == entry.ref.id)) return;

        current.add({
          'sourceCollection': entry.source,
          'messageId': entry.ref.id,
          'text': entry.text,
          'hadithNumber': entry.hadithNumber,
          // Not serverTimestamp(): Firestore rejects the sentinel inside an
          // array value, and the pin order is what actually matters here.
          'setAt': Timestamp.now(),
        });

        tx.set(_scheduleRef, {
          'days': {dateKey: current},
        }, SetOptions(merge: true));
      });
      if (!mounted) return;
      final slot = existing.length + 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dateKey == _dateKey(today)
                ? 'تمت إضافتها لرسائل اليوم ($slot من $perDay) — ستظهر للمستخدمين الآن'
                : 'تمت إضافتها ليوم $dateKey ($slot من $perDay)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _schedulingPaths.remove(entry.ref.path));
    }
  }

  /// Drops one pin from a day, leaving the rest in place; a day left with no
  /// pins loses its key entirely so it goes back to a fully random draw.
  Future<void> _removeScheduled(String dateKey, String messageId) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_scheduleRef);
        final days = snap.data()?['days'] as Map<String, dynamic>?;
        final current = DailyTipService.normaliseScheduledDay(days?[dateKey])
          ..removeWhere((e) => e['messageId'] == messageId);

        if (current.isEmpty) {
          tx.update(_scheduleRef, {'days.$dateKey': FieldValue.delete()});
        } else {
          tx.set(_scheduleRef, {
            'days': {dateKey: current},
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إزالة الجدولة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScheduleSummary(
          onRemove: _removeScheduled,
          onCountChanged: _setMessagesPerDay,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'ابحث برقم الحديث أو جزء من النص...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث القائمة',
                onPressed: _reload,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<_SourceFilter>(
              segments: const [
                ButtonSegment(value: _SourceFilter.all, label: Text('الكل')),
                ButtonSegment(
                  value: _SourceFilter.daily,
                  label: Text('رسائل اليوم'),
                ),
                ButtonSegment(
                  value: _SourceFilter.community,
                  label: Text('مشاركات المجتمع'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_PoolEntry>>(
            future: _poolFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('تعذّر التحميل: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              _entries ??= snapshot.data!;
              final entries = _entries!;

              final asNumber = int.tryParse(_search);
              final visible = entries.where((e) {
                final matchesFilter = _filter == _SourceFilter.all ||
                    (_filter == _SourceFilter.daily &&
                        e.source == 'dailyMessages') ||
                    (_filter == _SourceFilter.community &&
                        e.source == 'communityMessages');
                final matchesSearch = _search.isEmpty ||
                    (asNumber != null && e.hadithNumber == asNumber) ||
                    e.text.contains(_search);
                return matchesFilter && matchesSearch;
              }).toList();

              if (visible.isEmpty) {
                return const Center(child: Text('لا توجد نتائج مطابقة'));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final entry = visible[i];
                  return _PoolRow(
                    key: ValueKey(entry.ref.path),
                    entry: entry,
                    deleting: _deletingPaths.contains(entry.ref.path),
                    scheduling: _schedulingPaths.contains(entry.ref.path),
                    onDelete: () => _delete(entry),
                    onSchedule: () => _scheduleMessage(entry),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The card above the pool list: how many messages a day carries, plus every
/// upcoming date that has pins, grouped by date so it reads as "this day has
/// 2 of 3 chosen".
class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({
    required this.onRemove,
    required this.onCountChanged,
  });

  final void Function(String dateKey, String messageId) onRemove;
  final ValueChanged<int> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final today = _dateKey(DateTime.now());
    final db = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                db.collection('settings').doc('dailyMessageConfig').snapshots(),
            builder: (context, configSnapshot) {
              final rawCount =
                  (configSnapshot.data?.data()?['messagesPerDay'] as num?)
                      ?.toInt();
              final perDay = (rawCount == null || rawCount < 1)
                  ? 1
                  : (rawCount > DailyTipService.maxMessagesPerDay
                      ? DailyTipService.maxMessagesPerDay
                      : rawCount);

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('settings')
                    .doc('dailyMessageSchedule')
                    .snapshots(),
                builder: (context, snapshot) {
                  final days =
                      snapshot.data?.data()?['days'] as Map<String, dynamic>?;
                  final upcoming = <MapEntry<String, dynamic>>[
                    if (days != null)
                      for (final entry in days.entries)
                        if (entry.key.compareTo(today) >= 0) entry,
                  ]..sort((a, b) => a.key.compareTo(b.key));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'رسائل اليوم المجدولة',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Text('عدد رسائل اليوم:'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: perDay,
                            onChanged: (v) {
                              if (v != null) onCountChanged(v);
                            },
                            items: [
                              for (var i = 1;
                                  i <= DailyTipService.maxMessagesPerDay;
                                  i++)
                                DropdownMenuItem(value: i, child: Text('$i')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يعرض التطبيق $perDay ${perDay == 1 ? 'رسالة' : 'رسائل'} لكل يوم، '
                        'تُختار مرة واحدة في اليوم وتبقى ثابتة حتى اليوم التالي. '
                        'اضغط أيقونة "تحديد ليوم" على أي رسالة أدناه لتثبيتها في يوم معيّن — '
                        'يمكنك تثبيت حتى $perDay ${perDay == 1 ? 'رسالة' : 'رسائل'} لليوم الواحد، '
                        'والخانات التي تتركها فارغة تُملأ برسائل عشوائية. '
                        'رفع العدد أثناء اليوم يضيف رسائل فوراً، وخفضه يبدأ من اليوم التالي '
                        'حتى لا تُسحب رسالة قرأها المستخدم بالفعل.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (upcoming.isEmpty)
                        const Text('لا توجد رسائل مجدولة قادمة')
                      else
                        // A year of pinned days would otherwise push the
                        // pool list itself off the page — this card keeps a
                        // fixed share of the height and scrolls inside it.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final day in upcoming)
                                  _ScheduledDay(
                                    dateKey: day.key,
                                    isToday: day.key == today,
                                    perDay: perDay,
                                    pins:
                                        DailyTipService.normaliseScheduledDay(
                                      day.value,
                                    ),
                                    onRemove: (messageId) =>
                                        onRemove(day.key, messageId),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Every pin on one date, with an "n of N" header — so an admin can see at a
/// glance which days are fully chosen and which still have random slots.
class _ScheduledDay extends StatelessWidget {
  const _ScheduledDay({
    required this.dateKey,
    required this.isToday,
    required this.perDay,
    required this.pins,
    required this.onRemove,
  });

  final String dateKey;
  final bool isToday;
  final int perDay;
  final List<Map<String, dynamic>> pins;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    // A day can hold more pins than the current count if the count was
    // lowered after they were set — the extras are simply ignored by the
    // app, so say so rather than letting an admin wonder.
    final overflowing = pins.length > perDay;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isToday ? 'اليوم ($dateKey)' : dateKey,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${pins.length} من $perDay محددة'),
                backgroundColor: isToday
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.blueGrey.withValues(alpha: 0.10),
              ),
              if (overflowing) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      'الزائد عن $perDay لن يُعرض — احذف رسالة أو ارفع العدد',
                  child: Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange[800]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < pins.length; i++)
                _ScheduledChip(
                  slot: i + 1,
                  ignored: i >= perDay,
                  text: pins[i]['text'] as String? ?? '',
                  onRemove: () =>
                      onRemove(pins[i]['messageId'] as String? ?? ''),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduledChip extends StatelessWidget {
  const _ScheduledChip({
    required this.slot,
    required this.ignored,
    required this.text,
    required this.onRemove,
  });

  final int slot;
  final bool ignored;
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final snippet = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    return Tooltip(
      message: text,
      child: InputChip(
        label: Text('$slot — $snippet'),
        backgroundColor: ignored
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.blueGrey.withValues(alpha: 0.10),
        onDeleted: onRemove,
        deleteIconColor: Colors.red[700],
      ),
    );
  }
}

class _PoolRow extends StatelessWidget {
  const _PoolRow({
    super.key,
    required this.entry,
    required this.deleting,
    required this.scheduling,
    required this.onDelete,
    required this.onSchedule,
  });

  final _PoolEntry entry;
  final bool deleting;
  final bool scheduling;
  final VoidCallback onDelete;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final everShown = entry.timesShown > 0;
    final isCommunity = entry.source == 'communityMessages';

    return Card(
      key: ValueKey('card-${entry.ref.path}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        'الحديث ${entry.hadithNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isCommunity ? Colors.blue : Colors.brown)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCommunity ? 'من المجتمع' : 'من رسائل اليوم',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isCommunity ? Colors.blue[800] : Colors.brown[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(everShown ? 'عُرضت ${entry.timesShown} مرة' : 'لم تُعرض بعد'),
              backgroundColor: everShown
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 4),
            Chip(
              label: Text(
                '♥ ${entry.likeCount}',
                style: TextStyle(
                  color: entry.likeCount > 0 ? Colors.red[700] : Colors.grey[700],
                ),
              ),
              backgroundColor: entry.likeCount > 0
                  ? Colors.red.withValues(alpha: 0.10)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 4),
            scheduling
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.event_available_rounded, color: Colors.green),
                    tooltip: 'تحديد ليوم معيّن',
                    onPressed: onSchedule,
                  ),
            deleting
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    tooltip: 'حذف نهائياً',
                    onPressed: onDelete,
                  ),
          ],
        ),
      ),
    );
  }
}
