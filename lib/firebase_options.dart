// File generated manually to mirror `flutterfire configure` output, since the
// FlutterFire CLI isn't available in this environment. Values are copied
// verbatim from the google-services.json / GoogleService-Info.plist
// downloaded from the Firebase console (project hadithdaily-5fc06).
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Web is the moderator dashboard (lib/main_dashboard.dart) — the phone
    // app itself never runs as web. Its own Firebase Web app, registered
    // for exactly this, since Android/iOS options don't carry the
    // authDomain a browser-based Auth flow needs.
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA1jc9xLvrPYS-Svye4q8zXAhAAUhPZbj0',
    appId: '1:305295927502:web:2452f24d43584e82c8089f',
    messagingSenderId: '305295927502',
    projectId: 'hadithdaily-5fc06',
    authDomain: 'hadithdaily-5fc06.firebaseapp.com',
    storageBucket: 'hadithdaily-5fc06.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXAIksb0SkfQgEvbyvsWTEnZyH7WEmrMI',
    appId: '1:305295927502:android:4fe2d1ce3f3b828ec8089f',
    messagingSenderId: '305295927502',
    projectId: 'hadithdaily-5fc06',
    storageBucket: 'hadithdaily-5fc06.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyADXHJPjbXf9cI5LaQNcj3Ov0RwqP54euw',
    appId: '1:305295927502:ios:3f519d06a5117e7ec8089f',
    messagingSenderId: '305295927502',
    projectId: 'hadithdaily-5fc06',
    storageBucket: 'hadithdaily-5fc06.firebasestorage.app',
    iosClientId:
        '305295927502-4bqfmmrh77fbmjk4mqgd1b5fai0q2hnl.apps.googleusercontent.com',
    iosBundleId: 'com.prodktstudio.tayebqalbak',
  );
}
