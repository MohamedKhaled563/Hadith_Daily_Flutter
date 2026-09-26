import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/services/notification_schedule.dart';

/// Moderator/admin management of the small curated pool
/// NotificationScheduler draws from on-device — see firestore.rules
/// (phase 12).
///
/// Works like the «رسائل اليوم ومشاركات المجتمع» calendar: a message can be
/// pinned to a specific day's morning or evening reminder
/// (`settings/notificationSchedule`, see notification_schedule.dart), and
/// every slot left unpinned is drawn at random from the active messages on
/// each device. There is no random/manual toggle and no ordering — the
/// calendar is the manual control.
///
/// Rows are deliberately not editable in place: a message is added, pinned,
/// switched on/off, or deleted. Fixing a typo is delete + add.
///
/// Phase 16 narrowed notificationMessages update/delete in firestore.rules
/// to isAdmin() — a moderator may only create here now, same as
/// dailyMessages via BulkAddPage. [isAdmin] gates every affordance that
/// would otherwise hit that wall (per-row toggle/delete); a moderator still
/// sees the list, can add new messages and can use the calendar, which
/// writes to settings/ (moderator-writable).
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
  final String text;
  final int order;
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

  late Future<List<_MsgEntry>> _messagesFuture = _loadMessages();
  List<_MsgEntry>? _messages;
  final _schedulingIds = <String>{};

  DocumentReference<Map<String, dynamic>> get _scheduleRef =>
      _db.collection('settings').doc('notificationSchedule');

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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

  /// Pick a day, then which of its two reminders this message fills. A slot
  /// that already holds another message is replaced — the dialog says which
  /// one, so nothing is overwritten by surprise.
  Future<void> _scheduleMessage(_MsgEntry entry) async {
    if (!entry.active) {
      _snack('فعّل الرسالة أولاً — الرسائل المعطّلة لا تُرسل حتى لو كانت محددة ليوم');
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'اختر يوم إرسال هذا التنبيه',
      confirmText: 'التالي',
      cancelText: 'إلغاء',
    );
    if (picked == null || !mounted) return;
    final dateKey = notificationDateKey(picked);

    final Map<String, dynamic>? day;
    try {
      final snap = await _scheduleRef.get();
      final days = snap.data()?['days'] as Map<String, dynamic>?;
      day = days?[dateKey] as Map<String, dynamic>?;
    } catch (error) {
      _snack('تعذّر قراءة الجدول: $error');
      return;
    }
    if (!mounted) return;

    final slot = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('أي تنبيه يوم $dateKey؟'),
        children: [
          for (final s in kNotificationSlots)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: _SlotOption(
                label: kNotificationSlotLabels[s]!,
                current: day?[s] as Map<String, dynamic>?,
                thisMessageId: entry.ref.id,
              ),
            ),
        ],
      ),
    );
    if (slot == null || !mounted) return;

    setState(() => _schedulingIds.add(entry.ref.id));
    try {
      await _scheduleRef.set({
        'days': {
          dateKey: {
            slot: {
              'messageId': entry.ref.id,
              'text': entry.text,
              'setAt': Timestamp.now(),
            },
          },
        },
      }, SetOptions(merge: true));
      _snack('تم تحديدها لـ${kNotificationSlotLabels[slot]} يوم $dateKey');
    } catch (error) {
      _snack('تعذّر الحفظ: $error');
    } finally {
      if (mounted) setState(() => _schedulingIds.remove(entry.ref.id));
    }
  }

  /// Clears one slot; a day left with neither slot loses its key entirely,
  /// so it goes back to a fully random draw.
  Future<void> _removeScheduled(String dateKey, String slot) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_scheduleRef);
        final days = snap.data()?['days'] as Map<String, dynamic>?;
        final day = Map<String, dynamic>.from(
          days?[dateKey] as Map<String, dynamic>? ?? const {},
        )..remove(slot);
        final stillPinned = kNotificationSlots.any(day.containsKey);
        tx.update(_scheduleRef, {
          stillPinned ? 'days.$dateKey.$slot' : 'days.$dateKey':
              FieldValue.delete(),
        });
      });
    } catch (error) {
      _snack('تعذّر إزالة الجدولة: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _ScheduleSummary(
              onRemove: _removeScheduled,
              onRefresh: _reload,
            ),
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
                    itemBuilder: (context, index) {
                      final entry = messages[index];
                      return _MessageRow(
                        key: ValueKey(entry.ref.id),
                        entry: entry,
                        canEdit: widget.isAdmin,
                        scheduling: _schedulingIds.contains(entry.ref.id),
                        onSchedule: () => _scheduleMessage(entry),
                        onToggleActive: (v) => _toggleActive(entry, v),
                        onDelete: () => _delete(entry),
                      );
                    },
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

/// One choice in the "which reminder?" dialog, naming what it would replace.
class _SlotOption extends StatelessWidget {
  const _SlotOption({
    required this.label,
    required this.current,
    required this.thisMessageId,
  });

  final String label;
  final Map<String, dynamic>? current;
  final String thisMessageId;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final String note;
    if (current == null) {
      note = 'فارغ — يُختار عشوائياً الآن';
    } else if (current['messageId'] == thisMessageId) {
      note = 'هذه الرسالة محددة له بالفعل';
    } else {
      final text = current['text'] as String? ?? '';
      final snippet = text.length > 50 ? '${text.substring(0, 50)}…' : text;
      note = 'سيحل محل: $snippet';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(note, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// The card above the list: every upcoming date that has a pinned reminder,
/// with each slot removable.
class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.onRemove, required this.onRefresh});

  final void Function(String dateKey, String slot) onRemove;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final today = notificationDateKey(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('notificationSchedule')
                .snapshots(),
            builder: (context, snapshot) {
              final days =
                  snapshot.data?.data()?['days'] as Map<String, dynamic>?;
              final upcoming = <MapEntry<String, dynamic>>[
                if (days != null)
                  for (final entry in days.entries)
                    if (entry.key.compareTo(today) >= 0 && entry.value is Map)
                      entry,
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
                          'التنبيهات المجدولة',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'تحديث القائمة',
                        onPressed: onRefresh,
                      ),
                    ],
                  ),
                  Text(
                    'لكل يوم تنبيهان: رسالة الصباح وتأمل المساء. اضغط أيقونة التقويم '
                    'على أي رسالة أدناه لتحديدها ليوم معيّن، والتنبيه الذي تتركه فارغاً '
                    'يُختار عشوائياً من الرسائل المفعّلة. يصل التحديد لأجهزة المستخدمين '
                    'عند فتحهم التطبيق.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    const Text('لا توجد تنبيهات مجدولة قادمة')
                  else
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
                                slots: day.value as Map<String, dynamic>,
                                onRemove: (slot) => onRemove(day.key, slot),
                              ),
                          ],
                        ),
                      ),
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

