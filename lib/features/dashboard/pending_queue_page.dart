import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PendingQueuePage extends StatelessWidget {
  const PendingQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('communityMessages')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذّر تحميل القائمة: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد رسائل بانتظار المراجعة 🌿',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _PendingCard(
            key: ValueKey(docs[index].id),
            doc: docs[index],
          ),
        );
      },
    );
  }
}

class _PendingCard extends StatefulWidget {
  const _PendingCard({super.key, required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  late final TextEditingController _textController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.doc.data()['message'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _review(String status) async {
    setState(() => _busy = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await widget.doc.reference.update({
        'status': status,
        // Any edit made in the text field goes out together with the
        // decision — no separate "save" step needed for the common case.
        'message': _textController.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': uid,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final authorName = data['authorName'] as String? ?? 'فاعل خير';
    final hadithNumber = data['hadithNumber'] as int? ?? 0;
    final createdAt = data['createdAt'];
    final createdLabel = createdAt is Timestamp
        ? createdAt.toDate().toString().split('.').first
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(authorName.isNotEmpty ? authorName[0] : '؟'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'الحديث رقم $hadithNumber  ·  $createdLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: null,
              enabled: !_busy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText: 'يمكن تعديل النص قبل الموافقة أو الرفض',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _review('rejected'),
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                  label: const Text('رفض'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _review('approved'),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('موافقة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
