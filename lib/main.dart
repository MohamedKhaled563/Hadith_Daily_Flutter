import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_state_controller.dart';
import 'core/widgets/smooth_page_route.dart';
import 'data/repositories/hadith_repository.dart';
import 'data/services/daily_tip_service.dart';
import 'data/services/notification_scheduler.dart';
import 'features/messages/daily_message_screen.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

/// Lets [NotificationScheduler.notificationTapped] open today's message
/// regardless of what screen is currently showing — a cold-start tap
/// instead goes through SplashScreen (see its own launch check), since
/// there's no live Navigator yet for that case.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every primary screen (Home, Community, Favorites, Daily Message, Share)
  // is built around a portrait-shaped hero layout with a fixed-height bottom
  // nav bar — in landscape the nav bar overlaps that content instead of
  // reflowing. Locking orientation avoids that rather than requiring every
  // screen in the app to be redesigned for a mode that gives a single-column
  // Arabic reading app no benefit anyway.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // AppStateController.init() reads FirebaseAuth.currentUser, so it must run
  // after Firebase is ready.
  await Future.wait([
    HadithRepository().load(),
    AppStateController().init(),
  ]);
  NotificationScheduler.notificationTapped.addListener(_openTodayMessage);
  runApp(const HadithApp());
}

/// Tapping a reminder always opens today's actual daily/community messages
/// (the same content the home screen's heart button shows) — never the
/// reminder pool's own generic text, which the reader never associated
/// with a specific "message" in the first place. A day can hold several
/// messages now; the tap lands on the first and the rest are a swipe away.
void _openTodayMessage() async {
  final tips = await DailyTipService().getTodayTips();
  if (tips.isEmpty) return;
  final repo = HadithRepository();

  final navState = navigatorKey.currentState;
  if (navState == null) return;
  navState.push(
    SeamlessMessagePageRoute(
      child: DailyMessageScreen.forDay(
        entries: [
          for (final tip in tips)
            DailyMessageEntry(
              insight: tip.toInsight(),
              hadith: repo.getByNumber(tip.hadithNumber),
            ),
        ],
      ),
    ),
  );
}

class HadithApp extends StatelessWidget {
  const HadithApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateController();

    return AnimatedBuilder(
      animation: state,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'طيّب قلبك',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // Compose the in-app reading-size preference with the reader's OS
            // text-size setting rather than discarding it, then clamp the
            // result so layouts stay intact at the extremes.
            final osScaler = MediaQuery.textScalerOf(context);
            final combined = osScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.6 / state.fontSizeScale,
            );

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: _ScaledTextScaler(combined, state.fontSizeScale),
              ),
              child: child!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

/// Applies the user's in-app reading-size multiplier on top of whatever the
/// platform scaler already resolved.
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this._base, this._factor);

  final TextScaler _base;
  final double _factor;

  @override
  double scale(double fontSize) => _base.scale(fontSize) * _factor;

  // Deprecated on TextScaler but still abstract, so it must be implemented.
  // Nothing in this app reads it — `scale` above is the live path.
  @Deprecated('Use scale instead')
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => _base.textScaleFactor * _factor;
}
