import 'package:firebase_auth/firebase_auth.dart';

/// Arabic-language message for a [FirebaseAuthException], for the login and
/// sign-up screens to show under the form.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'صيغة البريد الإلكتروني غير صحيحة';
    case 'user-disabled':
      return 'تم تعطيل هذا الحساب';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    case 'email-already-in-use':
      return 'هذا البريد الإلكتروني مستخدم بالفعل';
    case 'weak-password':
      return 'كلمة المرور ضعيفة جداً';
    case 'too-many-requests':
      return 'محاولات كثيرة جداً، حاول لاحقاً';
    case 'network-request-failed':
      return 'تعذّر الاتصال بالشبكة، تحقق من الإنترنت';
    default:
      return 'حدث خطأ غير متوقع، حاول مرة أخرى';
  }
}