class _ScheduledDay extends StatelessWidget {
  const _ScheduledDay({
    required this.dateKey,
    required this.isToday,
    required this.slots,
    required this.onRemove,
  });

  final String dateKey;
  final bool isToday;
  final Map<String, dynamic> slots;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday ? 'اليوم ($dateKey)' : dateKey,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in kNotificationSlots)
                if (slots[slot] is Map)
                  _ScheduledChip(
                    label: kNotificationSlotLabels[slot]!,
                    text: (slots[slot] as Map)['text'] as String? ?? '',
                    onRemove: () => onRemove(slot),
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
    required this.label,
    required this.text,
    required this.onRemove,
  });

  final String label;
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final snippet = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    return Tooltip(
      message: text,
      child: InputChip(
        label: Text('$label — $snippet'),
        backgroundColor: Colors.blueGrey.withValues(alpha: 0.10),
        onDeleted: onRemove,
        deleteIconColor: Colors.red[700],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.entry,
    required this.canEdit,
    required this.scheduling,
    required this.onSchedule,
    required this.onToggleActive,
    required this.onDelete,
  });

  final _MsgEntry entry;

  /// Phase 16: only an admin may update/delete an existing
  /// notificationMessages doc — a moderator sees the switch and delete
  /// disabled, but can still add new messages and use the calendar.
  final bool canEdit;
  final bool scheduling;
  final VoidCallback onSchedule;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: entry.active ? null : Theme.of(context).disabledColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: entry.active,
                  onChanged: canEdit ? onToggleActive : null,
                ),
                // Clamped: a supplementary status label next to the switch,
                // not primary content — left unscaled so a large accessibility
                // text-size setting can't widen this trailing cluster enough
                // to squeeze the message text into overflow.
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: Text(
                    entry.active ? 'مفعّلة' : 'معطّلة',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'حذف',
              onPressed: canEdit ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}
