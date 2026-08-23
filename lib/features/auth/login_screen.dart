import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';

/// PLACEHOLDER sign-in screen.
///
/// Validates against the hardcoded demo credentials in [AppStateController].
/// This is scaffolding for the real auth flow, not a secure login — see the
/// warning on `AppStateController.signIn`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AppStateController _state = AppStateController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  // The panel settles in rather than snapping into place. Short and eased —
  // enough to feel considered, not enough to delay anyone signing in.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
  );

  late final Animation<Offset> _rise = Tween(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(
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
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Stands in for the network round-trip the real service will make, so the
    // loading state is exercised now rather than bolted on later.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final signedIn = _state.signIn(username: username, password: password);

    if (!signedIn) {
      setState(() {
        _submitting = false;
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      SmoothPageRoute(child: const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      showBottomLandscape: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Brand(),

                  const SizedBox(height: 24),

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
                                'تسجيل الدخول',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أهلاً بك من جديد في مجتمع طيّب قلبك',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 22),
                            _Field(
                              controller: _usernameController,
                              label: 'اسم المستخدم',
                              hint: 'admin',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              enabled: !_submitting,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              onChanged: _clearError,
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              label: 'كلمة المرور',
                              // Not a row of dots: an obscured field renders
                              // its value as dots too, so a dotted hint is
                              // indistinguishable from actual content.
                              hint: 'أدخل كلمة المرور',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !_submitting,
                              onSubmitted: (_) => _submit(),
                              onChanged: _clearError,
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
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              _ErrorNote(message: _error!),
                            ],
                            const SizedBox(height: 22),
                            AppButton(
                              text: _submitting ? 'جارٍ الدخول…' : 'دخول',
                              icon: _submitting ? null : Icons.login_rounded,
                              onPressed: _submitting ? () {} : _submit,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        SmoothPageRoute(
                                          child: const SignUpScreen(),
                                        ),
                                      ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                foregroundColor: palette.goldText,
                              ),
                              child: const Text(
                                'ليس لديك حساب؟ أنشئ حساباً جديداً',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DemoHint(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // No closing line here: any text below the card sits over
                  // the landscape photograph, where it cannot hold contrast.
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            border: Border.all(color: palette.cardBorderStrong, width: 1.6),
            boxShadow: AppElevation.card,
          ),
          child: Hero(
            tag: 'heart_leaf_emblem_hero',
            child: AssetHelper.assetOrFallback(
              assetPath: 'assets/images/heart_leaf_emblem.png',
              width: 62,
              height: 62,
              fallback: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primaryGreen,
                size: 44,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'طيّب قلبك',
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: context.isDarkMode
                ? AppColors.primaryTextDark
                : AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        AssetHelper.assetOrFallback(
          assetPath: 'assets/images/golden_divider.png',
          width: 110,
          height: 16,
          fallback: Container(
            width: 60,
            height: 1.5,
            color: const Color(0xFFD6BE88),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 13,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
            color: palette.goldText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
          decoration: BoxDecoration(
            // Translucent so the glass behind reads through the field rather
            // than the field sitting on the panel as an opaque patch.
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.75),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.goldText),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  enabled: enabled,
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  // Credentials are Latin; force LTR so the caret and text sit
                  // correctly inside an otherwise RTL layout.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 14,
                    color: palette.bodyText,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintTextDirection: TextDirection.ltr,
                    hintStyle: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      color: palette.mutedText,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
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
          color: _error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.listItem),
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

/// Visible reminder that this is placeholder auth. Delete with the demo
/// credentials once the real service is wired up.
class _DemoHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.listItem),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: palette.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'نسخة تجريبية — ${AppStateController.demoHint}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11.5,
                height: AppLeading.body,
                fontWeight: FontWeight.w600,
                color: palette.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
