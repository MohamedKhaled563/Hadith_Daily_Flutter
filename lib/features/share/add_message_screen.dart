import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/community_service.dart';

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
  String? _hadithError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // No default selection: publishing under a hadith the reader never
    // actually chose (previously always hadith #1) mis-attributes their words.
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

  Future<void> _submit() async {
    // The button's onPressed only goes to a no-op once _submitting flips
    // true and this widget rebuilds — a frame later. Two taps dispatched
    // before that rebuild both still reach the old closure and would both
    // pass validation and post, creating a duplicate submission.
    if (_submitting) return;

    final messageText = _messageController.text.trim();

    var hasError = false;

    if (messageText.isEmpty) {
      // Inline, next to the field it concerns — a red SnackBar at the far edge
      // of the screen makes the reader hunt for what went wrong.
      _messageError = 'اكتب نص الرسالة أولاً لتتمكن من إرسالها';
      hasError = true;
    }

    if (_selectedHadith == null) {
      _hadithError = 'اختر الحديث المرتبط برسالتك أولاً';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() {
      _messageError = null;
      _hadithError = null;
    });

    // There is nowhere in this app to keep a message that isn't published —
    // turning the switch off means "don't send it," not "save it privately."
    // The old copy claimed the message was saved either way, which quietly
    // discarded it when the switch was off.
    if (!_shareWithCommunity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لن يتم نشر رسالتك بما أن المشاركة العامة معطّلة — '
            'فعّل الخيار أعلاه لنشرها 🌿',
          ),
        ),
      );
      return;
    }

    final authorName = _authorController.text.trim().isEmpty
        ? (_state.isLoggedIn && _state.userName.isNotEmpty
              ? _state.userName
              : 'فاعل خير')
        : _authorController.text.trim();

    setState(() => _submitting = true);

    try {
      await CommunityService().submit(
        hadithNumber: _selectedHadith!.number,
        message: messageText,
        authorName: authorName,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر إرسال رسالتك، حاول مرة أخرى 🌿'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال رسالتك للمراجعة، وستظهر بعد موافقة المشرفين 🌿'),
      ),
    );

    _messageController.clear();
    setState(() => _selectedHadith = null);
    if (!_state.isLoggedIn) _authorController.clear();

    FocusScope.of(context).unfocus();
    widget.onPostCreated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final hadithsList = _repo.hadiths;

    return AppLoadingOverlay(
      visible: _submitting,
      message: 'جارٍ إرسال رسالتك…',
      child: Column(
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
          child: Text('شارك رسالتك', style: textTheme.headlineMedium),
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
                  borderColor: _hadithError != null
                      ? const Color(0xFFB3261E)
                      : null,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Hadith>(
                      isExpanded: true,
                      value: _selectedHadith,
                      hint: Text(
                        'اختر حديثاً...',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          color: palette.mutedText,
                        ),
                      ),
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
                        setState(() {
                          _selectedHadith = val;
                          if (val != null) _hadithError = null;
                        });
                      },
                    ),
                  ),
                ),
                if (_hadithError != null) ...[
                  const SizedBox(height: 8),
                  _InlineError(_hadithError!),
                ],

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
                  _InlineError(_messageError!),
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
                  text: _submitting ? 'جارٍ الإرسال…' : 'إرسال الرسالة 🌿',
                  icon: _submitting ? null : Icons.send_rounded,
                  onPressed: _submitting ? () {} : () => _submit(),
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
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: Color(0xFFB3261E),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message,
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 12.5,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB3261E),
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
