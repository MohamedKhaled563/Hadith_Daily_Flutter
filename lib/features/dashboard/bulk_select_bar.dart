import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'bulk_sync.dart';

/// The strip above a dashboard list that offers bulk removal: a select-all
/// checkbox over whatever the list currently shows, how many are selected,
/// and a delete button for them. The per-row checkboxes live on each page's
/// own row widget; this bar only reflects and drives the shared selection.
class BulkSelectBar extends StatelessWidget {
  const BulkSelectBar({
    super.key,
    required this.visibleCount,
    required this.selectedVisibleCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onDelete,
    this.deleting = false,
  });

  final int visibleCount;
  final int selectedVisibleCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        visibleCount > 0 && selectedVisibleCount == visibleCount;
    final checkboxValue = selectedVisibleCount == 0
        ? false
        : (allSelected ? true : null);

    return Row(
      children: [
        Checkbox(
          tristate: true,
          value: checkboxValue,
          onChanged: visibleCount == 0 || deleting
              ? null
              : (_) => allSelected ? onClear() : onSelectAll(),
        ),
        Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
        const SizedBox(width: 12),
        if (selectedVisibleCount > 0)
          Text(
            'محدد: $selectedVisibleCount',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const Spacer(),
        if (deleting)
          const SizedBox(
            width: 36,
            height: 36,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          FilledButton.icon(
            onPressed: selectedVisibleCount == 0 ? null : onDelete,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: Text('حذف المحدد ($selectedVisibleCount)'),
          ),
      ],
    );
  }
}

/// Asks before deleting [count] items at once. True only on an explicit yes.
Future<bool> confirmBulkDelete(BuildContext context, int count) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حذف $count ${count == 1 ? 'عنصر' : 'عناصر'} نهائياً؟'),
      content: const Text('لا يمكن التراجع عن هذا الحذف.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, true),
          child: Text('حذف $count'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Deletes [refs] through [BatchWriter], so any number of rows goes out in
/// as few batches as the 500-write limit allows. Returns how many were
/// committed before an error, if one is thrown — the caller drops exactly
/// those from its list.
Future<int> bulkDelete(
  List<DocumentReference<Map<String, dynamic>>> refs,
) async {
  final writer = BatchWriter(FirebaseFirestore.instance);
  try {
    for (final ref in refs) {
      await writer.delete(ref);
    }
    await writer.flush();
  } catch (e) {
    throw BulkDeleteError(writer.committedCount, e);
  }
  return writer.committedCount;
}

class BulkDeleteError implements Exception {
  BulkDeleteError(this.committed, this.cause);

  final int committed;
  final Object cause;

  @override
  String toString() => 'حُذف $committed فقط — $cause';
}
