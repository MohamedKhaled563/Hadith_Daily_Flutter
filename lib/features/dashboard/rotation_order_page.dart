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
    required this.order,
    required this.timesShown,
    required this.lastShownAt,
    required this.source,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String text;
  final int hadithNumber;
  int order;
  final int timesShown;
  final Timestamp? lastShownAt;
  final String source; // 'dailyMessages' | 'communityMessages'
}

enum _SourceFilter { all, daily, community }

/// Order is only meaningful in manual delivery mode, and only coherent
/// when dragging the *whole* mixed pool — reordering a filtered/searched
/// subset would leave the hidden items' order values interleaved
/// incorrectly. So dragging (and the single "حفظ الترتيب" batch save,
/// same pattern as NotificationMessagesPage) is only enabled with no
/// search text and the "الكل" filter selected; a specific-source filter or
/// active search still lets you browse and see each row's order, just not
/// drag it.
class RotationOrderPage extends StatefulWidget {
  const RotationOrderPage({super.key});

  @override
  State<RotationOrderPage> createState() => _RotationOrderPageState();
}

class _RotationOrderPageState extends State<RotationOrderPage> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _search = '';
  _SourceFilter _filter = _SourceFilter.all;

  late Future<List<_PoolEntry>> _poolFuture = _loadPool();
  List<_PoolEntry>? _entries;
  bool _orderDirty = false;
  bool _savingOrder = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setMode(String mode) {
    return _db.collection('settings').doc('deliveryMode').set({'mode': mode});
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
          order: (data['order'] as num?)?.toInt() ?? 0,
          timesShown: (data['timesShown'] as num?)?.toInt() ?? 0,
          lastShownAt: data['lastShownAt'] as Timestamp?,
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
          order: (data['order'] as num?)?.toInt() ?? (1 << 30),
          timesShown: (data['timesShown'] as num?)?.toInt() ?? 0,
          lastShownAt: data['lastShownAt'] as Timestamp?,
          source: 'communityMessages',
        ),
      );
    }

    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
  }

  void _reload() {
    setState(() {
      _orderDirty = false;
      _entries = null;
      _poolFuture = _loadPool();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    final entries = _entries;
    if (entries == null) return;
    setState(() {
      final item = entries.removeAt(oldIndex);
      entries.insert(newIndex, item);
      for (var i = 0; i < entries.length; i++) {
        entries[i].order = i;
      }
      _orderDirty = true;
    });
  }

  final _deletingPaths = <String>{};

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

  Future<void> _saveOrder() async {
    final entries = _entries;
    if (entries == null || _savingOrder) return;
    setState(() => _savingOrder = true);
    try {
      final batch = _db.batch();
      for (final entry in entries) {
        batch.update(entry.ref, {'order': entry.order});
      }
      await batch.commit();
      if (mounted) {
        setState(() {
          _orderDirty = false;
          _savingOrder = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الترتيب')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ الترتيب')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _ModeToggle(onChanged: _setMode, onRefresh: _reload),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('settings')
                        .doc('deliveryMode')
                        .snapshots(),
                    builder: (context, modeSnap) {
                      final mode =
                          modeSnap.data?.data()?['mode'] as String? ?? 'random';

                      // Indices into `entries` (the full, order-authoritative
                      // list) for the rows currently visible — dragging needs
                      // the real index, not the filtered position.
                      final asNumber = int.tryParse(_search);
                      final visibleIndices = <int>[
                        for (var i = 0; i < entries.length; i++)
                          if ((_filter == _SourceFilter.all ||
                                  (_filter == _SourceFilter.daily &&
                                      entries[i].source == 'dailyMessages') ||
                                  (_filter == _SourceFilter.community &&
                                      entries[i].source ==
                                          'communityMessages')) &&
                              (_search.isEmpty ||
                                  (asNumber != null &&
                                      entries[i].hadithNumber == asNumber) ||
                                  entries[i].text.contains(_search)))
                            i,
                      ];

                      final draggable = mode == 'manual' &&
                          _filter == _SourceFilter.all &&
                          _search.isEmpty;

                      if (visibleIndices.isEmpty) {
                        return const Center(
                          child: Text('لا توجد نتائج مطابقة'),
                        );
                      }

                      return ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        buildDefaultDragHandles: false,
                        itemCount: visibleIndices.length,
                        onReorderItem: draggable
                            ? (oldVisible, newVisible) => _onReorder(
                                  visibleIndices[oldVisible],
                                  visibleIndices[newVisible],
                                )
                            : (_, __) {},
                        itemBuilder: (context, visibleIndex) {
                          final entry = entries[visibleIndices[visibleIndex]];
                          return _PoolRow(
                            key: ValueKey(entry.ref.path),
                            entry: entry,
                            draggable: draggable,
                            dragIndex: visibleIndex,
                            deleting: _deletingPaths.contains(entry.ref.path),
                            onDelete: () => _delete(entry),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_orderDirty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _savingOrder ? null : _saveOrder,
              backgroundColor: Colors.green,
              icon: _savingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('حفظ الترتيب'),
            ),
          ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.onChanged, required this.onRefresh});

  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('deliveryMode')
            .snapshots(),
        builder: (context, snapshot) {
          final mode = snapshot.data?.data()?['mode'] as String? ?? 'random';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              // Wrap, not Row: an admin's browser window can be any width,
              // and this row has real content on both ends — no single
              // element to just ellipsize when space runs out.
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.settings_suggest_rounded),
                      SizedBox(width: 8),
                      Text(
                        'طريقة اختيار رسالة اليوم:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'random', label: Text('عشوائي')),
                      ButtonSegment(value: 'manual', label: Text('يدوي')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => onChanged(s.first),
                  ),
                  Text(
                    mode == 'manual'
                        ? 'اسحب الرسائل لترتيبها (بدون فلتر أو بحث)، ثم اضغط "حفظ الترتيب"'
                        : 'يختار كل جهاز عشوائياً مما لم يُعرض له بعد',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'تحديث القائمة',
                    onPressed: onRefresh,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PoolRow extends StatelessWidget {
  const _PoolRow({
    super.key,
    required this.entry,
    required this.draggable,
    required this.dragIndex,
    required this.deleting,
    required this.onDelete,
  });

  final _PoolEntry entry;
  final bool draggable;
  final int dragIndex;
  final bool deleting;
  final VoidCallback onDelete;

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
            if (draggable) ...[
              ReorderableDragStartListener(
                index: dragIndex,
                child: const Icon(Icons.drag_handle_rounded),
              ),
              const SizedBox(width: 8),
            ],
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
                        'الحديث ${entry.hadithNumber}  ·  الترتيب ${entry.order}',
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
