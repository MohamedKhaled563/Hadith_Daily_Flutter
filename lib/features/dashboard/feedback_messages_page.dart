import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Moderator/admin view of messages sent from the app's settings drawer
/// ("تواصل معنا واقترح فكرة") — see FeedbackService.submit, which is the
/// only writer of this collection besides this page's own `read` toggle.
class FeedbackMessagesPage extends StatelessWidget {
  const FeedbackMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('feedbackMessages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
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
              'لا توجد رسائل من المستخدمين بعد 🌿',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _FeedbackCard(
            key: ValueKey(docs[index].id),
            doc: docs[index],
          ),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({super.key, required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

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
