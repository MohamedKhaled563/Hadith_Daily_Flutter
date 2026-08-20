import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HadithApp());
}

class HadithApp extends StatelessWidget {
  const HadithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الأربعون النووية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      // RTL is enforced explicitly since app content is Arabic-only in V1.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
