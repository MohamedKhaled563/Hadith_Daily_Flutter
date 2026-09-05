import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../home/home_screen.dart';
import 'auth_error_messages.dart';

/// How the reader wants to register.
enum _SignUpMethod { email, mobile }

/// Real sign-up screen: email/password creates a Firebase account; Google
/// signs in via the official `google_sign_in` flow. Phone sign-up is deferred
/// (SMS verification is the one part of Firebase Auth that isn't free) and
/// still shows as "coming soon".
///
/// The Google mark drawn below is a neutral stand-in rather than an
/// approximation of Google's actual logo, which their brand guidelines
/// reserve for their own supplied assets.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();

  _SignUpMethod _method = _SignUpMethod.email;
  bool _obscurePassword = true;
  bool _submitting = false;
  String _loadingMessage = 'جارٍ إنشاء الحساب…';
  bool _acceptedTerms = false;
  String? _error;
  String? _nameError;
  Timer? _nameCheckDebounce;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
  );

  late final Animation<Offset> _rise =
      Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
    CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _nameCheckDebounce?.cancel();
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isEmail => _method == _SignUpMethod.email;

  /// Live, debounced duplicate check as the reader types — applies
  /// regardless of the chosen method (email or phone), since the name field
  /// is shared between both. This is UX feedback only; [_submit] always
  /// re-checks authoritatively right before creating the account.
  void _onNameChanged(String value) {
    _clearError(value);
    _nameCheckDebounce?.cancel();
    setState(() => _nameError = null);

    final name = value.trim();
    if (name.isEmpty) return;

    _nameCheckDebounce = Timer(const Duration(milliseconds: 500), () async {
      final taken = await AuthService.instance.isDisplayNameTaken(name);
      if (!mounted) return;
      if (name != _nameController.text.trim()) return;
      if (taken) {
        setState(() => _nameError = 'هذا الاسم مستخدم بالفعل، جرّب اسماً آخر');
      }
    });
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'أدخل اسمك أو لقبك';
    }
    if (_nameError != null) {
      return _nameError;
    }

    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      return _isEmail ? 'أدخل بريدك الإلكتروني' : 'أدخل رقم جوالك';
    }
    if (_isEmail && !contact.contains('@')) {
      return 'أدخل بريداً إلكترونياً صحيحاً';
    }
    if (!_isEmail && contact.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      return 'أدخل رقم جوال صحيحاً';
    }

    if (_passwordController.text.length < 6) {
      return 'كلمة المرور يجب ألا تقل عن ٦ أحرف';
    }
    if (!_acceptedTerms) {
      return 'وافق على شروط الاستخدام للمتابعة';
    }

    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_isEmail) {
      _comingSoon('رقم الجوال');
      return;
    }

    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _loadingMessage = 'جارٍ التحقق من الاسم…';
      _error = null;
    });

    final name = _nameController.text.trim();
    // Authoritative re-check right before creating the account — the live
    // check above is debounced and may be stale (e.g. submitted before it
    // ever fired). signUpWithEmail still re-checks via the security rules
    // themselves in case of a race after this point.
    final taken = await AuthService.instance.isDisplayNameTaken(name);
    if (!mounted) return;
    if (taken) {
      setState(() {
        _submitting = false;
        _nameError = 'هذا الاسم مستخدم بالفعل، جرّب اسماً آخر';
      });
      return;
    }

    setState(() => _loadingMessage = 'جارٍ إنشاء الحساب…');

    try {
      await AuthService.instance.signUpWithEmail(
        email: _contactController.text.trim(),
        password: _passwordController.text,
        displayName: name,
      );
    } on DisplayNameTakenException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameError = 'هذا الاسم مستخدم بالفعل، جرّب اسماً آخر';
      });
      return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = authErrorMessage(e);
      });
      return;
    }
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      SmoothPageRoute(child: const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _submitting = true;
      _loadingMessage = 'جارٍ الدخول عبر Google…';
      _error = null;
    });

    final UserCredential? credential;
    try {
      credential = await AuthService.instance.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = authErrorMessage(e);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'تعذّر إتمام تسجيل الدخول عبر Google';
      });
      return;
    }

    if (!mounted) return;
    if (credential == null) {
      // Reader dismissed the account picker — not an error.
      setState(() => _submitting = false);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      SmoothPageRoute(child: const HomeScreen()),
      (route) => false,
    );
  }

  void _comingSoon(String provider) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('التسجيل عبر $provider غير مفعّل في النسخة التجريبية')),
    );
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.palette;

    return AppLoadingOverlay(
      visible: _submitting,
      message: _loadingMessage,
      child: AppScreen(
        showBottomLandscape: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 32).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Brand(),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _rise,
                        child: GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'إنشاء حساب جديد',
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'انضم لمجتمع طيّب قلبك واحفظ تأملاتك',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                              ),
                              const SizedBox(height: 20),
                              ProviderButton(
                                label: 'المتابعة باستخدام Google',
                                icon: const GoogleMark(),
                                onTap: _submitting ? () {} : _submitGoogle,
                              ),
                              const SizedBox(height: 18),
                              const OrDivider(),
                              const SizedBox(height: 18),
                              _MethodToggle(
                                method: _method,
                                onChanged: (m) => setState(() {
                                  _method = m;
                                  _contactController.clear();
                                  _error = null;
                                }),
                              ),
                              const SizedBox(height: 18),
                              _Label('الاسم أو اللقب'),
                              const SizedBox(height: 6),
                              GlassField(
                                leading: Icon(
                                  Icons.person_outline_rounded,
                                  size: 20,
                                  color: palette.goldText,
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  enabled: !_submitting,
                                  textInputAction: TextInputAction.next,
                                  onChanged: _onNameChanged,
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 14,
                                    color: palette.bodyText,
                                  ),
                                  decoration: _inputDecoration(
                                    'مثال: محمد',
                                    palette.mutedText,
                                  ),
                                ),
                              ),
                              if (_nameError != null) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 4,
                                  ),
                                  child: Text(
                                    _nameError!,
                                    style: const TextStyle(
                                      fontFamily: kSans,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFB3261E),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _Label(_isEmail
                                  ? 'البريد الإلكتروني'
                                  : 'رقم الجوال'),
                              const SizedBox(height: 6),
                              GlassField(
                                leading: Icon(
                                  _isEmail
                                      ? Icons.mail_outline_rounded
                                      : Icons.phone_iphone_rounded,
                                  size: 20,
                                  color: palette.goldText,
                                ),
                                child: TextField(
                                  controller: _contactController,
                                  enabled: !_submitting,
                                  textInputAction: TextInputAction.next,
                                  onChanged: _clearError,
                                  keyboardType: _isEmail
                                      ? TextInputType.emailAddress
                                      : TextInputType.phone,
                                  // Both are Latin/numeric, so they read LTR
                                  // inside the otherwise RTL layout.
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 14,
                                    color: palette.bodyText,
                                  ),
                                  decoration: _inputDecoration(
                                    _isEmail
                                        ? 'name@example.com'
                                        : '05xxxxxxxx',
                                    palette.mutedText,
                                    ltrHint: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _Label('كلمة المرور'),
                              const SizedBox(height: 6),
                              GlassField(
                                leading: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                  color: palette.goldText,
                                ),
                                trailing: TapTarget(
                                  onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  semanticLabel: _obscurePassword
                                      ? 'إظهار كلمة المرور'
                                      : 'إخفاء كلمة المرور',
                                  toggled: !_obscurePassword,
                                  minSize: 44,
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: palette.mutedText,
                                  ),
                                ),
                                child: TextField(
                                  controller: _passwordController,
                                  enabled: !_submitting,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onChanged: _clearError,
                                  onSubmitted: (_) => _submit(),
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 14,
                                    color: palette.bodyText,
                                  ),
                                  decoration: _inputDecoration(
                                    '٦ أحرف على الأقل',
                                    palette.mutedText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _TermsCheck(
                                value: _acceptedTerms,
                                onChanged: (v) => setState(() {
                                  _acceptedTerms = v;
                                  if (v) _error = null;
                                }),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                _ErrorNote(message: _error!),
                              ],
                              const SizedBox(height: 20),
                              AppButton(
                                text: _submitting
                                    ? 'جارٍ الإنشاء…'
                                    : 'إنشاء الحساب',
                                icon: _submitting
                                    ? null
                                    : Icons.person_add_alt_rounded,
                                onPressed: _submitting ? () {} : _submit,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.maybePop(context),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  foregroundColor: palette.goldText,
                                ),
                                child: const Text(
                                  'لديك حساب بالفعل؟ تسجيل الدخول',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    Color hintColor, {
    bool ltrHint = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintTextDirection: ltrHint ? TextDirection.ltr : null,
      hintStyle: TextStyle(
        fontFamily: kSans,
        fontSize: 13,
        color: hintColor,
      ),
      border: InputBorder.none,
      isDense: true,
    );
  }
}

// ------------------------------------------------------------- fragments ----

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.method, required this.onChanged});

  final _SignUpMethod method;
  final ValueChanged<_SignUpMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget option(_SignUpMethod value, String label, IconData icon) {
      final selected = method == value;
      return Expanded(
        child: TapTarget(
          onTap: () => onChanged(value),
          semanticLabel: label,
          selected: selected,
          minSize: 44,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(
                      alpha: context.isDarkMode ? 0.10 : 0.72,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? palette.goldText : palette.mutedText,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      height: AppLeading.chrome,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? palette.bodyText : palette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: context.isDarkMode ? 0.04 : 0.30,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: context.isDarkMode ? 0.10 : 0.55,
          ),
        ),
      ),
      child: Row(
        children: [
          option(
              _SignUpMethod.email, 'بريد إلكتروني', Icons.mail_outline_rounded),
          option(_SignUpMethod.mobile, 'رقم جوال', Icons.phone_iphone_rounded),
        ],
      ),
    );
  }
}

