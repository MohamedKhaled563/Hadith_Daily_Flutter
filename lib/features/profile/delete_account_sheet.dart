import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/services/account_deletion_service.dart';
import '../auth/auth_error_messages.dart';

/// The account-deletion flow: say exactly what goes, make them confirm it in
/// their own words, re-authenticate, then wipe.
///
/// Deliberately not a one-tap "are you sure?" — this is the only irreversible
/// action in the app, and it takes content other readers may have liked with
/// it. The typed confirmation is there because a destructive default button
/// is too easy to hit by muscle memory, and because a reader who cannot bring
/// themselves to type the word probably did not mean to be here.
///
/// Returns true when the account was deleted, so the caller can drop the
/// navigation stack.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final service = AccountDeletionService();

  final result = await showBotanicalSheet<bool>(
    context: context,
    title: 'حذف الحساب',
    subtitle: 'إجراء نهائي لا يمكن التراجع عنه',
    child: DeleteAccountForm(
      method: service.reauthMethod,
      onConfirm: (password, onProgress) async {
        await service.reauthenticate(password: password);
        await service.deleteAccount(onProgress: onProgress);
      },
    ),
  );
  return result ?? false;
}

/// The sheet's body, with the account work behind a callback.
///
/// Public and Firebase-free on purpose: the typed-confirmation gate is the
/// only thing standing in front of the one irreversible action in the app, so
/// it is worth a test, and a form that reached for `FirebaseAuth.instance`
/// itself could not be pumped in one.
@visibleForTesting
class DeleteAccountForm extends StatefulWidget {
  const DeleteAccountForm({
    super.key,
    required this.method,
    required this.onConfirm,
  });

  /// Which credential the account re-authenticates with, which decides
  /// whether the password field is shown at all.
  final ReauthMethod method;

  /// Re-authenticates and deletes. Throws to report failure; the sheet turns
  /// that into an inline message rather than a half-finished delete.
  final Future<void> Function(
    String? password,
    void Function(String step) onProgress,
  ) onConfirm;

  @override
  State<DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<DeleteAccountForm> {
  /// What the reader has to type. Short, unambiguous, and not a word they
  /// would produce by accident.
  static const _confirmWord = 'حذف';

  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  bool get _confirmed =>
      _confirmController.text.trim() == _confirmWord;

  bool get _needsPassword => widget.method == ReauthMethod.password;

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (!_confirmed) {
      setState(() => _error = 'اكتب كلمة «$_confirmWord» للتأكيد');
      return;
    }
    if (_needsPassword && _passwordController.text.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور لتأكيد هويتك');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // The overlay is shown over the *page*, not the sheet: the sheet is about
    // to be popped, and an overlay attached to it would go with it while the
    // deletion is still running.
    final pageContext = Navigator.of(context, rootNavigator: true).context;
    showAppLoadingOverlay(pageContext, message: 'جارٍ تأكيد هويتك…');

    try {
      await widget.onConfirm(
        _needsPassword ? _passwordController.text : null,
        (step) {
          hideAppLoadingOverlay();
          showAppLoadingOverlay(pageContext, message: step);
        },
      );

      hideAppLoadingOverlay();
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      hideAppLoadingOverlay();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _deleteErrorMessage(e);
      });
    } catch (error) {
      hideAppLoadingOverlay();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر إتمام الحذف، تحقق من الاتصال وحاول مرة أخرى';
      });
      debugPrint('account deletion failed: $error');
    }
  }

  String _deleteErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'cancelled-by-user':
        return 'لم يكتمل تأكيد الهوية';
      case 'requires-recent-login':
        return 'انتهت صلاحية الجلسة، سجّل الخروج وادخل مجدداً ثم أعد المحاولة';
      case 'unsupported-provider':
        return 'طريقة الدخول هذه لا تدعم الحذف من داخل التطبيق، راسلنا لنساعدك';
      default:
        return authErrorMessage(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.dangerWash,
            borderRadius: BorderRadius.circular(AppRadii.listItem),
            border: Border.all(
              color: palette.danger.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: palette.danger,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'سيُحذف نهائياً',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final line in const [
                'حسابك وبريدك واسمك المعروض',
                'كل رسائلك المنشورة في المجتمع',
                'كل إعجاباتك',
                'كل ملاحظاتك المرسلة إلينا',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          line,
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.bodyText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'سيتحرر اسمك المعروض ليستخدمه قارئ آخر. محفوظاتك المحلية على '
                'هذا الجهاز تبقى كما هي.',
                style: textTheme.bodySmall?.copyWith(
                  color: palette.mutedText,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        const _Label('اكتب «$_confirmWord» للتأكيد'),
        const SizedBox(height: 6),
        _Field(
          controller: _confirmController,
          hint: _confirmWord,
          enabled: !_busy,
          onChanged: (_) => setState(() => _error = null),
        ),

        if (_needsPassword) ...[
          const SizedBox(height: 14),
          const _Label('كلمة المرور'),
          const SizedBox(height: 6),
          _Field(
            controller: _passwordController,
            hint: 'أدخل كلمة المرور',
            enabled: !_busy,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() => _error = null),
            trailing: TapTarget(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              semanticLabel:
                  _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
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
        ] else if (widget.method == ReauthMethod.google) ...[
          const SizedBox(height: 12),
          Text(
            'سيُطلب منك تأكيد هويتك عبر Google قبل الحذف.',
            style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: palette.danger),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Destructive confirm stays visually secondary and disabled until the
        // word is typed, so the safe path is the one that reads as default.
        _DestructiveButton(
          label: 'حذف حسابي نهائياً',
          enabled: _confirmed && !_busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        AppButton(
          text: 'إلغاء',
          isSecondary: true,
          onPressed: _busy ? null : () => Navigator.pop(context, false),
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
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 12.5,
          height: AppLeading.chrome,
          fontWeight: FontWeight.w700,
          color: context.palette.goldText,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onChanged,
    this.obscureText = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.listItem),
        border: Border.all(color: palette.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscureText,
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                color: palette.bodyText,
              ),
              decoration: InputDecoration(
                hintText: hint,
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
    );
  }
}

/// A filled button in the danger role, with a real disabled state.
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.danger,
        // danger is a light tone in dark mode and a deep one in light mode,
        // so the ink flips with it rather than being a fixed white.
        foregroundColor: isDark ? const Color(0xFF2B1917) : Colors.white,
        disabledBackgroundColor: palette.dangerWash,
        disabledForegroundColor: palette.mutedText,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        textStyle: AppTextStyles.buttonText,
        shape: const StadiumBorder(),
      ),
    );
  }
}
