import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/moderation_service.dart';

/// The moderator's side of the in-app report button.
///
/// Reports were landing in `contentReports` with nowhere to be read, which
/// made the feature half-built: App Store guideline 1.2 asks for content to be
/// reported *and acted on*, and a reader who reports something offensive and
/// watches nothing happen stops reporting.
///
/// Grouped by message rather than listed one row per report. The document id
/// is `<postId>_<reporterUid>`, so a second report of the same post by the
/// same reader overwrites the first — which means the number of rows for a
/// post is the number of *people* who objected, and that is the number worth
/// putting in front of a moderator. Three separate rows saying the same thing
/// would bury it.
class ContentReportsPage extends StatelessWidget {
  const ContentReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contentReports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذّر تحميل البلاغات: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد بلاغات مفتوحة',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        // Grouped in memory, not by a query: Firestore cannot group, and at
        // the volume a report queue runs at the whole open set is a handful
        // of documents.
        final byPost =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in docs) {
          final postId = doc.data()['postId'] as String? ?? '';
          if (postId.isEmpty) continue;
          byPost.putIfAbsent(postId, () => []).add(doc);
        }

        // Most-objected-to first: a message five people flagged deserves a
        // moderator's attention before one that a single reader disliked.
        final postIds = byPost.keys.toList()
          ..sort((a, b) => byPost[b]!.length.compareTo(byPost[a]!.length));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: postIds.length,
          itemBuilder: (context, index) => _ReportedMessageCard(
            key: ValueKey(postIds[index]),
            postId: postIds[index],
            reports: byPost[postIds[index]]!,
          ),
        );
      },
    );
  }
}

class _ReportedMessageCard extends StatefulWidget {
  const _ReportedMessageCard({
    super.key,
    required this.postId,
    required this.reports,
  });

  final String postId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> reports;

  @override
  State<_ReportedMessageCard> createState() => _ReportedMessageCardState();
}

class _ReportedMessageCardState extends State<_ReportedMessageCard> {
  bool _busy = false;
  String? _error;

  DocumentReference<Map<String, dynamic>> get _post =>
      FirebaseFirestore.instance
          .collection('communityMessages')
          .doc(widget.postId);

  /// Closes every open report on this message with one verdict.
  ///
  /// The reports are updated rather than deleted: a queue that empties itself
  /// leaves no record that anyone looked, and "we act on reports" is
  /// something a store may ask you to show rather than assert.
  Future<void> _resolve(String status, {bool hidePost = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final batch = FirebaseFirestore.instance.batch();

      if (hidePost) {
        // 'rejected' is the status the community feed already filters out,
        // so this uses the mechanism the pending queue uses rather than
        // inventing a second notion of hidden.
        batch.update(_post, {
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': uid,
        });
      }

      for (final report in widget.reports) {
        batch.update(report.reference, {
          'status': status,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': uid,
        });
      }

      await batch.commit();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'تعذّر تنفيذ الإجراء: $error';
        });
      }
      return;
    }
    // No setState on success: the stream drops this card from the list.
  }

  /// A report whose message the author has since deleted. There is nothing
  /// left to hide, so the only sensible action is to close the report.
  Future<void> _closeOrphan() => _resolve('dismissed');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _post.get(),
          builder: (context, snapshot) {
            final loading = !snapshot.hasData && !snapshot.hasError;
            final exists = snapshot.data?.exists ?? false;
            final post = snapshot.data?.data();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(count: widget.reports.length),
                const SizedBox(height: 14),

                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  )
                else if (!exists)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'المشاركة لم تعد موجودة — حذفها صاحبها أو حُذف حسابه.',
                    ),
                  )
                else
                  _PostPreview(post: post!),

                const SizedBox(height: 14),
                _Reasons(reports: widget.reports),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],

                const SizedBox(height: 14),
                if (loading)
                  const SizedBox.shrink()
                else if (!exists)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _closeOrphan,
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('إغلاق البلاغ'),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _resolve('dismissed'),
                        icon: const Icon(Icons.thumb_up_off_alt_rounded),
                        label: const Text('المشاركة سليمة'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _resolve('actioned', hidePost: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        icon: const Icon(Icons.visibility_off_rounded),
                        label: const Text('إخفاء المشاركة'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
          child: const Icon(Icons.flag_rounded, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            // The count is people, not reports — one reader cannot file
            // twice against the same message, because the document id is
            // `<postId>_<uid>` and the rule enforces that shape.
            count == 1
                ? 'قارئ واحد أبلغ عن هذه المشاركة'
                : 'أبلغ عنها $count قُرّاء',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = post['status'] as String? ?? '';
    final hadithNumber = post['hadithNumber'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post['message'] as String? ?? '',
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
          const SizedBox(height: 10),
          Text(
            '${post['authorName'] ?? 'فاعل خير'}  ·  '
            'الحديث رقم $hadithNumber  ·  $status',
            style: theme.textTheme.bodySmall,
          ),
          if (status == 'rejected')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'مخفية بالفعل — لم تعد تظهر في المجتمع.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.reports});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> reports;

  /// Maps the stored key back to the Arabic the reader actually chose, so the
  /// dashboard and the app cannot drift apart on what a reason means.
  String _label(String key) {
    for (final reason in ReportReason.values) {
      if (reason.key == key) return reason.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final report in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(report.data()['reason'] as String? ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if ((report.data()['note'] as String? ?? '')
                          .trim()
                          .isNotEmpty)
                        Text(
                          report.data()['note'] as String,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Text(
                  _when(report.data()['createdAt']),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _when(Object? createdAt) => createdAt is Timestamp
      ? createdAt.toDate().toString().split('.').first
      : '';
}
