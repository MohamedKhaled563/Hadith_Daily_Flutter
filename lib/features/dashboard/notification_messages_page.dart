import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Moderator/admin management of the small curated pool
/// NotificationScheduler draws from on-device — see firestore.rules
/// (phase 12). Same random/manual mode toggle as the daily-tip pool
/// (RotationOrderPage), stored separately at settings/notificationMode so
/// the two rotations don't interfere with each other.
class NotificationMessagesPage extends StatefulWidget {
  const NotificationMessagesPage({super.key});

  @override
  State<NotificationMessagesPage> createState() => _NotificationMessagesPageState();
}

class _NotificationMessagesPageState extends State<NotificationMessagesPage> {
  final _db = FirebaseFirestore.instance;

  Future<void> _setMode(String mode) {
    return _db.collection('settings').doc('notificationMode').set({'mode': mode});
  }

  Future<void> _addMessage() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رسالة تنبيه جديدة'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'نص قصير يظهر في إشعار الجهاز',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    final countSnap = await _db.collection('notificationMessages').count().get();
    await _db.collection('notificationMessages').add({
      'text': text,
      'order': countSnap.count ?? 0,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _ModeToggle(onChanged: _setMode),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('notificationMessages')
                    .orderBy('order')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('تعذّر التحميل: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('لا توجد رسائل تنبيه بعد — أضف أول رسالة'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _MessageRow(
                      key: ValueKey(docs[index].id),
                      doc: docs[index],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton.extended(
            onPressed: _addMessage,
            icon: const Icon(Icons.add_rounded),
            label: const Text('رسالة جديدة'),
          ),
        ),
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
            .doc('notificationMode')
            .snapshots(),
        builder: (context, snapshot) {
          final mode = snapshot.data?.data()?['mode'] as String? ?? 'random';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.notifications_active_outlined),
                      SizedBox(width: 8),
                      Text(
                        'طريقة اختيار رسالة التنبيه:',
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
                        ? 'يسير كل جهاز حسب "الترتيب" أدناه، نفس الرسالة لكل الأجهزة'
                        : 'يختار كل جهاز عشوائياً من الرسائل المفعّلة — قد تختلف بين الأجهزة',
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

class _MessageRow extends StatefulWidget {
  const _MessageRow({super.key, required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  late final TextEditingController _textController;
  late final TextEditingController _orderController;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data();
    _textController = TextEditingController(text: data['text'] as String? ?? '');
    _orderController = TextEditingController(text: '${data['order'] ?? 0}');
  }

  @override
  void dispose() {
    _textController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    final order = int.tryParse(_orderController.text.trim());
    if (text.isEmpty || order == null) return;
    await widget.doc.reference.update({'text': text, 'order': order});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    }
  }

  Future<void> _toggleActive(bool value) {
    return widget.doc.reference.update({'active': value});
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف رسالة التنبيه؟'),
        content: Text(_textController.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.doc.data()['active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: TextField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب', isDense: true),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: active, onChanged: _toggleActive),
                // Clamped: a supplementary status label next to the switch,
                // not primary content — left unscaled so a large accessibility
                // text-size setting can't widen this trailing cluster enough
                // to squeeze the message field into overflow.
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: Text(
                    active ? 'مفعّلة' : 'معطّلة',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.save_rounded, size: 18),
              tooltip: 'حفظ',
              onPressed: _save,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              tooltip: 'حذف',
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }
}
