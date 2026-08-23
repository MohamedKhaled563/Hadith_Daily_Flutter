import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';

class AddMessageScreen extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const AddMessageScreen({super.key, this.onPostCreated});

  @override
  State<AddMessageScreen> createState() => _AddMessageScreenState();
}

class _AddMessageScreenState extends State<AddMessageScreen> {
  final HadithRepository _repo = HadithRepository();
  final AppStateController _state = AppStateController();
  final _messageController = TextEditingController();
  final _authorController = TextEditingController();
  Hadith? _selectedHadith;
  bool _shareWithCommunity = true;

  @override
  void initState() {
    super.initState();
    if (_repo.hadiths.isNotEmpty) {
      _selectedHadith = _repo.hadiths.first;
    }
    if (_state.isLoggedIn && _state.userName.isNotEmpty) {
      _authorController.text = _state.userName;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _submit() {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء كتابة نص الرسالة أو التأمل', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authorName = _authorController.text.trim().isEmpty
        ? (_state.isLoggedIn && _state.userName.isNotEmpty ? _state.userName : 'فاعل خير')
        : _authorController.text.trim();

    final newPost = CommunityPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hadithNumber: _selectedHadith?.number ?? 1,
      message: messageText,
      authorName: authorName,
      likes: 1, // Author's initial like
      isLiked: true,
      createdAt: DateTime.now(),
    );

    if (_shareWithCommunity) {
      _repo.addCommunityPost(newPost);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال رسالتك بنجاح ونشرها في المجتمع 🌿', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    _messageController.clear();
    if (!_state.isLoggedIn) {
      _authorController.clear();
    }

    if (widget.onPostCreated != null) {
      widget.onPostCreated!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _state.isDarkMode;
    final bgCard = isDark ? AppColors.cardDark : const Color(0xFFFFFDFC);
    final textColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final subTextColor = isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061);
    final borderColor = isDark ? AppColors.cardBorderDark : const Color(0x66D1BE93);

    final hadithsList = _repo.hadiths;
    final currentHadith = _selectedHadith ?? (hadithsList.isNotEmpty ? hadithsList.first : null);

    return AppBackground(
      showBottomLandscape: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (Navigator.canPop(context))
                    _buildCircleButton(
                      icon: Icons.chevron_right,
                      isDark: isDark,
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    )
                  else
                    const SizedBox(width: 44),

                  // Center Emblem
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.png',
                        width: 40,
                        height: 40,
                        fallback: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryGreen,
                          size: 28,
                        ),
                      ),
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/golden_divider.png',
                        width: 60,
                        height: 10,
                        fallback: const SizedBox(height: 2),
                      ),
                    ],
                  ),

                  const SizedBox(width: 44),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Titles
            Text(
              'أضف رسالتك',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'شارك خاطرة أو تأملاً مربوطاً بحديث نبوي شريف',
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
                fontFamily: 'Tajawal',
              ),
            ),

            const SizedBox(height: 14),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Choose Hadith
                    _buildLabel('اختر الحديث المرتبط بالرسالة', isDark),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Hadith>(
                          isExpanded: true,
                          value: currentHadith,
                          dropdownColor: bgCard,
                          items: hadithsList.map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text(
                                'الحديث ${h.number}: ${h.title}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedHadith = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Field 2: Your Name
                    _buildLabel('اسمك أو لقبك (اختياري)', isDark),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _authorController,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: 'Tajawal', color: textColor),
                        decoration: InputDecoration(
                          hintText: 'مثال: سارة، فاعل خير...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF9E9D97),
                            fontSize: 13,
                            fontFamily: 'Tajawal',
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Field 3: Reflection Text
                    _buildLabel('نص الرسالة أو التأمل', isDark),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: 'Tajawal', color: textColor, height: 1.6),
                        decoration: InputDecoration(
                          hintText: 'اكتب ما فتح الله به عليك من أثر هذا الحديث في حياتك...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF9E9D97),
                            fontSize: 13,
                            height: 1.6,
                            fontFamily: 'Tajawal',
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Switch: Share with community
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'مشاركة الرسالة في مجتمع الحديث العام',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        Switch(
                          value: _shareWithCommunity,
                          activeTrackColor: AppColors.primaryGreen.withOpacity(0.5),
                          activeColor: AppColors.primaryGreen,
                          onChanged: (val) => setState(() => _shareWithCommunity = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF385240),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'إرسال الرسالة 🌿',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.primaryGreenDark : const Color(0xFF385240),
        fontFamily: 'Tajawal',
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0x66D1BE93),
          ),
        ),
        child: Icon(icon, size: 22, color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
      ),
    );
  }
}
