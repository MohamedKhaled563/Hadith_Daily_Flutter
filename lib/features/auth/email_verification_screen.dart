import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../home/home_screen.dart';
import 'auth_error_messages.dart';
import 'login_screen.dart';

/// Shown right after email/password sign-up (and on any later sign-in where
/// the account still isn't verified) until the reader confirms the address
/// via the link Firebase emails them. Nothing in this app read
/// `emailVerified` before this screen existed, so an unverified account used
/// to sail straight into HomeScreen with no proof the inbox was real.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown -= 1;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthService.instance.resendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = 'تم إرسال رابط التحقق من جديد — تحقق من بريدك 🌿';
      });
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = authErrorMessage(e);
      });
    }
  }

  Future<void> _iVerified() async {
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    await AuthService.instance.reloadCurrentUser();
    if (!mounted) return;

    if (AuthService.instance.isEmailVerified) {
      Navigator.pushAndRemoveUntil(
        context,
        SmoothPageRoute(child: const HomeScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      _checking = false;
      _error = 'لم يتم التحقق من بريدك بعد، تحقق من صندوق الوارد أولاً';
    });
  }

  Future<void> _useDifferentAccount() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SmoothPageRoute(child: const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.palette;
    final email = AuthService.instance.currentUser?.email ?? '';
    final busy = _checking || _resending;

    return AppLoadingOverlay(
      visible: busy,
      message: _resending ? 'جارٍ إرسال الرابط…' : 'جارٍ التحقق…',
      child: AppScreen(
        showBottomLandscape: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: palette.goldText,
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    header: true,
                    child: Text(
                      'تحقق من بريدك الإلكتروني',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'أرسلنا رابط تفعيل إلى',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.bodyText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'افتح الرابط في بريدك، ثم اضغط "لقد تحققت من بريدي"',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _Note(message: _notice!, isError: false),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Note(message: _error!, isError: true),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    text: 'لقد تحققت من بريدي',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: busy ? () {} : _iVerified,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: (busy || _resendCooldown > 0) ? null : _resend,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: palette.goldText,
                    ),
                    child: Text(
                      _resendCooldown > 0
                          ? 'إعادة الإرسال بعد $_resendCooldown ثانية'
                          : 'إعادة إرسال رابط التحقق',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _useDifferentAccount,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: palette.mutedText,
                    ),
                    child: const Text(
                      'استخدام بريد إلكتروني آخر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
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

class _Note extends StatelessWidget {
  const _Note({required this.message, required this.isError});

  final String message;
  final bool isError;

  static const _errorColor = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    final color = isError ? _errorColor : context.palette.goldText;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
