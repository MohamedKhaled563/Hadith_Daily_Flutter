import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_state_controller.dart';
import 'data/repositories/hadith_repository.dart';
import 'data/services/moderation_service.dart';
import 'data/services/notification_lifecycle_refresher.dart';
import 'data/services/notification_scheduler.dart';
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
    // The community feed filters on this synchronously while building, so
    // it has to be in memory before the first frame.
    ModerationService().load(),
  ]);
  runApp(const HadithApp());
}

// Tapping a reminder used to push a message screen from here. It no longer
// does: today's message lives inline on the home tab and stays there once
// opened, so there is one place a message is shown rather than two that can
// drift apart. HomeScreen listens to NotificationScheduler.notificationTapped
// directly and brings itself to the front.

class HadithApp extends StatefulWidget {
  const HadithApp({super.key});

  @override
  State<HadithApp> createState() => _HadithAppState();
}

class _HadithAppState extends State<HadithApp> with WidgetsBindingObserver {
  /// Owns the rolling reminder window for the whole life of the app. This
  /// used to be a fire-and-forget call in a decorative home-screen widget's
  /// initState, which meant it ran once per cold start and never again —
  /// see [NotificationLifecycleRefresher] for what that cost.
  final _reminders = NotificationLifecycleRefresher();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminders.start();
  }

  @override
  void dispose() {
    _reminders.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The OS flipped light/dark. MaterialApp resolves ThemeMode.system on its
  /// own, but AppStateController.isDarkMode — which code outside the tree
  /// reads — does not, so anything watching it needs a rebuild.
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

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
