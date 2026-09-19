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
import '../../core/widgets/tap_target.dart';
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
  // This screen sits inside the home Scaffold's body, and Scaffold strips
  // the keyboard's inset out of the MediaQuery it hands to its body (it's
  // already accounted for via resizing) — so MediaQuery.viewInsets.bottom
  // reads 0 here even while the keyboard is up. Tracking focus directly is
  // what actually tells this screen a field's keyboard is showing.
  final _authorFocusNode = FocusNode();
  final _messageFocusNode = FocusNode();

  Hadith? _selectedHadith;
  String? _messageError;
  String? _hadithError;
  bool _submitting = false;

  bool get _keyboardLikelyOpen =>
      _authorFocusNode.hasFocus || _messageFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    // No default selection: publishing under a hadith the reader never
    // actually chose (previously always hadith #1) mis-attributes their words.
    if (_state.isLoggedIn && _state.userName.isNotEmpty) {
      _authorController.text = _state.userName;
    }
    _authorFocusNode.addListener(_onFocusChanged);
    _messageFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _messageController.dispose();
    _authorController.dispose();
    _authorFocusNode.dispose();
    _messageFocusNode.dispose();
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
          content: Text('تعذّر إرسال رسالتك، تحقق من اتصالك بالإنترنت وحاول مرة أخرى 🌿'),
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
          // A plain Column here doesn't shrink with the keyboard the way
          // Expanded/BottomNavigation-scoped screens elsewhere do — this one
          // has no Scaffold of its own to resize it, so on a small screen the
          // keyboard opening left less height than the fixed-size fields above
          // the message box needed, and the Column overflowed instead of
          // shrinking. Scrolling is the backstop: whatever the keyboard takes,
          // the reader can still reach every field by scrolling instead of the
          // layout breaking.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                    focusNode: _authorFocusNode,
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

                // minLines/maxLines rather than Expanded+expands:true: this
                // field now lives in a SingleChildScrollView, which gives its
                // children unbounded height — Expanded needs a bounded parent
                // and would assert. Sizing to its own content (with a floor
                // and a cap) is also what the fullscreen editor below already
                // does successfully under the same keyboard-inset pressure.
                Stack(
                  children: [
                    _FieldShell(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16, 16, 44, 16,
                      ),
                      borderColor: _messageError != null
                          ? const Color(0xFFB3261E)
                          : null,
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 6,
                        maxLines: 12,
                        textAlignVertical: TextAlignVertical.top,
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
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: TapTarget(
                        onTap: _openExpandedEditor,
                        semanticLabel: 'تكبير مربع النص',
                        minSize: 32,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surfaceSunken,
                          ),
                          child: Icon(
                            Icons.open_in_full_rounded,
                            size: 15,
                            color: palette.goldText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_messageError != null) ...[
                  const SizedBox(height: 8),
                  _InlineError(_messageError!),
                ],
              ],
            ),
          ),
        ),

        // Pinned outside the scroll area so the submit button stays put
        // instead of travelling with the fields above it.
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            // The bottom nav bar's own height only needs reserving when the
            // bar is actually floating over the content, at the very bottom
            // of the screen. Once a field is focused the keyboard covers the
            // bar instead, and the Scaffold has already shifted this button
            // up to sit right above the keyboard — adding the bar's height on
            // top of that left a tall dead gap of background art between the
            // button and the keyboard.
            12 +
                (_keyboardLikelyOpen
                    ? 0
                    : BottomNavigation.reservedHeight(context)),
          ),
          child: AppButton(
            text: _submitting ? 'جارٍ الإرسال…' : 'إرسال الرسالة 🌿',
            icon: _submitting ? null : Icons.send_rounded,
            onPressed: _submitting ? () {} : () => _submit(),
          ),
        ),
      ],
      ),
    );
  }

  Future<void> _openExpandedEditor() async {
    final palette = context.palette;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.listItem),
        ),
        // A Dialog already folds the keyboard's inset into the space it
        // gives its child, but a *fixed* fraction-of-screen SizedBox for the
        // field (the previous approach) doesn't shrink along with that —
        // the moment the keyboard opened, the field + label + button no
        // longer fit and the Column overflowed by however tall the keyboard
        // was, on every phone. minLines/maxLines lets the field size itself
        // instead of demanding a fixed height, and the SingleChildScrollView
        // is a hard backstop: whatever's left over after the keyboard takes
        // its share, this scrolls rather than overflows, on any device.
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Label('نص الرسالة أو التأمل'),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  minLines: 8,
                  maxLines: 16,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
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
                    filled: true,
                    fillColor: palette.surfaceSunken,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.listItem),
                      borderSide: BorderSide(color: palette.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  text: 'تم',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
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
