import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/repositories/hadith_repository.dart';
import '../auth/login_screen.dart';

class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  final AppStateController _state = AppStateController();
  final HadithRepository _repo = HadithRepository();

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ------------------------------------------------------------- account ----

  void _confirmLogout() {
    showBotanicalSheet<void>(
      context: context,
      title: 'تسجيل الخروج',
      subtitle: 'هل تريد الخروج من حسابك؟ ستبقى محفوظاتك كما هي.',
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              onPressed: () {
                Navigator.pop(sheetContext);
                _logout();
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'إلغاء',
              isSecondary: true,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    _state.logout();

    // Drop the whole stack: there is nothing to come back to once signed out.
    Navigator.of(context).pushAndRemoveUntil(
      SmoothPageRoute(child: const LoginScreen()),
      (route) => false,
    );
  }

  // -------------------------------------------------------------- dialogs ----

  void _showAboutSheet() {
    showBotanicalSheet<void>(
      context: context,
      title: 'عن تطبيق «طيّب قلبك»',
      child: Builder(
        builder: (sheetContext) {
          final palette = sheetContext.palette;
          final textTheme = Theme.of(sheetContext).textTheme;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '«طيّب قلبك» تطبيق روحي وتأملي يقرّب أحاديث الأربعين النووية '
                'لحياتنا اليومية، ويستخلص الهدايات والرسائل القلبية التي تبث '
                'السكينة والنور في النفوس.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '📚 المصادر والتوثيق',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.goldText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• متن الأربعين النووية للإمام يحيى بن شرف النووي.\n'
                '• جامع العلوم والحكم للحافظ ابن رجب الحنبلي.\n'
                '• صحيح الإمام البخاري وصحيح الإمام مسلم.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              AppButton(
                text: 'إغلاق',
                isSecondary: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeedbackSheet() {
    final msgCtrl = TextEditingController();

    showBotanicalSheet<void>(
      context: context,
      title: 'تواصل معنا واقترح 🌿',
      subtitle: 'يسعدنا سماع رأيك، أو أي فكرة تود إضافتها لتطوير التطبيق',
      child: Builder(
        builder: (sheetContext) {
          final palette = sheetContext.palette;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.listItem),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13.5,
                    height: AppLeading.body,
                    color: palette.bodyText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك أو اقتراحك هنا...',
                    hintStyle: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      color: palette.mutedText,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                text: 'إرسال الاقتراح',
                icon: Icons.send_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _toast('شكراً لك! وصلتنا رسالتك وسنعمل بها بإذن الله 🌿');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _shareApp() {
    Clipboard.setData(
      const ClipboardData(
        text: '🌿 تطبيق «طيّب قلبك» — هدايات وأحاديث الأربعين النووية بأسلوب '
            'روحي هادئ يملأ يومك طمأنينة وسكينة.',
      ),
    );
    _toast('تم نسخ عبارة المشاركة 🌿');
  }

  Future<void> _pickTime(bool isMorning) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isMorning ? _state.morningReminderTime : _state.eveningReminderTime,
    );

    if (picked == null || !mounted) return;

    isMorning
        ? _state.setMorningReminderTime(picked)
        : _state.setEveningReminderTime(picked);

    setState(() {});
    _toast(
      'تم ضبط وقت ${isMorning ? "تذكير الصباح" : "تذكير المساء"} '
      'على ${_formatTime(picked)} ✨',
    );
  }

  // ---------------------------------------------------------------- build ----

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final palette = context.palette;
        final isDark = context.isDarkMode;

        return Drawer(
          backgroundColor:
              isDark ? AppColors.backgroundDark : AppColors.background,
          child: SafeArea(
            child: Column(
              children: [
                _ProfileHeader(state: _state, repo: _repo),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _SectionHeader('المظهر والقراءة'),
                      _SettingsCard(
                        children: [
                          _SwitchTile(
                            icon: isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            title: 'الوضع الليلي',
                            subtitle: isDark
                                ? 'مفعل — مريح للعين'
                                : 'الوضع الفاتح مفعّل',
                            value: isDark,
                            onChanged: (_) => _state.toggleTheme(),
                          ),
                          _Divider(),
                          // The reading-size control this app was missing: the
                          // state existed but nothing exposed or consumed it.
                          _FontSizeTile(state: _state),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _SectionHeader('مواعيد التنبيهات اليومية'),
                      _SettingsCard(
                        children: [
                          _TimeTile(
                            icon: Icons.wb_sunny_outlined,
                            title: 'تذكير رسالة الصباح',
                            time: _formatTime(_state.morningReminderTime),
                            isEnabled: _state.morningReminderEnabled,
                            onToggle: _state.toggleMorningReminder,
                            onTapTime: () => _pickTime(true),
                          ),
                          _Divider(),
                          _TimeTile(
                            icon: Icons.nights_stay_outlined,
                            title: 'تذكير تأمل المساء',
                            time: _formatTime(_state.eveningReminderTime),
                            isEnabled: _state.eveningReminderEnabled,
                            onToggle: _state.toggleEveningReminder,
                            onTapTime: () => _pickTime(false),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _SectionHeader('المعلومات والتواصل'),
                      _SettingsCard(
                        children: [
                          _NavTile(
                            icon: Icons.info_outline_rounded,
                            title: 'من نحن وعن التطبيق',
                            onTap: _showAboutSheet,
                          ),
                          _Divider(),
                          _NavTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'تواصل معنا واقترح فكرة',
                            onTap: _showFeedbackSheet,
                          ),
                          _Divider(),
                          _NavTile(
                            icon: Icons.share_rounded,
                            title: 'شارك التطبيق وكن داعياً للخير 🌿',
                            onTap: _shareApp,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Sign-out lives here rather than behind the profile
                      // name: tapping your own name should show you your
                      // account, not offer to end the session.
                      _SectionHeader('الحساب'),
                      _SettingsCard(
                        children: [
                          _NavTile(
                            icon: Icons.logout_rounded,
                            title: 'تسجيل الخروج',
                            onTap: _confirmLogout,
                            destructive: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              '«طِبْ نفساً واستبشر بنور النبوة»',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: kNaskh,
                                fontSize: 15,
                                height: AppLeading.body,
                                color: palette.goldText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إصدار 1.0.0 — الأربعين النووية',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------- fragments ----

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.state, required this.repo});

  final AppStateController state;
  final HadithRepository repo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // Real counts rather than the placeholder figures that used to sit on the
    // state controller.
    final saved =
        repo.favoriteHadithNumbers.length + repo.favoriteInsightTexts.length;
    final contributions = repo.communityPosts
        .where((post) => post.authorName == state.userName)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.cardBorder),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surfaceSunken,
                    border: Border.all(
                      color: palette.cardBorderStrong,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    firstInitial(state.userName),
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 22,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w900,
                      color: palette.goldText,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.bookmark_rounded,
                    value: saved,
                    label: 'محفوظاتي',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: palette.cardBorder,
                ),
                Expanded(
                  child: _Stat(
                    icon: Icons.edit_note_rounded,
                    value: contributions,
                    label: 'مشاركاتي',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: palette.goldText),
            const SizedBox(width: 6),
            Text(
              toArabicDigits(value),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 17,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w900,
                color: palette.bodyText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 11.5,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w600,
            color: palette.mutedText,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
            color: context.palette.goldText,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.listItem),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: context.palette.cardBorder);
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: Icon(icon, color: palette.goldText, size: 22),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(fontSize: 11.5),
      ),
    );
  }
}

class _FontSizeTile extends StatelessWidget {
  const _FontSizeTile({required this.state});

  final AppStateController state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final steps = AppStateController.fontSizeSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_size_rounded,
                color: palette.goldText,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'حجم النص',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                for (final entry in steps.entries)
                  Expanded(
                    child: _FontSizeOption(
                      label: entry.key,
                      selected:
                          (state.fontSizeScale - entry.value).abs() < 0.001,
                      onTap: () => state.setFontSizeScale(entry.value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeOption extends StatelessWidget {
  const _FontSizeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: 'حجم النص: $label',
      selected: selected,
      minSize: 44,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: selected ? AppElevation.card : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            height: AppLeading.chrome,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.goldText : palette.mutedText,
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.title,
    required this.time,
    required this.isEnabled,
    required this.onToggle,
    required this.onTapTime,
  });

  final IconData icon;
  final String title;
  final String time;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapTime;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: palette.goldText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TapTarget(
                  onTap: onTapTime,
                  semanticLabel: '$title — الوقت الحالي $time، اضغط للتغيير',
                  minSize: 44,
                  child: Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 11.5,
                            height: AppLeading.chrome,
                            fontWeight: FontWeight.w700,
                            color: palette.goldText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 11,
                          color: palette.goldText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Sign-out and anything else that ends or removes something. Colours the
  /// row so it cannot be mistaken for another navigation item.
  final bool destructive;

  static const _destructive = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: title,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.listItem),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: destructive ? _destructive : palette.goldText,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          fontWeight:
                              destructive ? FontWeight.w700 : FontWeight.w600,
                          color: destructive ? _destructive : null,
                        ),
                  ),
                ),
                if (!destructive)
                  // chevron_left points "forward" under RTL.
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: palette.mutedText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
