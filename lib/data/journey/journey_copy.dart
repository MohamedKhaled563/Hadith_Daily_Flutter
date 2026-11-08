/// Every word the journey says to a reader, in one place, so a person can
/// edit them without touching any logic.
///
/// The voice is one person talking to one person: a real detail from their
/// reading, one idea, no exclamation marks and no emoji. Past verbs without
/// vowels and «نكمل» include women readers, where «واصل» would not. Religious
/// wording here needs a qualified reviewer before release.
library;

import '../../core/utils/arabic_numerals.dart';
import 'journey_points.dart';

class JourneyMessage {
  const JourneyMessage({required this.title, required this.body});

  final String title;
  final String body;
}

class JourneyCopy {
  const JourneyCopy._();

  /// Shown after a hadith is finished, to open the writing screen.
  static const writePrompt =
      'ما أكثر جملة بقيت معك من هذا الحديث؟ اكتبها بكلماتك، فقد تنفع غيرك.';

  static const signInReason = 'سجّل الدخول لتبقى شجرتك معك على أي جهاز.';

  /// On every poster. A Status or a Story drops the caption and its link, so
  /// the image has to say how to find the app by itself.
  static const posterFindUs = 'ابحث عن «طيّب قلبك» في متجر التطبيقات';

  static const posterInvitation = 'اقرأ معي الأربعين النووية';

  static const posterReadToday = 'قرأته اليوم بشرحه';

  static String treeCaption(int count, String? link) {
    final progress = count == 0
        ? 'بدأت قراءة الأربعين النووية'
        : 'قرأت ${toArabicDigits(count)} من ٤٢ حديثاً من الأربعين النووية';
    return '$progress في تطبيق «طيّب قلبك»، فاقرأ معي.${_linkLine(link)}';
  }

  static String hadithCaption(String title, int number, String? link) =>
      '«$title»\nالحديث ${toArabicDigits(number)} من الأربعين النووية\n'
      'قرأته اليوم بشرحه في تطبيق «طيّب قلبك».${_linkLine(link)}';

  static String _linkLine(String? link) => link == null ? '' : '\n$link';

  /// The message for [milestone] hadiths. [lastTitle] is the hadith just
  /// read, and [days] how many reading days it took.
  static JourneyMessage milestone(
    int milestone, {
    required String lastTitle,
    required int days,
  }) {
    return switch (milestone) {
      5 => const JourneyMessage(
          title: 'صارت خمسة',
          body: 'خمسة أحاديث قرأتها كاملة، بنصّها وشرحها. لو توقفت هنا لكان '
              'خيراً، فكيف إذا أكملت؟ نلتقي عند السادس إن شاء الله.',
        ),
      10 => JourneyMessage(
          title: 'عشرة أحاديث، ما شاء الله',
          body: 'ما رأيك أن تحكي اليوم لأحد من أهلك ما فهمته من حديث '
              '«$lastTitle»؟ قد يفاجئك كم بقي معك.',
        ),
      20 => const JourneyMessage(
          title: 'بقي حديث واحد على النصف',
          body: 'عشرون حديثاً حتى الآن. الحديث القادم يضعك في منتصف الأربعين '
              'النووية تماماً، فما رأيك أن نصله غداً إن شاء الله؟',
        ),
      30 => const JourneyMessage(
          title: 'بقي اثنا عشر',
          body: 'ثلاثون حديثاً، وبقي اثنا عشر. في مثل هذا الموضع نستعجل '
              'النهاية عادةً، فلنقرأ ما بقي على مهل كما قرأنا ما قبله.',
        ),
      _ => JourneyMessage(
          title: 'ختمت الأربعين النووية',
          body: 'اثنان وأربعون حديثاً قرأتها واحداً واحداً بشرحها، في '
              '${arabicDayCount(days)}. نسأل الله أن ينفعك بما قرأت، وأن '
              'يجعله علماً نافعاً وعملاً صالحاً.',
        ),
    };
  }

