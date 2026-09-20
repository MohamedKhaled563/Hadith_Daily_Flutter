import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';

/// A submitter's own feedback loop: every message they've ever sent to the
/// community feed, whatever its current status, so approval/rejection is
/// something they can check rather than something that happens silently.
/// No push notifications — the app has no server component (Spark plan,
/// no Cloud Functions), so this reads the same `communityMessages` docs
/// the rest of the app already does, filtered to `authorUid == me`.
class MySubmissionsScreen extends StatelessWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'رجوع',
                  onTap: () => Navigator.maybePop(context),
                ),
                Text('مشاركاتي', style: textTheme.titleMedium?.copyWith(fontSize: 18)),
                const SizedBox(width: 44),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: uid == null
                ? AppEmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'سجّل الدخول لعرض مشاركاتك',
                    subtitle: '',
                  )
                // No orderBy here on purpose — combining it with the
                // authorUid equality filter needs a composite index this
                // service account isn't provisioned to create, and a
                // client-side sort is plenty for one person's own message
                // count. Same approach the community feed already uses for
                // its "most liked" sort.
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('communityMessages')
                        .where('authorUid', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return AppEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'تعذّر تحميل مشاركاتك',
                          subtitle: 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snapshot.data!.docs,
                      )..sort((a, b) {
                          final ta = a.data()['createdAt'] as Timestamp?;
                          final tb = b.data()['createdAt'] as Timestamp?;
                          if (ta == null || tb == null) return 0;
                          return tb.compareTo(ta);
                        });
                      if (docs.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.edit_note_rounded,
                          title: 'لم تشارك رسالة بعد',
                          subtitle: 'أول مشاركة منك ستظهر هنا بمجرد إرسالها.',
                        );
                      }
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          return _SubmissionCard(
                            message: data['message'] as String? ?? '',
                            hadithNumber: data['hadithNumber'] as int? ?? 0,
                            status: data['status'] as String? ?? 'pending',
                            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.message,
    required this.hadithNumber,
    required this.status,
    required this.createdAt,
  });

  final String message;
  final int hadithNumber;
  final String status;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      showCornerOrnaments: false,
      showWatermark: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadge(status: status),
              Text(
                'الحديث ${toArabicDigits(hadithNumber)}',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: 1.5,
              color: palette.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Was one hardcoded colour per status on a 12%-alpha wash of itself, with
    // no dark variant: 2.02:1 at the worst. Now the semantic roles, which
    // carry a legible pair per theme. The leading icon is there so status
    // does not rest on hue alone.
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;

    switch (status) {
      case 'approved':
        bg = palette.successWash;
        fg = palette.success;
        icon = Icons.check_circle_outline_rounded;
        label = 'مقبولة';
        break;
      case 'rejected':
        bg = palette.dangerWash;
        fg = palette.danger;
        icon = Icons.cancel_outlined;
        label = 'غير مقبولة';
        break;
      default:
        bg = palette.warningWash;
        fg = palette.warning;
        icon = Icons.hourglass_empty_rounded;
        label = 'قيد المراجعة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        // The wash alone is close in luminance to the card behind it; the rim
        // is what makes the badge read as its own object.
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
