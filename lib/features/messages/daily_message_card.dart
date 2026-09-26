import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_links.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/like_counter.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/message_like_service.dart';
import '../hadith/hadith_detail_screen.dart';

/// One message plus the hadith it hangs off, if that hadith resolved
/// locally.
@immutable
class DailyMessageEntry {
  const DailyMessageEntry({required this.insight, this.hadith});

  final Insight insight;
  final Hadith? hadith;
}

/// The message card and the controls that act on it — bookmark, share, copy
/// and, where the insight has a backing doc, the like counter.
///
/// Lives here rather than inside the message screen because there are now
/// two places a message is shown: inline on the home tab (today's message,
/// which stays there once opened) and on its own screen (a bookmarked one,
/// from favourites). One implementation so the two cannot drift apart.
class DailyMessageCard extends StatefulWidget {
  const DailyMessageCard({
    super.key,
    required this.entry,
    this.heroTag,
    this.footer,
    this.fillHeight = false,
  });

  final DailyMessageEntry entry;

  /// Fill the height given instead of sizing to the message.
  ///
  /// This is what keeps the screen still. Sized to content, a short message
  /// and a long one produce cards of very different heights, so the toolbar
  /// and the day's button move up and down as the reader moves through the
  /// day, and a long message pushes both off the bottom into a scroll. Told
  /// to fill instead, the card takes all the room left over, the controls
  /// sit at fixed positions under it, and the message text is fitted to the
  /// space rather than the space to the text.
  final bool fillHeight;

  /// Hero tag for the emblem at the top of the card, when this card is the
  /// destination of a flight. Null where there is no flight — notably the
  /// home tab, where the card *replaces* the emblem rather than arriving
  /// from it, and two live Heroes sharing a tag would assert.
  final String? heroTag;

  /// Shown under the controls. The home tab puts the day's next step here.
  final Widget? footer;

  @override
  State<DailyMessageCard> createState() => _DailyMessageCardState();
}

class _DailyMessageCardState extends State<DailyMessageCard> {
  final HadithRepository _repo = HadithRepository();

  Insight get _insight => widget.entry.insight;
  Hadith? get _hadith => widget.entry.hadith;

  // Read live rather than cached: home swaps the entry in place when the
  // reader asks for another message, and the account's favourites can land
  // after the card is built (right after signing in).
  bool get _isBookmarked => _repo.isInsightFavorite(_insight);

