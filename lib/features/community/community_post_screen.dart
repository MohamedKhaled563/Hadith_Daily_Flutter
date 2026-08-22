import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../hadith/hadith_detail_screen.dart';

class CommunityPostScreen extends StatefulWidget {
  final CommunityPost post;

  const CommunityPostScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final HadithRepository _repo = HadithRepository();

  @override
  Widget build(BuildContext context) {
    final hadith = _repo.getByNumber(widget.post.hadithNumber);

    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      size: 20,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const Text(
                    'مشاركة مجتمعية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),

              const Spacer(),

              // Full Message Card
              AppCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryCard,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: AppColors.primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.authorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            Text(
                              'متأمل في الحديث ${widget.post.hadithNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Full Message text
                    Text(
                      widget.post.message,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                        fontFamily: 'Tajawal',
                      ),
                    ),

                    const SizedBox(height: 28),

                    // View related Hadith
                    if (hadith != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HadithDetailScreen(hadith: hadith),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hadith.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                    fontFamily: 'Tajawal',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_back,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Like and Share Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _repo.togglePostLike(widget.post.id);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: widget.post.isLiked ? Colors.red.shade400 : AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.post.likes} إعجاب',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
