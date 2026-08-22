import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';

class AddMessageScreen extends StatefulWidget {
  const AddMessageScreen({super.key});

  @override
  State<AddMessageScreen> createState() => _AddMessageScreenState();
}

class _AddMessageScreenState extends State<AddMessageScreen> {
  final HadithRepository _repo = HadithRepository();
  final _messageController = TextEditingController();
  final _authorController = TextEditingController();
  Hadith? _selectedHadith;
  bool _shareWithCommunity = true;

  @override
  void initState() {
    super.initState();
    _selectedHadith = _repo.hadiths.first;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء كتابة نص الرسالة أو التأمل', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newPost = CommunityPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hadithNumber: _selectedHadith?.number ?? 1,
      arabic: _messageController.text.trim(),
      authorName: _authorController.text.trim().isEmpty ? 'فاعل خير' : _authorController.text.trim(),
      likes: 0,
      createdAt: DateTime.now(),
    );

    _repo.addCommunityPost(newPost);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال رسالتك بنجاح ونشرها في المجتمع 🌿', textDirection: TextDirection.rtl),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    _messageController.clear();
    _authorController.clear();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Header matching اضف رسالة.png
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (Navigator.canPop(context))
                  _buildCircleButton(
                    icon: Icons.chevron_right,
                    onTap: () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 44),

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

                const SizedBox(width: 44),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Titles
          const Text(
            'أضف رسالتك',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'شارك خاطرة أو تأملاً مربوطاً بحديث نبوي شريف',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              fontFamily: 'Tajawal',
            ),
          ),

          const SizedBox(height: 14),

          // Form matching اضف رسالة.png
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field 1: Choose Hadith
                  _buildLabel('اختر الحديث المرتبط بالرسالة'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD1BE93).withOpacity(0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Hadith>(
                        isExpanded: true,
                        value: _selectedHadith,
                        items: _repo.hadiths.map((h) {
                          return DropdownMenuItem(
                            value: h,
                            child: Text(
                              'الحديث ${h.number}: ${h.title}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryText,
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
                  _buildLabel('اسمك أو لقبك (اختياري)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD1BE93).withOpacity(0.4),
                      ),
                    ),
                    child: TextField(
                      controller: _authorController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'مثال: سارة، فاعل خير...',
                        hintStyle: TextStyle(
                          color: AppColors.placeholder,
                          fontSize: 13,
                          fontFamily: 'Tajawal',
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Field 3: Reflection Text
                  _buildLabel('نص الرسالة أو التأمل'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD1BE93).withOpacity(0.4),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب ما فتح الله به عليك من أثر هذا الحديث في حياتك...',
                        hintStyle: TextStyle(
                          color: AppColors.placeholder,
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
                      const Text(
                        'مشاركة الرسالة في مجتمع الحديث العام',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      Switch(
                        value: _shareWithCommunity,
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
                        backgroundColor: AppColors.primaryGreen,
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
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryGreen,
        fontFamily: 'Tajawal',
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(icon, size: 22, color: AppColors.primaryText),
      ),
    );
  }
}
