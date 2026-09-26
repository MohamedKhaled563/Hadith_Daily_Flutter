import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Moderator/admin management of the small curated pool
/// NotificationScheduler draws from on-device — see firestore.rules
/// (phase 12).
///
/// There is no random/manual toggle here any more: which message goes out on
/// which day is curated on the «رسائل اليوم ومشاركات المجتمع» calendar, and
/// this pool only fills the reminder's body, so every device simply draws
/// from it at random (see pickMessageForDay). With no manual order to keep,
/// there is no drag-to-reorder either — `order` is still written on add, and
/// only sorts the list.
///
/// Phase 16 narrowed notificationMessages update/delete in firestore.rules
/// to isAdmin() — a moderator may only create here now, same as
/// dailyMessages via BulkAddPage. [isAdmin] gates every affordance that
/// would otherwise hit that wall (per-row edit/toggle/delete);
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
      _messages = null;
      _messagesFuture = _loadMessages();
    });
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
            _PoolHeader(onRefresh: _reload, isAdmin: widget.isAdmin),
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

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _MessageRow(
                      key: ValueKey(messages[index].ref.id),
                      entry: messages[index],
                      canEdit: widget.isAdmin,
                      onSaveText: (text) => _saveText(messages[index], text),
                      onToggleActive: (v) => _toggleActive(messages[index], v),
                      onDelete: () => _delete(messages[index]),
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

class _PoolHeader extends StatelessWidget {
  const _PoolHeader({required this.onRefresh, required this.isAdmin});

  final VoidCallback onRefresh;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAdmin
                      ? 'يختار كل جهاز عشوائياً من الرسائل المفعّلة لتنبيهَي الصباح والمساء'
                      : 'يختار كل جهاز عشوائياً من الرسائل المفعّلة — التعديل والحذف متاحان للمدير فقط، ويمكنك إضافة رسائل جديدة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث القائمة',
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatefulWidget {
  const _MessageRow({
    super.key,
    required this.entry,
    required this.canEdit,
    required this.onSaveText,
    required this.onToggleActive,
    required this.onDelete,
  });

  final _MsgEntry entry;

  /// Phase 16: only an admin may update/delete an existing
  /// notificationMessages doc — a moderator sees the list read-only besides
  /// adding new ones (NotificationMessagesPage._addMessage, unaffected).
  final bool canEdit;
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