  /// The morning reminder of a reader who has not read today.
  static JourneyMessage todaysHadith(String title, int minutes) =>
      JourneyMessage(
        title: 'حديث اليوم',
        body: '«$title»، ${arabicMinuteCount(minutes)} تقريباً.',
      );

  /// The evening reminder of a reader with a streak to keep.
  static JourneyMessage eveningStreak(int days) => JourneyMessage(
        title: 'لم نقرأ اليوم بعد',
        body: '${arabicDayCount(days, consecutive: true)}. '
            'حديث قصير قبل النوم؟',
      );

  /// The morning after a missed day that a grace day covered.
  static const graceUsed = JourneyMessage(
    title: 'لا بأس',
    body: 'فاتك أمس، وسلسلتك كما هي. نكمل اليوم؟',
  );

  /// A reader who has been away, with no mention of what they missed.
  static JourneyMessage placeKept(String title) => JourneyMessage(
        title: 'مكانك محفوظ',
        body: 'توقفنا عند «$title». نكمل حين يناسبك.',
      );

  /// The Friday morning reminder: the week so far, against the last.
  static JourneyMessage harvest({
    required int days,
    required int minutes,
    required int lastWeekMinutes,
  }) {
    final week = '${arabicDayCount(days)} و${arabicMinuteCount(minutes)} '
        'مع الحديث.';
    return JourneyMessage(
      title: 'حصاد الأسبوع',
      body: lastWeekMinutes > 0
          ? '$week الأسبوع الماضي كانت ${arabicMinuteCount(lastWeekMinutes)}.'
          : week,
    );
  }

  /// A writer's message has reached its hundredth reader.
  static const reach = JourneyMessage(
    title: 'وصلت رسالتك إلى ١٠٠ قارئ',
    body: 'كلمة كتبتها في دقيقة، وما زالت تصل.',
  );

  static const harvestInvitation = 'حصاد أسبوعي مع الحديث';

  static String harvestCaption(Harvest harvest, String? link) =>
      'هذا الأسبوع: ${arabicDayCount(harvest.days)} و'
      '${arabicMinuteCount(harvest.minutes)} مع الأربعين النووية في تطبيق '
      '«طيّب قلبك»، فاقرأ معي.${_linkLine(link)}';

  /// Memorizing. Plain about what the app can know: the reader says whether
  /// they had it, and the app keeps the dates.
  static JourneyMessage memoMilestone(int count, {required String lastTitle}) =>
      switch (count) {
        1 => JourneyMessage(
            title: 'أول حديث في حفظك',
            body: '«$lastTitle» معك الآن. نراجعه غداً، ثم تتباعد المراجعة.',
          ),
        5 => const JourneyMessage(
            title: 'خمسة أحاديث في حفظك',
            body: 'مراجعة قصيرة حين يحين موعدها تكفي لتبقى معك.',
          ),
        10 => JourneyMessage(
            title: 'عشرة أحاديث في حفظك',
            body: 'آخرها «$lastTitle». ما تكرره يبقى.',
          ),
        20 => const JourneyMessage(
            title: 'عشرون حديثاً في حفظك',
            body: 'قرابة نصف الأربعين، حديثاً بعد حديث.',
          ),
        _ => const JourneyMessage(
            title: 'حفظت الأحاديث كلها',
            body: 'اثنان وأربعون حديثاً. المراجعات تتباعد الآن حتى تثبت.',
          ),
      };

  /// After learning a hadith's last part, without a milestone.
  static JourneyMessage memorized(String title) => JourneyMessage(
        title: 'حفظت «$title»',
        body: 'نراجعه غداً، ثم تتباعد المراجعة شيئاً فشيئاً.',
      );

  /// After one part of a longer hadith.
  static JourneyMessage partLearned(int learned, int total) => JourneyMessage(
        title: 'حفظت الجزء ${toArabicDigits(learned)} من ${toArabicDigits(total)}',
        body: 'نكمل الجزء التالي في جلسة أخرى، اليوم أو غداً.',
      );

