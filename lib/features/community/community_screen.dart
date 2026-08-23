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

              // Top Bar (Left '+' Brushed Gold button, Center Emblem with Ring, Right Menu/Drawer button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brushed Gold '+' Button (Matches Reference Image top-left)
                    _buildBrushedGoldAddButton(onTap: _openAddMessage),

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

                    // Top Right: Settings & Profile Drawer Trigger
                    _buildMenuButton(
                      isDark: isDark,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
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
  bool _isHovered = false;
  bool _isPressed = false;

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  Widget _getAvatarWidget(int rank, String authorName) {
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(
              color: const Color(0xFFD6BE88),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
        // Mini Rank Pill Badge (Matches screenshot: 1, 2, 3, 4 beside avatar)
        Positioned(
          bottom: -2,
          left: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFC7A566),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: Text(
              _toArabicDigits(rank),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
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
    // Exact warm parchment tones from reference screenshot
    final bgGradientColors = widget.isDark
        ? [
            const Color(0xFF23342A),
            const Color(0xFF1B2A20),
          ]
        : [
            const Color(0xFFEFE8DC),
            const Color(0xFFECE4D7),
          ];

    final textColor = widget.isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final borderColor = widget.isDark ? const Color(0x60D1BE93) : const Color(0x75D1BE93);

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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradientColors,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isHovered ? const Color(0xFFD6BE88) : borderColor,
                width: _isHovered ? 1.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? (widget.isDark ? const Color(0x50000000) : const Color(0x203B5644))
                      : (widget.isDark ? const Color(0x28000000) : const Color(0x0E000000)),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 5 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Subtle & Visible Islamic geometric watermark in center (Matches screenshot aesthetic!)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: IslamicWatermarkPainter(
                        color: widget.isDark
                            ? const Color(0x1AD1BE93)
                            : const Color(0x28B89F70),
                        strokeWidth: 1.1,
                      ),
                    ),
                  ),

                  // Card Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Author & Avatar on Right, Heart & Likes on Left (in RTL layout)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Heart Like interactive counter (Matches screenshot)
                            _HeartLikeLeftWidget(
                              likes: widget.post.likes,
                              isLiked: widget.post.isLiked,
                              onTap: widget.onLikeToggle,
                            ),

                            // Right: Author Name + Avatar with Rank
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.post.authorName,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _getAvatarWidget(widget.rank, widget.post.authorName),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Message Text (Generous line-height for Arabic readability)
                        Text(
                          widget.post.message,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.75,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Bottom Row: "مرتبط بالحديث رقم X" with subtle chevron icon (Matches screenshot)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: _isHovered
                                  ? (widget.isDark ? AppColors.gold : const Color(0xFF385240))
                                  : (widget.isDark ? const Color(0xFF8E9990) : const Color(0xFF857E70)),
                            ),
                            Text(
                              'مرتبط بالحديث رقم ${_toArabicDigits(widget.post.hadithNumber)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? AppColors.gold : const Color(0xFF7A8D80),
                                fontFamily: 'Tajawal',
                              ),
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
}

class _HeartLikeLeftWidget extends StatefulWidget {
  final int likes;
  final bool isLiked;
  final VoidCallback onTap;

  const _HeartLikeLeftWidget({
    required this.likes,
    required this.isLiked,
    required this.onTap,
  });

  @override
  State<_HeartLikeLeftWidget> createState() => _HeartLikeLeftWidgetState();
}

class _HeartLikeLeftWidgetState extends State<_HeartLikeLeftWidget> {
  bool _isHovered = false;

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _isHovered ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: widget.isLiked ? const Color(0xFFC73E3E) : const Color(0xFF6B726C),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _toArabicDigits(widget.likes),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.isLiked ? const Color(0xFFC73E3E) : const Color(0xFF6B726C),
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
