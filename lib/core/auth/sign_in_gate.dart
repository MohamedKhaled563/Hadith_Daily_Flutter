import 'package:flutter/material.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../theme/app_palette.dart';
import '../theme/app_state_controller.dart';
import '../widgets/app_button.dart';
import '../widgets/asset_helper.dart';
import '../widgets/botanical_sheet.dart';
import '../widgets/smooth_page_route.dart';

/// Asks a guest to sign in, at the moment it actually matters.
///
/// The app used to route straight to the login screen from the splash, so the
/// first thing a new install saw was a form — before a single hadith. Nothing
/// on the home screen, the hadith list or the reading screens needs an
/// identity; everything the reader browses is public-read. Only four things
/// genuinely need to know who you are: saving a favourite (favourites belong
/// to the account, not the phone), liking something, posting to the
/// community, and writing to the moderators.
///
/// So the gate moved here. Call [requireSignIn] at those points and nowhere
/// else. It returns true if the reader is already signed in (the
/// common case, and it does not interrupt them), or if they signed in just
/// now; false if they dismissed it, in which case the caller should simply do
/// nothing rather than show an error — declining is not a failure.
/// The [requireSignIn] reason for every bookmark control, so they all say it
/// the same way.
const kFavoritesSignInReason =
    'سجّل الدخول لتُحفظ مفضلتك في حسابك وتجدها على أي جهاز.';

Future<bool> requireSignIn(
  BuildContext context, {
  /// One line saying what signing in unlocks, in the reader's own terms.
  /// "So your likes follow you to your next phone", not "auth required".
  required String reason,
}) async {
  if (AppStateController().isLoggedIn) return true;

  final signedIn = await showBotanicalSheet<bool>(
    context: context,
    title: 'يحتاج هذا إلى حساب',
    subtitle: reason,
    child: const _SignInPrompt(),
  );

  return signedIn ?? false;
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // The sheet pops with the sign-in result so the caller can carry on with
    // whatever the reader was doing, instead of dropping them somewhere else
    // and making them find their way back.
    Future<void> go(Widget screen) async {
      final result = await Navigator.push<bool>(
        context,
        appPageRoute(child: screen),
      );
      if (!context.mounted) return;
      Navigator.pop(context, result ?? AppStateController().isLoggedIn);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.cardBorderStrong, width: 1.5),
            ),
            child: AssetHelper.assetOrFallback(
              assetPath: 'assets/images/heart_leaf_emblem.png',
              width: 46,
              height: 46,
              fallback: Icon(
                Icons.favorite_rounded,
                color: palette.goldText,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'بالحساب تبقى مفضلتك وإعجاباتك معك على أي جهاز، وتستطيع المشاركة '
          'في مجتمع الحديث.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: 22),
        AppButton(
          text: 'تسجيل الدخول',
          icon: Icons.login_rounded,
          onPressed: () => go(const LoginScreen(returnOnSuccess: true)),
        ),
        const SizedBox(height: 10),
        AppButton(
          text: 'إنشاء حساب جديد',
          isSecondary: true,
          onPressed: () => go(const SignUpScreen(returnOnSuccess: true)),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: palette.mutedText,
          ),
          child: const Text('ليس الآن'),
        ),
      ],
    );
  }
}