  @override
  void initState() {
    super.initState();
    _repo.favoritesListenable.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _repo.favoritesListenable.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  String get _shareText {
    final link = AppLinks.storeLink;
    return '« ${_insight.message} »\n\n'
        'المرتبط بـ: ${_hadith?.title ?? 'حديث نبوي شريف'}\n'
        'من تطبيق: طيّب قلبك - هدي النبوة'
        '${link == null ? '' : '\n$link'}';
  }

  void _copyMessageText() {
    Clipboard.setData(ClipboardData(text: _shareText));
    showAppSnack(context, 'تم نسخ نص الرسالة', tone: SnackTone.success);
  }

  Future<void> _toggleBookmark() async {
    if (!await requireSignIn(context, reason: kFavoritesSignInReason)) return;
    if (!mounted) return;
    AppHaptics.toggle();
    setState(() => _repo.toggleFavoriteInsight(_insight));

    showAppSnack(
      context,
      _isBookmarked ? 'تم حفظ الرسالة في المفضلة' : 'تمت الإزالة من المفضلة',
      tone: _isBookmarked ? SnackTone.success : SnackTone.neutral,
      action: _isBookmarked ? null : undoAction(context, _toggleBookmark),
    );
  }

  void _showSharePreview() {
    showShareSheet(
      context: context,
      message: _insight.message,
      hadithTitle: _hadith?.title,
      hadithNumber: _hadith == null ? null : toArabicDigits(_hadith!.number),
      category: _insight.category,
    );
  }

  Widget get _toolbar => _insight.isLikeable
      ? _LiveMessageToolbar(
          insight: _insight,
          isBookmarked: _isBookmarked,
          onBookmark: _toggleBookmark,
          onShare: _showSharePreview,
          onCopy: _copyMessageText,
        )
      : _MessageToolbar(
          isBookmarked: _isBookmarked,
          likes: null,
          isLiked: false,
          onBookmark: _toggleBookmark,
          onShare: _showSharePreview,
          onCopy: _copyMessageText,
          onLike: null,
        );

  @override
  Widget build(BuildContext context) {
    if (!widget.fillHeight) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCard(),
          const SizedBox(height: 14),
          _toolbar,
          if (widget.footer != null) ...[
            const SizedBox(height: 16),
            widget.footer!,
          ],
        ],
      );
    }

    // The controls are laid out last and keep their own height, so whatever
    // is left goes to the card. Their distance from the bottom of the screen
    // is then the same on every message.
    return Column(
      children: [
        Expanded(child: _buildCard()),
        const SizedBox(height: 14),
        _toolbar,
        if (widget.footer != null) ...[
          const SizedBox(height: 14),
          widget.footer!,
        ],
      ],
    );
  }

  Widget _buildCard() {
    final palette = context.palette;

    final emblem = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(color: palette.cardBorderStrong, width: 1.5),
      ),
      child: Center(
        child: AssetHelper.assetOrFallback(
          assetPath: 'assets/images/heart_leaf_emblem.png',
          width: 34,
          height: 34,
          fallback: const Icon(
            Icons.favorite_rounded,
            color: AppColors.primaryGreen,
            size: 26,
          ),
        ),
      ),
    );

    final messageStyle = TextStyle(
      fontFamily: kSans,
      fontSize: 20,
      height: AppLeading.scripture,
      fontWeight: FontWeight.w800,
      color: palette.bodyText,
    );

    return ParchmentCard(
      elevated: true,
      showBotanicals: true,
      padding: EdgeInsets.all(widget.fillHeight ? 18 : 22),
      child: Column(
        mainAxisSize:
            widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          widget.heroTag == null
              ? emblem
              : Hero(tag: widget.heroTag!, child: emblem),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.cardBorder, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/leaf_accent.png',
                  width: 14,
                  height: 14,
                  fallback: Icon(
                    Icons.eco_rounded,
                    size: 14,
                    color: palette.goldText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _insight.category,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12.5,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
              ],
            ),
          ),
          GoldDivider(compact: widget.fillHeight),
          if (widget.fillHeight)
            Expanded(
              child: Center(
                child: _FittedMessage(
                  text: '« ${_insight.message} »',
                  style: messageStyle,
                ),
              ),
            )
          else
            Text(
              '« ${_insight.message} »',
              textAlign: TextAlign.center,
              style: messageStyle,
            ),
          GoldDivider(compact: widget.fillHeight),
          const SizedBox(height: 2),
          if (_hadith != null) ...[
            _HadithLinkPill(
              hadith: _hadith!,
              onTap: () => Navigator.push(
                context,
                appPageRoute(child: HadithDetailScreen(hadith: _hadith!)),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// Streams the live like count + this device's own like status from
/// [MessageLikeService] and feeds them into [_MessageToolbar] — split out
/// from it so a non-likeable insight (see [Insight.isLikeable]) never has to
/// touch Firestore at all.
class _LiveMessageToolbar extends StatefulWidget {
  const _LiveMessageToolbar({
    required this.insight,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.onCopy,
  });

  final Insight insight;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  State<_LiveMessageToolbar> createState() => _LiveMessageToolbarState();
}

class _LiveMessageToolbarState extends State<_LiveMessageToolbar> {
  final _likeService = MessageLikeService();

  // Optimistic "have I liked this": MessageLikeService.toggleLike runs a
  // Firestore transaction, and unlike a plain set/update, a transaction's
  // write is never applied to the local cache ahead of the server — the
  // likeStatus()/likeCount() streams below sit frozen until the round trip
  // completes. Without this override the heart would visibly do nothing
  // for however long that takes. Cleared once the live stream confirms the
  // same value, so a like from another device still always wins.
  bool? _optimisticLiked;
  bool _isToggling = false;

  Future<void> _handleLike(bool serverLiked) async {
    if (_isToggling) return;
    // Liking is one of the three things that needs to know who you are — the
    // like doc is keyed by uid so it follows the reader between devices.
    if (!await requireSignIn(
      context,
      reason: 'سجّل الدخول ليبقى إعجابك محفوظاً على كل أجهزتك',
    )) {
      return;
    }
    if (!mounted) return;
    final next = !(_optimisticLiked ?? serverLiked);
    setState(() {
      _optimisticLiked = next;
      _isToggling = true;
    });
    try {
      await _likeService.toggleLike(
        widget.insight.sourceCollection,
        widget.insight.id,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticLiked = null);
        showAppSnack(
          context,
          'تعذّر تسجيل الإعجاب، حاول مجدداً',
          tone: SnackTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _likeService.likeCount(
        widget.insight.sourceCollection,
        widget.insight.id,
      ),
      builder: (context, likeCountSnap) {
        return StreamBuilder<bool>(
          stream: _likeService.likeStatus(
            widget.insight.sourceCollection,
            widget.insight.id,
          ),
          builder: (context, likedSnap) {
            final serverLiked = likedSnap.data ?? false;
            if (_optimisticLiked != null && _optimisticLiked == serverLiked) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _optimisticLiked == serverLiked) {
                  setState(() => _optimisticLiked = null);
                }
              });
            }
            final isLiked = _optimisticLiked ?? serverLiked;
            final serverCount = likeCountSnap.data ?? 0;
            final displayedLikes =
                serverCount +
                (_optimisticLiked != null && _optimisticLiked != serverLiked
                    ? (_optimisticLiked! ? 1 : -1)
                    : 0);

            return _MessageToolbar(
              isBookmarked: widget.isBookmarked,
              likes: displayedLikes,
              isLiked: isLiked,
              onBookmark: widget.onBookmark,
              onShare: widget.onShare,
              onCopy: widget.onCopy,
              onLike: () => _handleLike(serverLiked),
            );
          },
        );
      },
    );
  }
}

