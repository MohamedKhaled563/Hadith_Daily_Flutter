import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/smooth_page_route.dart';
import 'code_input.dart';

/// How the reader left [EmailCodeScreen].
enum EmailCodeOutcome {
  /// The address is confirmed.
  verified,

  /// "Not now", or the back button. Still signed in, still unconfirmed.
  later,

  /// The address was mistyped: the new account was deleted and the reader
  /// signed out, so they can sign up again with the right one.
  changeEmail,
}

/// Where an email/password reader types the six-digit code we emailed.
///
/// Sends a code as soon as it opens (the server refuses politely if one went
/// out in the last minute), then always pops with an [EmailCodeOutcome] —
/// it never navigates anywhere itself, so sign-up, sign-in and the sign-in
/// gate each decide what comes next.
class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({super.key});

  /// Opens the screen and returns how the reader left it.
  static Future<EmailCodeOutcome> open(BuildContext context) async {
    final outcome = await Navigator.push<EmailCodeOutcome>(
      context,
      appPageRoute(child: const EmailCodeScreen()),
    );
    return outcome ?? EmailCodeOutcome.later;
  }

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  bool _sending = false;
  bool _checking = false;
  bool _discarding = false;
  String? _error;
  String? _notice;
  int _resendIn = 0;
  Timer? _countdown;

  bool get _busy => _sending || _checking || _discarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send(firstOpen: true));
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
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

  Future<void> _send({bool firstOpen = false}) async {
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });

    final EmailCodeSend result;
    try {
      result = await AuthService.instance.sendEmailCode();
    } on FirebaseFunctionsException {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'تعذّر إرسال الرمز الآن، حاول مرة أخرى بعد قليل';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'تعذّر الاتصال، تحقق من الإنترنت وحاول مرة أخرى';
      });
      return;
    }
    if (!mounted) return;

    switch (result.status) {
      case EmailCodeSendStatus.verified:
        Navigator.pop(context, EmailCodeOutcome.verified);
        return;
      case EmailCodeSendStatus.sent:
        setState(() {
          _sending = false;
          if (!firstOpen) _notice = 'أرسلنا رمزاً جديداً، والرمز السابق لم يعد صالحاً';
        });
        _codeController.clear();
      case EmailCodeSendStatus.wait:
        setState(() {
          _sending = false;
          // On opening, a short wait just means a code went out moments ago
          // — the reader most likely came back from their inbox. A tap on
          // "send", or a long wait (the daily limit), deserves a word.
          if (!firstOpen || result.waitSeconds > 60) {
            _notice = 'يمكن طلب رمز جديد بعد ${_formatWait(result.waitSeconds)}';
          }
        });
    }
    _startCountdown(result.waitSeconds);
    _codeFocus.requestFocus();
  }

  Future<void> _check() async {
    final code = _codeController.text;
    if (code.length != 6) {
      setState(() => _error = 'الرمز ستة أرقام');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });

    final EmailCodeCheck result;
    try {
      result = await AuthService.instance.verifyEmailCode(code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'تعذّر الاتصال، تحقق من الإنترنت وحاول مرة أخرى';
      });
      return;
    }
    if (!mounted) return;

    if (result.status == EmailCodeCheckStatus.verified) {
      Navigator.pop(context, EmailCodeOutcome.verified);
      return;
    }

    setState(() {
      _checking = false;
      _codeController.clear();
      _error = switch (result.status) {
        EmailCodeCheckStatus.wrong =>
          'الرمز غير صحيح، ${_attemptsLeft(result.attemptsLeft)}',
        EmailCodeCheckStatus.expired =>
          'انتهت صلاحية هذا الرمز، ويمكن طلب رمز جديد من الزر أدناه',
        EmailCodeCheckStatus.tooManyAttempts =>
          'انتهت المحاولات المتاحة لهذا الرمز، ويمكن طلب رمز جديد من الزر أدناه',
        _ => 'لا يوجد رمز صالح الآن، ويمكن طلب رمز جديد من الزر أدناه',
      };
    });
    _codeFocus.requestFocus();
  }

  Future<void> _changeEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل البريد'),
        content: const Text(
          'سيُحذف هذا الحساب الجديد ليُنشأ من جديد بالبريد الصحيح، '
          'ويبقى الاسم متاحاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف وتعديل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _discarding = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthService.instance.discardUnverifiedAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _discarding = false;
        _error = 'تعذّر تعديل البريد الآن، حاول مرة أخرى بعد قليل';
      });
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, EmailCodeOutcome.changeEmail);
  }

  static String _attemptsLeft(int left) => switch (left) {
        1 => 'بقيت محاولة واحدة',
        2 => 'بقيت محاولتان',
        _ => 'بقيت ${toArabicDigits(left)} محاولات',
      };

  static String _formatWait(int seconds) {
    if (seconds < 60) return '${toArabicDigits(seconds)} ثانية';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '${toArabicDigits(minutes)} دقيقة';
    return '${toArabicDigits((minutes / 60).ceil())} ساعة';
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
    final email = AuthService.instance.currentUser?.email ?? '';

    return AppLoadingOverlay(
      visible: _busy,
      message: _discarding
          ? 'جارٍ حذف الحساب…'
          : (_checking ? 'جارٍ التحقق…' : 'جارٍ إرسال الرمز…'),
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
                          Icons.mark_email_unread_outlined,
                          size: 40,
                          color: palette.goldText,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          child: Text(
                            'تأكيد البريد',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'أرسلنا رمزاً من ستة أرقام إلى',
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
                        const SizedBox(height: 8),
                        Text(
                          'يصل عادةً خلال دقيقة، وإن تأخر فقد يكون في الرسائل '
                          'غير المرغوب فيها.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CodeField(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          enabled: !_busy,
                          autofocus: true,
                          onComplete: (_) => _check(),
                          onEdited: () {
                            if (_error != null) setState(() => _error = null);
                          },
                          onNothingToPaste: () => setState(() => _error =
                              'لا يوجد رمز منسوخ، انسخ الرمز من البريد ثم اضغط «لصق الرمز»'),
                        ),
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
                          text: 'تأكيد',
                          icon: Icons.check_rounded,
                          onPressed: _busy ? null : _check,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _busy || _resendIn > 0 ? null : _send,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: palette.goldText,
                          ),
                          child: Text(
                            _resendIn > 0
                                ? 'إرسال رمز جديد بعد ${_resendIn > 600 ? _formatWait(_resendIn) : _clock(_resendIn)}'
                                : 'إرسال رمز جديد',
                            style: const TextStyle(
                              fontFamily: kSans,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (AuthService.instance.canDiscardUnverifiedAccount)
                          TextButton(
                            onPressed: _busy ? null : _changeEmail,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: palette.mutedText,
                            ),
                            child: const Text(
                              'تعديل البريد',
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(
                                    context,
                                    EmailCodeOutcome.later,
                                  ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: palette.mutedText,
                          ),
                          child: const Text(
                            'ليس الآن',
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
}
