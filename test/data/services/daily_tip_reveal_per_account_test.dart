import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/daily_tip_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How far a reader has gone through رسائل اليوم belongs to the account, not
/// the phone. It used to be one SharedPreferences entry per device, so a
/// second account signing in on the same phone opened straight on the last
/// message the first account had reached.
void main() {
  String? uid;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = null;
    DailyTipService.debugCurrentUid = () => uid;
  });

  tearDown(() => DailyTipService.debugCurrentUid = null);

  test('a second account on the same phone starts the day afresh', () async {
    final service = DailyTipService();

    uid = 'account-a';
    await service.saveRevealedCount(1);
    await service.saveRevealedCount(2);
    await service.saveRevealedCount(3);
    expect(await service.revealedCount(), 3);

    uid = 'account-b';
    expect(await service.revealedCount(), 0);
    await service.saveRevealedCount(1);
    expect(await service.revealedCount(), 1);

    uid = 'account-a';
    expect(await service.revealedCount(), 3);
  });

  test('signed out keeps its own count, apart from any account', () async {
    final service = DailyTipService();

    uid = 'account-a';
    await service.saveRevealedCount(2);

    uid = null;
    expect(await service.revealedCount(), 0);
    await service.saveRevealedCount(1);

    uid = 'account-a';
    expect(await service.revealedCount(), 2);
  });
}
