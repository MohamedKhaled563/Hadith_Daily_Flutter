import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bulk_sync.dart';

/// Admin-only review queue for the moderator bulk-edit requests
/// bulk_add_page.dart stages once an Excel upload crosses
/// [kBulkChangeThreshold] items. Approving replays the staged
/// creates/updates/deletes through the same [applySheetDiff] the immediate
/// (admin or small-moderator) path uses; rejecting just marks the request
/// closed without touching dailyMessages/communityMessages/
/// notificationMessages at all.
class BulkChangeRequestsPage extends StatefulWidget {
  const BulkChangeRequestsPage({super.key});

  @override
  State<BulkChangeRequestsPage> createState() =>
      _BulkChangeRequestsPageState();
}

class _BulkChangeRequestsPageState extends State<BulkChangeRequestsPage> {
  final _busyRequestIds = <String>{};

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _approve(String requestId, Map<String, dynamic> data) async {
    setState(() => _busyRequestIds.add(requestId));
    BatchWriter? writer;
    try {
      final db = FirebaseFirestore.instance;
      final sheetsJson = Map<String, dynamic>.from(data['sheets'] as Map);
      writer = BatchWriter(db);
      final skippedIds = <String>[];
      for (final entry in sheetsJson.entries) {
        final diff = SheetDiff.fromJson(Map<String, dynamic>.from(entry.value as Map));
        // The diff was captured when the moderator submitted this request,
        // possibly days before this approval — applySheetDiff's own
        // existence check (against current Firestore state, not the
        // snapshot the diff was built from) is what keeps a since-deleted
        // doc from being silently resurrected by a stale update.
        skippedIds.addAll(await applySheetDiff(db, writer, diff));
      }
      await writer.flush();

      await db.collection('bulkChangeRequests').doc(requestId).update({
        'status': 'approved',
        'reviewedByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (mounted && skippedIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ تم تجاهل ${skippedIds.length} تحديث لأن المستند المستهدف '
              'حُذف منذ إرسال هذا الطلب',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذّرت الموافقة بعد تطبيق ${writer?.committedCount ?? 0} تغيير: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRequestIds.remove(requestId));
    }
  }

  Future<void> _reject(String requestId) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض التعديل الجماعي'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض (اختياري)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyRequestIds.add(requestId));
    try {
      await FirebaseFirestore.instance
          .collection('bulkChangeRequests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'reviewedByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'reviewedAt': FieldValue.serverTimestamp(),
        if (noteController.text.trim().isNotEmpty)
          'reviewNote': noteController.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الرفض: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyRequestIds.remove(requestId));
    }
  }

  String _sheetsBreakdown(Map<String, dynamic> data) {
    final sheetsJson = data['sheets'] as Map?;
    if (sheetsJson == null) return '';
    return sheetsJson.entries.map((entry) {
      final diff =
          SheetDiff.fromJson(Map<String, dynamic>.from(entry.value as Map));
      return '${diff.label}: تحديث ${diff.updates.length}، حذف '
          '${diff.deletes.length}، إضافة ${diff.creates.length}';
    }).join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'قيد الانتظار'),
              Tab(text: 'السجل'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestList(
                  query: FirebaseFirestore.instance
                      .collection('bulkChangeRequests')
                      .where('status', isEqualTo: 'pending')
                      .orderBy('submittedAt', descending: true),
                  emptyText: 'لا توجد طلبات مراجعة قيد الانتظار',
                  busyRequestIds: _busyRequestIds,
                  formatTimestamp: _formatTimestamp,
                  sheetsBreakdown: _sheetsBreakdown,
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _RequestList(
                  query: FirebaseFirestore.instance
                      .collection('bulkChangeRequests')
                      .where('status', whereIn: ['approved', 'rejected'])
                      .orderBy('reviewedAt', descending: true)
                      .limit(30),
                  emptyText: 'لا يوجد سجل بعد',
                  busyRequestIds: _busyRequestIds,
                  formatTimestamp: _formatTimestamp,
                  sheetsBreakdown: _sheetsBreakdown,
                  onApprove: null,
                  onReject: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.query,
    required this.emptyText,
    required this.busyRequestIds,
    required this.formatTimestamp,
    required this.sheetsBreakdown,
    required this.onApprove,
    required this.onReject,
  });

  final Query<Map<String, dynamic>> query;
  final String emptyText;
  final Set<String> busyRequestIds;
  final String Function(Timestamp?) formatTimestamp;
  final String Function(Map<String, dynamic>) sheetsBreakdown;
  final Future<void> Function(String, Map<String, dynamic>)? onApprove;
  final Future<void> Function(String)? onReject;

  static const _statusLabels = {
    'pending': 'قيد الانتظار',
    'approved': 'مُوافَق عليه',
    'rejected': 'مرفوض',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذّر التحميل: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final busy = busyRequestIds.contains(doc.id);
            final status = data['status'] as String? ?? 'pending';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (data['submittedByEmail'] as String?)?.isNotEmpty ==
                                    true
                                ? data['submittedByEmail'] as String
                                : 'مستخدم غير معروف',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Chip(label: Text(_statusLabels[status] ?? status)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أُرسل: ${formatTimestamp(data['submittedAt'] as Timestamp?)} '
                      '— ${data['totalChanges'] ?? 0} عنصراً',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(sheetsBreakdown(data)),
                    if (data['reviewNote'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'ملاحظة المراجعة: ${data['reviewNote']}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (onApprove != null && onReject != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: busy ? null : () => onReject!(doc.id),
                            child: const Text('رفض'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed:
                                busy ? null : () => onApprove!(doc.id, data),
                            child: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('موافقة وتنفيذ'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
