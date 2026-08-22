import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/repositories/hadith_repository.dart';
import 'community_post_screen.dart';
import '../share/add_message_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final HadithRepository _repo = HadithRepository();

  @override
  Widget build(BuildContext context) {
    final posts = _repo.communityPosts;

    return AppBackground(
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Header matching المجتمع.png
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 44), // Balancer

                // Center Emblem + Divider
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.svg',
                      width: 44,
                      height: 44,
                      fallback: const Icon(
                        Icons.favorite_border,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/golden_divider.svg',
                      width: 60,
                      height: 10,
                      fallback: const SizedBox(height: 2),
                    ),
                  ],
                ),

                // Add message button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMessageScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD1BE93).withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Titles
          const Text(
            'مجتمع الحديث',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'أفضل ١٠ مشاركات لهذا الأسبوع',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              fontFamily: 'Tajawal',
            ),
          ),

          const SizedBox(height: 14),

          // Top 10 Community List matching المجتمع.png
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFD1BE93).withOpacity(0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommunityPostScreen(post: post),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Rank + Name + Likes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  // Rank badge
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryCard,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold.withOpacity(0.5),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    post.authorName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),

                              // Like button
                              Row(
                                children: [
                                  Text(
                                    '${post.likes}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.favorite_border,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Post message
                          Text(
                            post.arabic,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryText,
                              fontFamily: 'Tajawal',
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Hadith reference
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'مرتبط بالحديث رقم ${post.hadithNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryGreen,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              const Icon(
                                Icons.chevron_left,
                                size: 18,
                                color: Color(0xFFAAA9A3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Call To Action matching المجتمع.png
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddMessageScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'شارك رسالتك وكن سبباً في نشر الخير 🌿',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