/// A floating toolbar below the message card: the like counter on the right
/// (omitted when [likes] is null — the insight has nothing to like against,
/// see [Insight.isLikeable]), bookmark/share/copy grouped on the left,
/// separated by a hairline divider.
class _MessageToolbar extends StatelessWidget {
  const _MessageToolbar({
    required this.isBookmarked,
    required this.likes,
    required this.isLiked,
    required this.onBookmark,
    required this.onShare,
    required this.onCopy,
    required this.onLike,
  });

  final bool isBookmarked;
  final int? likes;
  final bool isLiked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
        boxShadow: AppElevation.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First child sits at the START edge — the right, in RTL — which
          // is where the like counter belongs.
          if (likes != null && onLike != null) ...[
            LikeCounter(likes: likes!, isLiked: isLiked, onTap: onLike!),
            const SizedBox(width: 14),
            Container(width: 1, height: 22, color: palette.cardBorder),
            const SizedBox(width: 14),
          ],
          _CardActionIcon(
            icon: isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            semanticLabel: 'حفظ الرسالة في المفضلة',
            toggled: isBookmarked,
            onTap: onBookmark,
          ),
          const SizedBox(width: 10),
          _CardActionIcon(
            icon: Icons.ios_share_rounded,
            semanticLabel: 'مشاركة البطاقة كصورة',
            onTap: onShare,
          ),
          const SizedBox(width: 10),
          _CardActionIcon(
            icon: Icons.copy_rounded,
            semanticLabel: 'نسخ نص الرسالة',
            onTap: onCopy,
          ),
        ],
      ),
    );
  }
}

/// A small round icon action clustered on the message toolbar — copy, share,
/// bookmark, all together rather than split between the card and the screen
/// header.
class _CardActionIcon extends StatelessWidget {
  const _CardActionIcon({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.toggled = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool toggled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      toggled: toggled,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: toggled ? palette.surfaceSunken : palette.surface,
          border: Border.all(
            color: toggled ? palette.cardBorderStrong : palette.cardBorder,
            width: 1.1,
          ),
        ),
        child: Icon(icon, size: 17, color: palette.goldText),
      ),
    );
  }
}

/// The message, at the largest size that still fits the space it is given.
///
/// The messages are reader-submitted and admin-curated, so their length is
/// not controlled: some are a line, some are a short paragraph. At one fixed
/// size the long ones either overflow or force the screen to scroll. Rather
/// than scroll, this steps the size down until the text fits, which keeps
/// every message on one screen and keeps short ones at their full size.
///
/// The floor matters as much as the ceiling — below it, fitting more words
/// on screen stops being worth what it costs to read them, so a message that
/// long is allowed to scroll inside the card instead.
class _FittedMessage extends StatelessWidget {
  const _FittedMessage({required this.text, required this.style});

  final String text;
  final TextStyle style;

  /// The size a message is set at when it has room to spare.
  ///
  /// Well above the 20 the card used to be fixed at, and that is the point:
  /// with the card filling a set height, a one-line message set at 20 sat
  /// marooned in a large empty parchment. Sized to the space it has, a short
  /// message reads as a deliberate statement instead of an accident.
  static const maxFontSize = 30.0;

  /// Below this the text stops being comfortable to read, so a message that
  /// still does not fit scrolls inside the card instead of shrinking on.
  static const minFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    // The app composes its own reading-size preference on top of the OS one
    // (see main.dart), so measuring has to use the same scaler Text will.
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        var fontSize = maxFontSize;

        double heightAt(double size) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
            textDirection: direction,
            textAlign: TextAlign.center,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          return painter.height;
        }

        if (constraints.maxHeight.isFinite) {
          while (fontSize > minFontSize &&
              heightAt(fontSize) > constraints.maxHeight) {
            fontSize -= 0.5;
          }
        }

        final fitted = Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(fontSize: fontSize),
        );

        // Still too tall at the floor: a genuinely long message. Let it
        // scroll within the card rather than shrink past readability or
        // overflow the layout.
        if (constraints.maxHeight.isFinite &&
            heightAt(fontSize) > constraints.maxHeight) {
          return SingleChildScrollView(child: fitted);
        }
        return fitted;
      },
    );
  }
}

/// The gold flourish that separates the card's parts.
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.compact = false});

  /// Tighter spacing where the card is filling a fixed height — the two
  /// dividers otherwise cost 72px of the room the message could have used.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 18),
      child: AssetHelper.assetOrFallback(
        assetPath: 'assets/images/golden_divider.png',
        width: 120,
        height: 15,
        fallback: Container(
          width: 80,
          height: 1.5,
          color: const Color(0xFFD6BE88),
        ),
      ),
    );
  }
}

class _HadithLinkPill extends StatelessWidget {
  const _HadithLinkPill({required this.hadith, required this.onTap});

  final Hadith hadith;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel:
          'افتح الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: palette.cardBorder, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 15,
              color: palette.goldText,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: palette.goldText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
