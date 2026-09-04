// Entry point for the moderator/admin dashboard — built with `flutter build
// web -t lib/main_dashboard.dart`, deployed separately from the phone app.
// The phone app's own lib/main.dart is untouched; this reuses the same
// Firestore models and services (CommunityPost, CommunityService, ...) but
// nothing else about the mobile UI.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/dashboard/dashboard_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DashboardApp());
}
