import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Confirms the signed-in emulator account's email, as the verifyEmailCode
/// function does after a right code, then refreshes the ID token so the
/// security rules see `email_verified: true`.
///
/// Since phase 21 the rules refuse posts, likes, reports, feedback and board
/// scores from an unconfirmed address, so every test account that does any
/// of those needs this right after it is created. The code flow itself is
/// tested end to end in functions/test/e2e.mjs.
///
/// Emulator only: the Auth emulator accepts "Bearer owner" as an admin.
Future<void> confirmEmailInEmulator(String host) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser!;
  // The project the SDK really talks to — on Android the default app comes
  // from google-services.json, whatever --project the emulators run under.
  final project = auth.app.options.projectId;
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(
      'http://$host:9099/identitytoolkit.googleapis.com/v1/'
      'projects/$project/accounts:update',
    ));
    request.headers
      ..set('Authorization', 'Bearer owner')
      ..contentType = ContentType.json;
    request.write(jsonEncode({'localId': user.uid, 'emailVerified': true}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('accounts:update ${response.statusCode}: $body');
    }
  } finally {
    client.close();
  }
  await user.reload();
  await auth.currentUser!.getIdToken(true);
}
