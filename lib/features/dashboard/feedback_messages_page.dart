import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'bulk_select_bar.dart';

/// Moderator/admin view of messages sent from the app's settings drawer
/// ("تواصل معنا واقترح فكرة") — see FeedbackService.submit, which is the
/// only writer of this collection besides this page's own `read` toggle.
class FeedbackMessagesPage extends StatefulWidget {
  const FeedbackMessagesPage({super.key});

  @override
  State<FeedbackMessagesPage> createState() => _FeedbackMessagesPageState();
}

class _FeedbackMessagesPageState extends State<FeedbackMessagesPage> {
  final _stream = FirebaseFirestore.instance
      .collection('feedbackMessages')
      .orderBy('createdAt', descending: true)
      .snapshots();

  final _selectedIds = <String>{};
  bool _bulkDeleting = false;

  /// The live stream drops deleted rows by itself, so this only has to
  /// write the deletes and clear the selection.
  Future<void> _deleteSelected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final targets =
        docs.where((d) => _selectedIds.contains(d.id)).toList();
    if (targets.isEmpty) return;
    if (!await confirmBulkDelete(context, targets.length) || !mounted) return;

    setState(() => _bulkDeleting = true);
    var committed = targets.length;
    Object? error;
    try {
      await bulkDelete([for (final d in targets) d.reference]);
    } on BulkDeleteError catch (e) {
      committed = e.committed;
      error = e;
    }
    if (!mounted) return;
    setState(() {
      _bulkDeleting = false;
      _selectedIds.removeAll(targets.take(committed).map((d) => d.id));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null ? 'تم حذف $committed رسالة' : 'تعذّر الحذف: $error',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذّر تحميل الرسائل: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد رسائل من المستخدمين بعد',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        // Only count what is still in the mailbox — a selected row that
        // another moderator deleted simply drops out.
        final liveIds = {for (final d in docs) d.id};
        final selectedCount = _selectedIds.where(liveIds.contains).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: BulkSelectBar(
                visibleCount: docs.length,
                selectedVisibleCount: selectedCount,
                deleting: _bulkDeleting,
                onSelectAll: () => setState(() => _selectedIds
                  ..clear()
                  ..addAll(liveIds)),
                onClear: () => setState(_selectedIds.clear),
                onDelete: () => _deleteSelected(docs),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final id = docs[index].id;
                  return _FeedbackCard(
                    key: ValueKey(id),
                    doc: docs[index],
                    selected: _selectedIds.contains(id),
                    onSelectedChanged: _bulkDeleting
                        ? null
                        : (v) => setState(() => v
                            ? _selectedIds.add(id)
                            : _selectedIds.remove(id)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    super.key,
    required this.doc,
    required this.selected,
    required this.onSelectedChanged,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  Future<void> _toggleRead(bool value) {
    return doc.reference.update({'read': value});
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة؟'),
        content: Text(doc.data()['message'] as String? ?? ''),
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
    if (confirmed == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final userName = data['userName'] as String? ?? 'مستخدم';
    final userEmail = data['userEmail'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final read = data['read'] as bool? ?? false;
    final createdAt = data['createdAt'];
    final createdLabel = createdAt is Timestamp
        ? createdAt.toDate().toString().split('.').first
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: read ? null : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: onSelectedChanged == null
                      ? null
                      : (v) => onSelectedChanged!(v ?? false),
                ),
                CircleAvatar(
                  child: Text(userName.isNotEmpty ? userName[0] : '؟'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        userEmail.isEmpty
                            ? createdLabel
                            : '$userEmail  ·  $createdLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!read)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'جديدة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  tooltip: 'حذف',
                  onPressed: () => _delete(context),
                ),
                TextButton.icon(
                  onPressed: () => _toggleRead(!read),
                  icon: Icon(
                    read ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                  ),
                  label: Text(read ? 'وضع كغير مقروءة' : 'وضع كمقروءة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
