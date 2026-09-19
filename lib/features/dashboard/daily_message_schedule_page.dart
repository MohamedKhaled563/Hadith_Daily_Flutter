import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

/// Lets an admin pin a specific message to a specific calendar date — see
/// `settings/dailyMessageSchedule`'s `days` map, keyed by that same
/// yyyy-MM-dd string. DailyTipService checks that map for *today's* key
/// before falling back to its normal random pick, so scheduling today's
/// date takes effect immediately for every device, and a future date just
/// waits its turn — no explicit "manual vs random" mode needed any more,
/// and nothing to revert afterwards since an expired date simply stops
/// matching "today".
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
    final scheduleRef = _db.collection('settings').doc('dailyMessageSchedule');

    // Warn before silently overwriting whatever was already pinned to that
    // date, rather than letting an admin clobber a colleague's choice by
    // accident.
    final existingSnap = await scheduleRef.get();
    final existingDays = existingSnap.data()?['days'] as Map<String, dynamic>?;
    final existing = existingDays?[dateKey] as Map<String, dynamic>?;
    if (existing != null) {
      if (!mounted) return;
      final existingText = existing['text'] as String? ?? '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('استبدال رسالة $dateKey؟'),
          content: Text(
            existingText.length > 140
                ? '${existingText.substring(0, 140)}…'
                : existingText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('استبدال'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _schedulingPaths.add(entry.ref.path));
    try {
      await scheduleRef.set({
        'days': {
          dateKey: {
            'sourceCollection': entry.source,
            'messageId': entry.ref.id,
            'text': entry.text,
            'hadithNumber': entry.hadithNumber,
            'setAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dateKey == _dateKey(today)
                ? 'تم تحديدها كرسالة اليوم — ستظهر للمستخدمين الآن'
                : 'تم تحديدها لرسالة يوم $dateKey',
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

  Future<void> _removeScheduled(String dateKey) async {
    try {
      await _db.collection('settings').doc('dailyMessageSchedule').update({
        'days.$dateKey': FieldValue.delete(),
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
        _ScheduleSummary(onRemove: _removeScheduled),
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

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.onRemove});

  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final today = _dateKey(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('dailyMessageSchedule')
                .snapshots(),
            builder: (context, snapshot) {
              final days = snapshot.data?.data()?['days'] as Map<String, dynamic>?;
              final upcoming = <MapEntry<String, dynamic>>[
                if (days != null)
                  for (final entry in days.entries)
                    if (entry.key.compareTo(today) >= 0) entry,
              ]..sort((a, b) => a.key.compareTo(b.key));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_available_rounded),
                      SizedBox(width: 8),
                      Text(
                        'رسائل اليوم المجدولة',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اضغط أيقونة "تحديد ليوم" على أي رسالة أدناه لتظهر في يوم معيّن — إن كان اليوم هو نفسه فستظهر للمستخدمين فوراً؛ وإن كان في المستقبل فستظهر تلقائياً عند حلول ذلك اليوم. الأيام التي لا تحمل رسالة محددة تُعرض فيها رسالة عشوائية كالمعتاد.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    const Text('لا توجد رسائل مجدولة قادمة')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in upcoming)
                          _ScheduledChip(
                            dateKey: entry.key,
                            isToday: entry.key == today,
                            text: (entry.value as Map<String, dynamic>)['text']
                                    as String? ??
                                '',
                            onRemove: () => onRemove(entry.key),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduledChip extends StatelessWidget {
  const _ScheduledChip({
    required this.dateKey,
    required this.isToday,
    required this.text,
    required this.onRemove,
  });

  final String dateKey;
  final bool isToday;
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final snippet = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    return Tooltip(
      message: text,
      child: InputChip(
        label: Text('${isToday ? 'اليوم' : dateKey} — $snippet'),
        backgroundColor: isToday
            ? Colors.green.withValues(alpha: 0.15)
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
