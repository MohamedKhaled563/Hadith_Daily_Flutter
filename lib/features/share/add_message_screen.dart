import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';

/// A tab inside [HomeScreen]'s IndexedStack — the host supplies the Scaffold
/// and the background.
class AddMessageScreen extends StatefulWidget {
  const AddMessageScreen({super.key, this.onPostCreated});

  final VoidCallback? onPostCreated;

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
  String? _messageError;

  @override
  void initState() {
    super.initState();
    if (_repo.hadiths.isNotEmpty) _selectedHadith = _repo.hadiths.first;
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
      // Inline, next to the field it concerns — a red SnackBar at the far edge
      // of the screen makes the reader hunt for what went wrong.
      setState(() => _messageError = 'اكتب نص الرسالة أولاً لتتمكن من إرسالها');
      return;
    }

    setState(() => _messageError = null);

    final authorName = _authorController.text.trim().isEmpty
        ? (_state.isLoggedIn && _state.userName.isNotEmpty
              ? _state.userName
              : 'فاعل خير')
        : _authorController.text.trim();

    if (_shareWithCommunity) {
      _repo.addCommunityPost(
        CommunityPost(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          hadithNumber: _selectedHadith?.number ?? 1,
          message: messageText,
          authorName: authorName,
          likes: 1,
          isLiked: true,
          createdAt: DateTime.now(),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _shareWithCommunity
              ? 'تم نشر رسالتك في المجتمع 🌿'
              : 'تم حفظ رسالتك 🌿',
        ),
      ),
    );

    _messageController.clear();
    if (!_state.isLoggedIn) _authorController.clear();

    FocusScope.of(context).unfocus();
    widget.onPostCreated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final hadithsList = _repo.hadiths;
    final currentHadith =
        _selectedHadith ?? (hadithsList.isNotEmpty ? hadithsList.first : null);

    return Column(
      children: [
        const SizedBox(height: 8),

        Center(
          child: Column(
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
        ),

        const SizedBox(height: 10),

        Semantics(
          header: true,
          child: Text('أضف رسالتك', style: textTheme.headlineMedium),
        ),
        const SizedBox(height: 4),
        Text(
          'شارك خاطرة أو تأملاً مربوطاً بحديث نبوي شريف',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),

        const SizedBox(height: 14),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20, 8, 20, 24 + BottomNavigation.reservedHeight(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('اختر الحديث المرتبط بالرسالة'),
                const SizedBox(height: 6),
                _FieldShell(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Hadith>(
                      isExpanded: true,
                      value: currentHadith,
                      dropdownColor: palette.surface,
                      borderRadius: BorderRadius.circular(AppRadii.listItem),
                      // 48dp rows keep the list itself tappable.
                      itemHeight: 48,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        color: palette.bodyText,
                      ),
                      items: [
                        for (final h in hadithsList)
                          DropdownMenuItem(
                            value: h,
                            child: Text(
                              'الحديث ${toArabicDigits(h.number)}: ${h.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedHadith = val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _Label('اسمك أو لقبك (اختياري)'),
                const SizedBox(height: 6),
                _FieldShell(
                  child: TextField(
                    controller: _authorController,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: kSans,
                      color: palette.bodyText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: سارة، فاعل خير...',
                      hintStyle: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontFamily: kSans,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _Label('نص الرسالة أو التأمل'),
                const SizedBox(height: 6),
                _FieldShell(
                  padding: const EdgeInsets.all(16),
                  borderColor: _messageError != null
                      ? const Color(0xFFB3261E)
                      : null,
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    onChanged: (_) {
                      if (_messageError != null) {
                        setState(() => _messageError = null);
                      }
                    },
                    style: TextStyle(
                      fontFamily: kSans,
                      color: palette.bodyText,
                      height: AppLeading.body,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'اكتب ما فتح الله به عليك من أثر هذا الحديث في حياتك...',
                      hintStyle: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        height: AppLeading.body,
                        fontFamily: kSans,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                if (_messageError != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Color(0xFFB3261E),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _messageError!,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 12.5,
                            height: AppLeading.chrome,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB3261E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'مشاركة الرسالة في مجتمع الحديث العام',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          height: AppLeading.chrome,
                          fontWeight: FontWeight.w600,
                          color: palette.bodyText,
                        ),
                      ),
                    ),
                    Switch(
                      value: _shareWithCommunity,
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (val) =>
                          setState(() => _shareWithCommunity = val),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                AppButton(
                  text: 'إرسال الرسالة 🌿',
                  icon: Icons.send_rounded,
                  onPressed: _submit,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 13,
        height: AppLeading.chrome,
        fontWeight: FontWeight.w700,
        color: context.palette.goldText,
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.listItem),
        border: Border.all(
          color: borderColor ?? palette.cardBorder,
          width: borderColor != null ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}
