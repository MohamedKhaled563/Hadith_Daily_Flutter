import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Moderator/admin management of the small curated pool
/// NotificationScheduler draws from on-device — see firestore.rules
/// (phase 12). Same random/manual mode toggle as the daily-tip pool
/// (RotationOrderPage), stored separately at settings/notificationMode so
/// the two rotations don't interfere with each other.
///
/// Order is only meaningful in manual mode (random mode ignores it
/// entirely), so it's set by dragging rows rather than typing a number, and
/// a full drag session is committed with one "حفظ الترتيب" batch write —
/// there's nothing else per-row left to "save" once the number field is
/// gone. Loaded once into local state (like RotationOrderPage) rather than
/// a live stream, since a mid-drag snapshot update would fight the drag.
///
/// Phase 16 narrowed notificationMessages update/delete in firestore.rules
/// to isAdmin() — a moderator may only create here now, same as
/// dailyMessages via BulkAddPage. [isAdmin] gates every affordance that
/// would otherwise hit that wall (reordering, per-row edit/toggle/delete);
/// a moderator still sees the list and can add new messages.
class NotificationMessagesPage extends StatefulWidget {
  const NotificationMessagesPage({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<NotificationMessagesPage> createState() => _NotificationMessagesPageState();
}

class _MsgEntry {
  _MsgEntry({
    required this.ref,
    required this.text,
    required this.order,
    required this.active,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  String text;
  int order;
  bool active;
}

/// The cap firestore.rules enforces on `notificationMessages.text` (create
/// and update alike). Mirrored here so an over-long message is caught with a
/// message the moderator can act on, instead of failing the write with
/// PERMISSION_DENIED as an unhandled async error and no UI feedback at all.
const kNotificationTextMaxLength = 300;

/// Why [text] cannot be saved, or null if it can. Pure, so the rule mirror
/// is testable without a Firestore round trip.
String? validateNotificationText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'النص فارغ';
  if (trimmed.length > kNotificationTextMaxLength) {
    return 'النص طويل جداً (${trimmed.length}/$kNotificationTextMaxLength حرف)';
  }
  return null;
}

class _NotificationMessagesPageState extends State<NotificationMessagesPage> {
  final _db = FirebaseFirestore.instance;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
  late Future<List<_MsgEntry>> _messagesFuture = _loadMessages();
  List<_MsgEntry>? _messages;
  bool _orderDirty = false;
  bool _savingOrder = false;

  Future<List<_MsgEntry>> _loadMessages() async {
    final snapshot = await _db
        .collection('notificationMessages')
        .orderBy('order')
        .get();
    return snapshot.docs
        .map(
          (doc) => _MsgEntry(
            ref: doc.reference,
            text: doc.data()['text'] as String? ?? '',
            order: (doc.data()['order'] as num?)?.toInt() ?? 0,
            active: doc.data()['active'] as bool? ?? true,
          ),
        )
        .toList();
  }

  void _reload() {
    setState(() {
      _orderDirty = false;
      _messages = null;
      _messagesFuture = _loadMessages();
    });
  }

  Future<void> _setMode(String mode) async {
    try {
      await _db
          .collection('settings')
          .doc('notificationMode')
          .set({'mode': mode});
    } catch (error) {
      _snack('تعذّر تغيير طريقة الاختيار: $error');
    }
  }

  Future<void> _addMessage() async {
    final controller = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('رسالة تنبيه جديدة'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            maxLength: kNotificationTextMaxLength,
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
    } finally {
      controller.dispose();
    }
    if (text == null) return;

    final problem = validateNotificationText(text);
    if (problem != null) {
      _snack(problem);
      return;
    }

    // `_messages?.length ?? 0` handed every message added before the list
    // finished loading the same order 0.
    final loaded = _messages;
    final order = loaded == null
        ? 0
        : loaded.fold<int>(-1, (max, m) => m.order > max ? m.order : max) + 1;
    try {
      await _db.collection('notificationMessages').add({
        'text': text.trim(),
        'order': order,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _snack('تعذّر إضافة الرسالة: $error');
      return;
    }
    _reload();
  }

  void _onReorder(int oldIndex, int newIndex) {
    final messages = _messages;
    if (messages == null) return;
    setState(() {
      final item = messages.removeAt(oldIndex);
      messages.insert(newIndex, item);
      for (var i = 0; i < messages.length; i++) {
        messages[i].order = i;
      }
      _orderDirty = true;
    });
  }

  Future<void> _saveOrder() async {
    final messages = _messages;
    if (messages == null || _savingOrder) return;
    setState(() => _savingOrder = true);
    try {
      final batch = _db.batch();
      for (final entry in messages) {
        batch.update(entry.ref, {'order': entry.order});
      }
      await batch.commit();
      if (mounted) {
        setState(() {
          _orderDirty = false;
          _savingOrder = false;
        });
        _snack('تم حفظ الترتيب');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savingOrder = false);
        _snack('تعذّر حفظ الترتيب: $error');
      }
    }
  }

  Future<void> _saveText(_MsgEntry entry, String text) async {
    final problem = validateNotificationText(text);
    if (problem != null) {
      _snack(problem);
      return;
    }
    try {
      await entry.ref.update({'text': text.trim()});
    } catch (error) {
      _snack('تعذّر الحفظ: $error');
      return;
    }
    entry.text = text.trim();
    _snack('تم الحفظ');
  }

  Future<void> _toggleActive(_MsgEntry entry, bool value) async {
    try {
      await entry.ref.update({'active': value});
    } catch (error) {
      _snack('تعذّر تغيير الحالة: $error');
      return;
    }
    if (mounted) setState(() => entry.active = value);
  }

  Future<void> _delete(_MsgEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف رسالة التنبيه؟'),
        content: Text(entry.text),
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
    if (confirmed != true) return;
    try {
      await entry.ref.delete();
    } catch (error) {
      _snack('تعذّر الحذف: $error');
      return;
    }
    if (mounted) {
      setState(() => _messages?.remove(entry));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _ModeToggle(onChanged: _setMode, onRefresh: _reload, isAdmin: widget.isAdmin),
            Expanded(
              child: FutureBuilder<List<_MsgEntry>>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('تعذّر التحميل: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  _messages ??= snapshot.data!;
                  final messages = _messages!;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('لا توجد رسائل تنبيه بعد — أضف أول رسالة'),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('settings')
                        .doc('notificationMode')
                        .snapshots(),
                    builder: (context, modeSnap) {
                      final mode =
                          modeSnap.data?.data()?['mode'] as String? ?? 'random';
                      final draggable = widget.isAdmin && mode == 'manual';

                      return ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        buildDefaultDragHandles: false,
                        itemCount: messages.length,
                        onReorderItem: draggable
                            ? _onReorder
                            : (_, __) {},
                        itemBuilder: (context, index) => _MessageRow(
                          key: ValueKey(messages[index].ref.id),
                          entry: messages[index],
                          draggable: draggable,
                          canEdit: widget.isAdmin,
                          index: index,
                          onSaveText: (text) => _saveText(messages[index], text),
                          onToggleActive: (v) => _toggleActive(messages[index], v),
                          onDelete: () => _delete(messages[index]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_orderDirty && widget.isAdmin)
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
  const _ModeToggle({
    required this.onChanged,
    required this.onRefresh,
    required this.isAdmin,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;
  final bool isAdmin;

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
                        ? (isAdmin
                            ? 'اسحب الرسائل لترتيبها، ثم اضغط "حفظ الترتيب" — نفس الرسالة لكل الأجهزة'
                            : 'الترتيب والتعديل والحذف متاحة للمدير فقط — يمكنك إضافة رسائل جديدة')
                        : 'يختار كل جهاز عشوائياً من الرسائل المفعّلة — الترتيب لا يُستخدم هنا',
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

class _MessageRow extends StatefulWidget {
  const _MessageRow({
    super.key,
    required this.entry,
    required this.draggable,
    required this.canEdit,
    required this.index,
    required this.onSaveText,
    required this.onToggleActive,
    required this.onDelete,
  });

  final _MsgEntry entry;
  final bool draggable;

  /// Phase 16: only an admin may update/delete an existing
  /// notificationMessages doc — a moderator sees the list read-only besides
  /// adding new ones (NotificationMessagesPage._addMessage, unaffected).
  final bool canEdit;
  final int index;
  final ValueChanged<String> onSaveText;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() => widget.onSaveText(_textController.text.trim());

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('card-${widget.entry.ref.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.draggable) ...[
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                enabled: widget.canEdit,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: widget.entry.active,
                  onChanged: widget.canEdit ? widget.onToggleActive : null,
                ),
                // Clamped: a supplementary status label next to the switch,
                // not primary content — left unscaled so a large accessibility
                // text-size setting can't widen this trailing cluster enough
                // to squeeze the message field into overflow.
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: Text(
                    widget.entry.active ? 'مفعّلة' : 'معطّلة',
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
              tooltip: 'حفظ النص',
              onPressed: widget.canEdit ? _save : null,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              tooltip: 'حذف',
              onPressed: widget.canEdit ? widget.onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}