class ProviderButton extends StatelessWidget {
  const ProviderButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return PressableSurface(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.95),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: palette.bodyText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral stand-in for the Google mark.
///
/// Google's brand guidelines require their own supplied button asset, and
/// drawing an approximation of another company's logo is not something to
/// ship. This is a placeholder to be replaced when `google_sign_in` is wired
/// up with the official asset.
class GoogleMark extends StatelessWidget {
  const GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.cardBorder, width: 1.2),
      ),
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: context.palette.mutedText,
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = Expanded(
      child: Container(height: 1, color: palette.cardBorder),
    );

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'أو',
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.mutedText,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _TermsCheck extends StatelessWidget {
  const _TermsCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      checked: value,
      label: 'أوافق على شروط الاستخدام وسياسة الخصوصية',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value
                        ? AppColors.primaryGreen
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color:
                          value ? AppColors.primaryGreen : palette.cardBorder,
                      width: 1.3,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أوافق على شروط الاستخدام وسياسة الخصوصية',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      height: AppLeading.body,
                      fontWeight: FontWeight.w600,
                      color: palette.bodyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  static const _error = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _error.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: _error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w600,
                  color: _error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            border: Border.all(color: palette.cardBorderStrong, width: 1.5),
            boxShadow: AppElevation.card,
          ),
          child: AssetHelper.assetOrFallback(
            assetPath: 'assets/images/heart_leaf_emblem.png',
            width: 52,
            height: 52,
            fallback: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primaryGreen,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'طيّب قلبك',
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: context.isDarkMode
                ? AppColors.primaryTextDark
                : AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}
