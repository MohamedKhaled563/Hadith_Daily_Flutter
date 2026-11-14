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
    // Google sign-in with an address that already has a password account.
    // Used to fall through to "unexpected error", which left the owner of
    // the address with no idea what to do next.
    case 'account-exists-with-different-credential':
      return 'لهذا البريد حساب بكلمة مرور، ادخل بها أو أعد تعيينها من «نسيت كلمة المرور»';
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
