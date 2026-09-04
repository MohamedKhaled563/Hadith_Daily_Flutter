import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Admin-only: lists every account and lets an admin change anyone else's
/// role with an ordinary Firestore write — see firestore.rules phase 11.
/// No Cloud Function, no Admin SDK from here; the write itself is what's
/// allowed or denied by the users/{uid} update rule.
class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('email')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('تعذّر تحميل المستخدمين: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('لا يوجد مستخدمون بعد'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) =>
              _UserCard(doc: docs[index], isSelf: docs[index].id == myUid),
        );
      },
    );
  }
}

const _roles = ['user', 'moderator', 'admin'];
const _roleLabels = {'user': 'مستخدم', 'moderator': 'مشرف', 'admin': 'مدير'};

class _UserCard extends StatefulWidget {
  const _UserCard({required this.doc, required this.isSelf});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isSelf;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _busy = false;

  Future<void> _changeRole(String role) async {
    setState(() => _busy = true);
    try {
      await widget.doc.reference.update({'role': role});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الدور إلى: ${_roleLabels[role]}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تحديث الدور: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final email = data['email'] as String? ?? '';
    final displayName = data['displayName'] as String? ?? '';
    final role = data['role'] as String? ?? 'user';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                () {
                  final label = displayName.isNotEmpty ? displayName : email;
                  return label.isNotEmpty ? label[0].toUpperCase() : '؟';
                }(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName.isNotEmpty ? displayName : email,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (widget.isSelf) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: const Text('أنت', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (widget.isSelf)
              // Rules block an admin from changing their own role (a
              // safety net against an accidental self-demotion lockout),
              // so the control just shows the current role here instead.
              Chip(label: Text(_roleLabels[role] ?? role))
            else if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              DropdownButton<String>(
                value: _roles.contains(role) ? role : 'user',
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabels[r]!)))
                    .toList(),
                onChanged: (value) {
                  if (value != null && value != role) _changeRole(value);
                },
              ),
          ],
        ),
      ),
    );
  }
}
