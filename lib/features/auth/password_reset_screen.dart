import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/tap_target.dart';
import 'code_input.dart';
import 'email_typos.dart';

/// "Forgot password", by code: the reader gives their address, we email a
/// six-digit code from the app's own address, and they type it here with a
/// new password. Then they are signed straight in.
///
/// Replaces Firebase's reset link, which arrived in English from a
/// firebaseapp.com address and sent the reader off to a web page. Pops with
/// true once signed in, so the login screen can carry on as after any
/// sign-in.
///
/// The server answers the same whether or not the address has an account, so
/// the wording here never claims an account exists.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _codeSent = false;
  bool _sending = false;
  bool _resetting = false;
  bool _obscurePassword = true;
  String? _error;
  String? _notice;
  int _resendIn = 0;
  Timer? _countdown;

  bool get _busy => _sending || _resetting;

  @override
  void dispose() {
    _countdown?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = 'Ø£Ø¯Ø®Ù„ Ø¨Ø±ÙŠØ¯Ø§Ù‹ Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠØ§Ù‹ ØµØ­ÙŠØ­Ø§Ù‹');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });

    final EmailCodeSend result;
    try {
      result = await AuthService.instance.sendPasswordResetCode(email);
    } on FirebaseFunctionsException {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'ØªØ¹Ø°Ù‘Ø± Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ù…Ø² Ø§Ù„Ø¢Ù†ØŒ Ø­Ø§ÙˆÙ„ Ù…Ø±Ø© Ø£Ø®Ø±Ù‰ Ø¨Ø¹Ø¯ Ù‚Ù„ÙŠÙ„';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'ØªØ¹Ø°Ù‘Ø± Ø§Ù„Ø§ØªØµØ§Ù„ØŒ ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª ÙˆØ­Ø§ÙˆÙ„ Ù…Ø±Ø© Ø£Ø®Ø±Ù‰';
      });
      return;
    }
    if (!mounted) return;

    final wasSent = _codeSent;
    setState(() {
      _sending = false;
      _codeSent = true;
      if (result.status == EmailCodeSendStatus.wait) {
        _notice = 'Ø£Ø±Ø³Ù„Ù†Ø§ Ø±Ù…Ø²Ø§Ù‹ Ù‚Ø¨Ù„ Ù‚Ù„ÙŠÙ„ØŒ ÙˆÙŠÙ…ÙƒÙ† Ø·Ù„Ø¨ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯ Ø¨Ø¹Ø¯ '
            '${_formatWait(result.waitSeconds)}';
      } else if (wasSent) {
        _notice = 'Ø£Ø±Ø³Ù„Ù†Ø§ Ø±Ù…Ø²Ø§Ù‹ Ø¬Ø¯ÙŠØ¯Ø§Ù‹ØŒ ÙˆØ§Ù„Ø±Ù…Ø² Ø§Ù„Ø³Ø§Ø¨Ù‚ Ù„Ù… ÙŠØ¹Ø¯ ØµØ§Ù„Ø­Ø§Ù‹';
        _codeController.clear();
      }
    });
    _startCountdown(result.waitSeconds);
    _codeFocus.requestFocus();
  }

  Future<void> _reset() async {
    final code = _codeController.text;
    final password = _passwordController.text;
    if (code.length != 6) {
      setState(() => _error = 'Ø§Ù„Ø±Ù…Ø² Ø³ØªØ© Ø£Ø±Ù‚Ø§Ù…');
      _codeFocus.requestFocus();
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ± ÙŠØ¬Ø¨ Ø£Ù„Ø§ ØªÙ‚Ù„ Ø¹Ù† Ù¨ Ø£Ø­Ø±Ù');
      _passwordFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _resetting = true;
      _error = null;
      _notice = null;
    });

    final PasswordResetResult result;
    try {
      result = await AuthService.instance.resetPasswordWithCode(
        email: _emailController.text,
        code: code,
        newPassword: password,
      );
    } on FirebaseAuthException {
      // The password was saved; only the automatic sign-in after it failed.
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _error = 'Ø­ÙÙØ¸Øª ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ± Ø§Ù„Ø¬Ø¯ÙŠØ¯Ø©ØŒ Ù„ÙƒÙ† ØªØ¹Ø°Ù‘Ø± Ø§Ù„Ø¯Ø®ÙˆÙ„ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹. '
            'ÙŠÙ…ÙƒÙ† Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø¨Ù‡Ø§ Ø§Ù„Ø¢Ù† Ù…Ù† Ø´Ø§Ø´Ø© ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _error = 'ØªØ¹Ø°Ù‘Ø± Ø§Ù„Ø§ØªØµØ§Ù„ØŒ ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª ÙˆØ­Ø§ÙˆÙ„ Ù…Ø±Ø© Ø£Ø®Ø±Ù‰';
      });
      return;
    }
    if (!mounted) return;

    if (result.status == PasswordResetStatus.reset) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _resetting = false;
      _codeController.clear();
      _error = switch (result.status) {
        PasswordResetStatus.wrong =>
          'Ø§Ù„Ø±Ù…Ø² ØºÙŠØ± ØµØ­ÙŠØ­ØŒ ${_attemptsLeft(result.attemptsLeft)}',
        PasswordResetStatus.expired =>
          'Ø§Ù†ØªÙ‡Øª ØµÙ„Ø§Ø­ÙŠØ© Ù‡Ø°Ø§ Ø§Ù„Ø±Ù…Ø²ØŒ ÙˆÙŠÙ…ÙƒÙ† Ø·Ù„Ø¨ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯ Ù…Ù† Ø§Ù„Ø²Ø± Ø£Ø¯Ù†Ø§Ù‡',
        PasswordResetStatus.tooManyAttempts =>
          'Ø§Ù†ØªÙ‡Øª Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø§Øª Ø§Ù„Ù…ØªØ§Ø­Ø© Ù„Ù‡Ø°Ø§ Ø§Ù„Ø±Ù…Ø²ØŒ ÙˆÙŠÙ…ÙƒÙ† Ø·Ù„Ø¨ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯ Ù…Ù† Ø§Ù„Ø²Ø± Ø£Ø¯Ù†Ø§Ù‡',
        _ => 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø±Ù…Ø² ØµØ§Ù„Ø­ Ù„Ù‡Ø°Ø§ Ø§Ù„Ø¨Ø±ÙŠØ¯ØŒ ÙˆÙŠÙ…ÙƒÙ† Ø·Ù„Ø¨ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯ Ù…Ù† Ø§Ù„Ø²Ø± Ø£Ø¯Ù†Ø§Ù‡',
      };
    });
    _codeFocus.requestFocus();
  }

  void _editEmail() {
    _countdown?.cancel();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _error = null;
      _notice = null;
      _codeController.clear();
    });
  }

  static String _attemptsLeft(int left) => switch (left) {
        1 => 'Ø¨Ù‚ÙŠØª Ù…Ø­Ø§ÙˆÙ„Ø© ÙˆØ§Ø­Ø¯Ø©',
        2 => 'Ø¨Ù‚ÙŠØª Ù…Ø­Ø§ÙˆÙ„ØªØ§Ù†',
        _ => 'Ø¨Ù‚ÙŠØª ${toArabicDigits(left)} Ù…Ø­Ø§ÙˆÙ„Ø§Øª',
      };

  static String _formatWait(int seconds) {
    if (seconds < 60) return '${toArabicDigits(seconds)} Ø«Ø§Ù†ÙŠØ©';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '${toArabicDigits(minutes)} Ø¯Ù‚ÙŠÙ‚Ø©';
    return '${toArabicDigits((minutes / 60).ceil())} Ø³Ø§Ø¹Ø©';
  }

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppLoadingOverlay(
      visible: _busy,
      message: _resetting ? 'Ø¬Ø§Ø±Ù Ø­ÙØ¸ ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ±â€¦' : 'Ø¬Ø§Ø±Ù Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ù…Ø²â€¦',
      child: AppScreen(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 36).clamp(0, double.infinity),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          size: 40,
                          color: palette.goldText,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          child: Text(
                            _codeSent ? 'ÙƒÙ„Ù…Ø© Ù…Ø±ÙˆØ± Ø¬Ø¯ÙŠØ¯Ø©' : 'Ù†Ø³ÙŠØª ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ±ØŸ',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!_codeSent) ..._emailStep(palette, textTheme),
                        if (_codeSent) ..._codeStep(palette, textTheme),
                        if (_error != null || _notice != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ?? _notice!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _error != null
                                    ? const Color(0xFFB3261E)
                                    : palette.goldText,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        AppButton(
                          text: _codeSent ? 'Ø­ÙØ¸ ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ± ÙˆØ§Ù„Ø¯Ø®ÙˆÙ„' : 'Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ù…Ø²',
                          icon: _codeSent ? Icons.check_rounded : Icons.send_rounded,
                          onPressed: _busy ? null : (_codeSent ? _reset : _send),
                        ),
                        const SizedBox(height: 10),
                        if (_codeSent) ...[
                          _LinkButton(
                            text: _resendIn > 0
                                ? 'Ø¥Ø±Ø³Ø§Ù„ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯ Ø¨Ø¹Ø¯ ${_resendIn > 600 ? _formatWait(_resendIn) : _clock(_resendIn)}'
                                : 'Ø¥Ø±Ø³Ø§Ù„ Ø±Ù…Ø² Ø¬Ø¯ÙŠØ¯',
                            color: palette.goldText,
                            onPressed: _busy || _resendIn > 0 ? null : _send,
                          ),
                          _LinkButton(
                            text: 'ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„Ø¨Ø±ÙŠØ¯',
                            color: palette.mutedText,
                            onPressed: _busy ? null : _editEmail,
                          ),
                        ],
                        _LinkButton(
                          text: 'Ø±Ø¬ÙˆØ¹ Ø¥Ù„Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„',
                          color: palette.mutedText,
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context, false),
                        ),
                      ],
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

  List<Widget> _emailStep(BotanicalPalette palette, TextTheme textTheme) => [
        Text(
          'Ø§ÙƒØªØ¨ Ø¨Ø±ÙŠØ¯ Ø­Ø³Ø§Ø¨ÙƒØŒ ÙˆØ³Ù†Ø±Ø³Ù„ Ø¥Ù„ÙŠÙ‡ Ø±Ù…Ø²Ø§Ù‹ Ù…Ù† Ø³ØªØ© Ø£Ø±Ù‚Ø§Ù… Ù„Ø§Ø®ØªÙŠØ§Ø± ÙƒÙ„Ù…Ø© '
          'Ù…Ø±ÙˆØ± Ø¬Ø¯ÙŠØ¯Ø©.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        GlassField(
          leading: Icon(
            Icons.mail_outline_rounded,
            size: 20,
            color: palette.goldText,
          ),
          child: TextField(
            controller: _emailController,
            enabled: !_busy,
            autofocus: widget.initialEmail.isEmpty,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.username],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              color: palette.bodyText,
            ),
            decoration: InputDecoration(
              hintText: 'name@example.com',
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
      ];

  List<Widget> _codeStep(BotanicalPalette palette, TextTheme textTheme) => [
        Text(
          'Ø¥Ù† ÙƒØ§Ù† Ù„Ù‡Ø°Ø§ Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø­Ø³Ø§Ø¨ ÙÙ‚Ø¯ Ø£Ø±Ø³Ù„Ù†Ø§ Ø¥Ù„ÙŠÙ‡ Ø±Ù…Ø²Ø§Ù‹ Ù…Ù† Ø³ØªØ© Ø£Ø±Ù‚Ø§Ù…:',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          _emailController.text.trim(),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.bodyText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ÙŠØµÙ„ Ø¹Ø§Ø¯Ø©Ù‹ Ø®Ù„Ø§Ù„ Ø¯Ù‚ÙŠÙ‚Ø©ØŒ ÙˆØ¥Ù† ØªØ£Ø®Ø± ÙÙ‚Ø¯ ÙŠÙƒÙˆÙ† ÙÙŠ Ø§Ù„Ø±Ø³Ø§Ø¦Ù„ ØºÙŠØ± Ø§Ù„Ù…Ø±ØºÙˆØ¨ ÙÙŠÙ‡Ø§.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: 20),
        CodeField(
          controller: _codeController,
          focusNode: _codeFocus,
          enabled: !_busy,
          autofocus: true,
          // The code alone isn't enough here: the new password comes next.
          onComplete: (_) => _passwordFocus.requestFocus(),
          onEdited: () {
            if (_error != null) setState(() => _error = null);
          },
          onNothingToPaste: () => setState(() => _error =
              'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø±Ù…Ø² Ù…Ù†Ø³ÙˆØ®ØŒ Ø§Ù†Ø³Ø® Ø§Ù„Ø±Ù…Ø² Ù…Ù† Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø«Ù… Ø§Ø¶ØºØ· Â«Ù„ØµÙ‚ Ø§Ù„Ø±Ù…Ø²Â»'),
        ),
        const SizedBox(height: 10),
        GlassField(
          leading: Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: palette.goldText,
          ),
          trailing: TapTarget(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            semanticLabel:
                _obscurePassword ? 'Ø¥Ø¸Ù‡Ø§Ø± ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ±' : 'Ø¥Ø®ÙØ§Ø¡ ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ±',
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
            focusNode: _passwordFocus,
            enabled: !_busy,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _reset(),
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              color: palette.bodyText,
            ),
            decoration: InputDecoration(
              hintText: 'ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ± Ø§Ù„Ø¬Ø¯ÙŠØ¯Ø©ØŒ Ù¨ Ø£Ø­Ø±Ù Ø¹Ù„Ù‰ Ø§Ù„Ø£Ù‚Ù„',
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
      ];
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  final String text;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: color,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: kSans,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
