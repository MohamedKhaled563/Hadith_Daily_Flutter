import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One row in the delivery pool — either a dailyMessages doc or an approved
/// communityMessages doc, unified for display. See DailyTipService, which
/// draws from exactly this same pool.
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
  final int order;
  final int timesShown;
  final Timestamp? lastShownAt;
  final String source; // 'dailyMessages' | 'communityMessages'
}

class RotationOrderPage extends StatefulWidget {
  const RotationOrderPage({super.key});

  @override
  State<RotationOrderPage> createState() => _RotationOrderPageState();
}

class _RotationOrderPageState extends State<RotationOrderPage> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setMode(String mode) {
    return _db.collection('settings').doc('deliveryMode').set({'mode': mode});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModeToggle(onChanged: _setMode),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
        Expanded(child: _PoolList(search: _search)),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.onChanged});

  final ValueChanged<String> onChanged;

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
                        ? 'يسير كل جهاز حسب "الترتيب" أدناه'
                        : 'يختار كل جهاز عشوائياً مما لم يُعرض له بعد',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _PoolList extends StatelessWidget {
  const _PoolList({required this.search});

  final String search;

  Future<List<_PoolEntry>> _load() async {
    final db = FirebaseFirestore.instance;
    final entries = <_PoolEntry>[];

    final dm = await db.collection('dailyMessages').get();
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

    final cm = await db
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_PoolEntry>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذّر التحميل: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var entries = snapshot.data!;
        if (search.isNotEmpty) {
          final asNumber = int.tryParse(search);
          entries = entries
              .where(
                (e) =>
                    (asNumber != null && e.hadithNumber == asNumber) ||
                    e.text.contains(search),
              )
              .toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: entries.length,
          itemBuilder: (context, index) => _PoolRow(entry: entries[index]),
        );
      },
    );
  }
}

class _PoolRow extends StatefulWidget {
  const _PoolRow({required this.entry});

  final _PoolEntry entry;

  @override
  State<_PoolRow> createState() => _PoolRowState();
}

class _PoolRowState extends State<_PoolRow> {
  late final TextEditingController _orderController;

  @override
  void initState() {
    super.initState();
    _orderController = TextEditingController(text: '${widget.entry.order}');
  }

  @override
  void dispose() {
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _saveOrder() async {
    final value = int.tryParse(_orderController.text.trim());
    if (value == null) return;
    await widget.entry.ref.update({'order': value});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الترتيب')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final everShown = e.timesShown > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: TextField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الترتيب',
                  isDense: true,
                ),
                onSubmitted: (_) => _saveOrder(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save_rounded, size: 18),
              tooltip: 'حفظ الترتيب',
              onPressed: _saveOrder,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'الحديث ${e.hadithNumber}  ·  ${e.source == 'communityMessages' ? 'من المجتمع' : 'من رسائل اليوم'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(everShown ? 'عُرضت ${e.timesShown} مرة' : 'لم تُعرض بعد'),
              backgroundColor: everShown
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}