  /// After a review. [days] is null once the hadith is kept.
  static String reviewed({required bool remembered, int? days}) {
    if (days == null) return 'ثبت في حفظك، ولا مراجعة له بعد اليوم.';
    final when = days == 1 ? 'غداً' : 'بعد ${arabicDayCount(days)}';
    return remembered
        ? 'تذكرته. المراجعة القادمة $when.'
        : 'لا بأس، لهذا وُضعت المراجعة. نعود إليه $when.';
  }

  /// The morning reminder when a review is due.
  static JourneyMessage reviewDue(String title) => JourneyMessage(
        title: 'مراجعة قصيرة',
        body: 'هل ما زلت تذكر «$title»؟ دقيقة واحدة تكفي.',
      );

  /// The weekly board. Joining is optional and off until the reader turns it
  /// on, so every line here says what will be shown, and to whom.
  static const boardSignInReason =
      'سجّل الدخول لتظهر في لوحة الأسبوع، باسمك أو باسم «فاعل خير».';
  static const boardNote = 'النقاط تحسب نشاطك في التطبيق، لا أكثر.';
  static const boardNotYet =
      'لم تُنشر لوحة بعد. تُنشر يوم الجمعة حين يكثر القراء.';
  static const boardOff = 'اسمك لا يظهر لأحد ما دام هذا مغلقاً.';
  static const boardOn = 'يظهر الاسم الذي اخترته إن كان بين العشرة الأوائل '
      'حين تُنشر اللوحة يوم الجمعة. تستطيع الخروج متى شئت.';

  /// The reading week starting [saturday], as «٧ – ١٣ نوفمبر».
  static String boardWeek(String saturday) {
    final parts = saturday.split('-').map(int.parse).toList();
    final start = DateTime.utc(parts[0], parts[1], parts[2]);
    final end = start.add(const Duration(days: 6));
    final from = start.month == end.month
        ? toArabicDigits(start.day)
        : '${toArabicDigits(start.day)} ${_months[start.month - 1]}';
    return '$from – ${toArabicDigits(end.day)} ${_months[end.month - 1]}';
  }

  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// A streak line for the completion sheet.
  static String streakLine(int current, int best) {
    if (current <= 1) return 'بداية طيبة، ونلتقي غداً إن شاء الله.';
    final line = '${arabicDayCount(current, consecutive: true)}.';
    if (best > current) return '$line أفضل سلسلة لك ${toArabicDigits(best)}.';
    return line;
  }
}

/// [count] minutes in the form that number takes: دقيقة واحدة، دقيقتان،
/// ٣ دقائق، ١١ دقيقة.
String arabicMinuteCount(int count) {
  if (count == 1) return 'دقيقة واحدة';
  if (count == 2) return 'دقيقتان';
  final tail = count % 100;
  final noun = tail >= 3 && tail <= 10 ? 'دقائق' : 'دقيقة';
  return '${toArabicDigits(count)} $noun';
}

/// [count] days with the Arabic counted noun in the form that number takes:
/// يوم واحد، يومان، ٣ أيام، ١١ يوماً، ١٠٠ يوم.
String arabicDayCount(int count, {bool consecutive = false}) {
  if (count == 1) return 'يوم واحد';
  if (count == 2) return consecutive ? 'يومان متتاليان' : 'يومين';
  final tail = count % 100;
  final noun = switch (tail) {
    >= 3 && <= 10 => 'أيام',
    >= 11 => 'يوماً',
    _ => 'يوم',
  };
  final suffix = consecutive ? ' متتالية' : '';
  return '${toArabicDigits(count)} $noun$suffix';
}

/// [count] messages in the form that number takes: رسالة واحدة، رسالتان،
/// ٣ رسائل، ١١ رسالة.
String arabicMessageCount(int count) {
  if (count == 1) return 'رسالة واحدة';
  if (count == 2) return 'رسالتان';
  final tail = count % 100;
  final noun = tail >= 3 && tail <= 10 ? 'رسائل' : 'رسالة';
  return '${toArabicDigits(count)} $noun';
}
