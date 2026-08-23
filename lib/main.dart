import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_state_controller.dart';
import 'data/repositories/hadith_repository.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HadithRepository().load();
  runApp(const HadithApp());
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
