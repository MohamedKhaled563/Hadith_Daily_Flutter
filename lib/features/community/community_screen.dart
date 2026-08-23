import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import 'community_post_screen.dart';
import '../share/add_message_screen.dart';
import '../profile/settings_drawer.dart';

class CommunityScreen extends StatefulWidget {
  final VoidCallback? onSwitchToShareTab;

  const CommunityScreen({
    super.key,
    this.onSwitchToShareTab,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final HadithRepository _repo = HadithRepository();
  final AppStateController _state = AppStateController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sortByLikes = true; // true = Most liked, false = Newest

  void _openAddMessage() {
    if (widget.onSwitchToShareTab != null) {
      widget.onSwitchToShareTab!();
    } else {
      Navigator.push(
        context,
        SmoothPageRoute(
          child: const AddMessageScreen(),
        ),
      ).then((_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _state.isDarkMode;
    final subTextColor = isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061);

    // Get posts and sort
    final posts = List<CommunityPost>.from(_repo.communityPosts);
    if (_sortByLikes) {
      posts.sort((a, b) => b.likes.compareTo(a.likes));
    } else {
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Top Bar: Options Menu button on Top-Right (RTL Start), Center Emblem, '+' Add button on Top-Left (RTL End)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top-Right in RTL: Settings & Profile Drawer Trigger with Menu icon
                    _buildMenuButton(
                      isDark: isDark,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    ),

                    // Center Emblem with circular copper/gold ring frame
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.softCreamDark : const Color(0xFFFAF6EE),
                        border: Border.all(
                          color: const Color(0xFFD6BE88),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0E000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.png',
                        width: 36,
                        height: 36,
                        fallback: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),

                    // Top-Left in RTL: Brushed Gold '+' Button
                    _buildBrushedGoldAddButton(onTap: _openAddMessage),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Titles (Matches Screenshot)
              Text(
                'مجتمع الحديث',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _sortByLikes = true),
                    child: Text(
                      'أفضل ١٠ مشاركات لهذا الأسبوع',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _sortByLikes ? FontWeight.bold : FontWeight.normal,
                        color: _sortByLikes ? (isDark ? AppColors.gold : const Color(0xFF385240)) : subTextColor,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: subTextColor, fontSize: 12)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _sortByLikes = false),
                    child: Text(
                      'الأحدث',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_sortByLikes ? FontWeight.bold : FontWeight.normal,
                        color: !_sortByLikes ? (isDark ? AppColors.gold : const Color(0xFF385240)) : subTextColor,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Posts List with Authentic Parchment Cards & Islamic Watermark
              Expanded(
                child: posts.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد مشاركات بعد.. كن أول من يشارك!',
                          style: TextStyle(
                            fontSize: 14,
                            color: subTextColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _RefinedCommunityPostCard(
                            post: post,
                            rank: index + 1,
                            isDark: isDark,
                            onLikeToggle: () {
                              setState(() {
                                _repo.togglePostLike(post.id);
                              });
                            },
                            onTap: () {
                              Navigator.push(
                                context,
                                SmoothPageRoute(
                                  child: CommunityPostScreen(post: post),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          );
                        },
                      ),
              ),

              // Floating Action Banner (Exact match from screenshot: "شارك رسالتك وكن سبباً في نشر الخير 🌿")
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildShareCtaBanner(onTap: _openAddMessage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrushedGoldAddButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEADBBE),
              Color(0xFFC7A566),
              Color(0xFF9E7C3E),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFF3E7CE),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Color(0xFF26352C),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildMenuButton({required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.softCreamDark : const Color(0xFFFAF6EE),
          border: Border.all(
            color: const Color(0x66D1BE93),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.menu_rounded,
          color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildShareCtaBanner({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color(0xFF1E3526),
              Color(0xFF2E4F3B),
              Color(0xFF1E3526),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFD6BE88),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3526).withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFFD6BE88).withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.edit_note_rounded,
              color: Color(0xFFF0E6D2),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'شارك رسالتك وكن سبباً في نشر الخير 🌿',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFFDFC),
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefinedCommunityPostCard extends StatefulWidget {
  final CommunityPost post;
  final int rank;
  final bool isDark;
  final VoidCallback onLikeToggle;
  final VoidCallback onTap;

  const _RefinedCommunityPostCard({
    required this.post,
    required this.rank,
    required this.isDark,
    required this.onLikeToggle,
    required this.onTap,
  });

  @override
  State<_RefinedCommunityPostCard> createState() => _RefinedCommunityPostCardState();
}

class _RefinedCommunityPostCardState extends State<_RefinedCommunityPostCard> {
  final HadithRepository _repo = HadithRepository();
  bool _isHovered = false;
  bool _isPressed = false;

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  void _copyPostText() {
    final hadith = _repo.getByNumber(widget.post.hadithNumber);
    final textToCopy = '« ${widget.post.message} »\n\n'
        '✍️ بقلم: ${widget.post.authorName}\n'
        '📌 المرتبط بـ: ${hadith?.title ?? 'الحديث رقم ${widget.post.hadithNumber}'}\n'
        '🌿 من تطبيق: طيّب قلبك - مجتمع المتأملين';
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص المشاركة بنجاح 🌿',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _getAvatarWidget(int rank, String authorName, bool isDark) {
    final initial = authorName.isNotEmpty ? authorName.substring(0, 1) : 'م';
    final List<Color> avatarColors = [
      const Color(0xFF6B8E76),
      const Color(0xFFB9A06A),
      const Color(0xFF8A6D9B),
      const Color(0xFF5A7B9B),
    ];
    final color = avatarColors[(rank - 1) % avatarColors.length];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
            border: Border.all(
              color: const Color(0xFFD6BE88),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD6BE88).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
        // Mini Rank Badge
        Positioned(
          bottom: -2,
          left: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFC7A566),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.0),
              boxShadow: const [
                BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              _toArabicDigits(rank),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hadith = _repo.getByNumber(widget.post.hadithNumber);

    // Exact warm parchment tones with subtle luxury gradient matching Daily Message Card
    final bgGradientColors = widget.isDark
        ? [
            const Color(0xFF24362B),
            const Color(0xFF1B2A20),
            const Color(0xFF152219),
          ]
        : [
            const Color(0xFFF2ECE0),
            const Color(0xFFEBE3D4),
            const Color(0xFFE5DCCB),
          ];

    final textColor = widget.isDark ? const Color(0xFFF7F5EE) : const Color(0xFF243329);
    final borderColor = widget.isDark
        ? (_isHovered ? const Color(0xFFD6BE88) : const Color(0x80D1BE93))
        : (_isHovered ? const Color(0xFFD6BE88) : const Color(0xA5D1BE93));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : (_isHovered ? 1.012 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradientColors,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: borderColor,
                width: 1.4,
              ),
              boxShadow: [
                // 1. Ambient deep ground shadow
                BoxShadow(
                  color: widget.isDark
                      ? Colors.black.withOpacity(0.50)
                      : const Color(0xFF1B3322).withOpacity(0.16),
                  blurRadius: _isHovered ? 28 : 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                // 2. Crisp tactile directional drop shadow
                BoxShadow(
                  color: widget.isDark ? const Color(0x35000000) : const Color(0x10000000),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                // 3. Specular Gold Rim Light
                BoxShadow(
                  color: const Color(0xFFD6BE88).withOpacity(widget.isDark ? 0.14 : 0.22),
                  blurRadius: _isHovered ? 16 : 10,
                  offset: const Offset(0, -1),
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  // 1. Subtle & Authentic Islamic geometric watermark in center
                  Positioned.fill(
                    child: CustomPaint(
                      painter: IslamicWatermarkPainter(
                        color: widget.isDark
                            ? const Color(0x1CD1BE93)
                            : const Color(0x28B89F70),
                        strokeWidth: 1.15,
                      ),
                    ),
                  ),

                  // 2. Corner Ornament Painter for crisp luxury gold brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CornerOrnamentPainter(
                        color: widget.isDark
                            ? const Color(0x55D1BE93)
                            : const Color(0x77B89F70),
                      ),
                    ),
                  ),

                  // 3. Botanical Top-Right Watercolor Branch Asset
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: widget.isDark ? 0.35 : 0.60,
                        child: AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/botanical_top_right.png',
                          width: 95,
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // 4. Botanical Bottom-Left Watercolor Branch Asset
                  Positioned(
                    bottom: -6,
                    left: -6,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: widget.isDark ? 0.35 : 0.60,
                        child: AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/botanical_bottom_left.png',
                          width: 95,
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // 5. Card Inner Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Header Row with Like Counter on the Left (in RTL layout)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left: Interactive Like Heart Counter
                            _buildHeartLikeCounter(widget.isDark),

                            // Center: Author Circular Avatar with Gold Rim & Rank
                            _getAvatarWidget(widget.rank, widget.post.authorName, widget.isDark),

                            // Right: Quick Copy Icon Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _copyPostText,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF6EE),
                                    border: Border.all(
                                      color: const Color(0x70D1BE93),
                                      width: 1.1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 17,
                                    color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Author Name & Subtitle
                        Text(
                          widget.post.authorName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'متأمل في الحديث الشريف ${_toArabicDigits(widget.post.hadithNumber)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? AppColors.gold : const Color(0xFF8C6B1B),
                            fontFamily: 'Tajawal',
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Top Golden Divider
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 110,
                          height: 14,
                          fallback: Container(
                            width: 60,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Central Message Quote with Refined Typography
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '« ${widget.post.message} »',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.8,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Bottom Golden Divider
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 110,
                          height: 14,
                          fallback: Container(
                            width: 60,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Associated Hadith Link Button
                        if (hadith != null) ...[
                          _buildHadithLinkPill(hadith, widget.isDark),
                          const SizedBox(height: 14),
                        ],

                        // Brand Watermark Signature
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 16,
                              height: 1,
                              color: const Color(0x70D1BE93),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '🌿 طيّب قلبك • مشاركات المجتمع',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? AppColors.gold : const Color(0xFF5A7562),
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 16,
                              height: 1,
                              color: const Color(0x70D1BE93),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive Heart Like Counter inside the Card
  Widget _buildHeartLikeCounter(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onLikeToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? (widget.post.isLiked ? const Color(0xFF382323) : const Color(0xFF1B2B20))
                : (widget.post.isLiked ? const Color(0xFFFDE8E8) : const Color(0xFFFAF6EE)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.post.isLiked ? const Color(0xFFC73E3E).withOpacity(0.6) : const Color(0x70D1BE93),
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: widget.post.isLiked ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Icon(
                  widget.post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: widget.post.isLiked ? const Color(0xFFC73E3E) : const Color(0xFF6B726C),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _toArabicDigits(widget.post.likes),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: widget.post.isLiked
                      ? const Color(0xFFC73E3E)
                      : (isDark ? AppColors.primaryTextDark : const Color(0xFF385240)),
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHadithLinkPill(Hadith hadith, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF283B2E) : const Color(0xFFFAF5EB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x70D1BE93),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 14,
            color: isDark ? AppColors.gold : const Color(0xFF385240),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'الحديث ${hadith.number}: ${hadith.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.primaryTextDark : const Color(0xFF385240),
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_back_rounded,
            size: 13,
            color: isDark ? AppColors.gold : const Color(0xFF385240),
          ),
        ],
      ),
    );
  }
}
