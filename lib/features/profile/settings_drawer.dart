import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/asset_helper.dart';

class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  final AppStateController _state = AppStateController();

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _showAuthModal() {
    final nameCtrl = TextEditingController(text: _state.isLoggedIn ? _state.userName : '');
    final emailCtrl = TextEditingController(text: _state.isLoggedIn ? _state.userEmail : '');
    bool isRegister = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _state.isDarkMode;
            final bgCard = isDark ? AppColors.cardDark : AppColors.card;
            final textColor = isDark ? AppColors.primaryTextDark : AppColors.primaryText;

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorder,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      _state.isLoggedIn
                          ? 'الملف الشخصي والحساب'
                          : (isRegister ? 'إنشاء حساب جديد 🌿' : 'تسجيل الدخول'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _state.isLoggedIn
                          ? 'بيانات حسابك في مجتمع طيّب قلبك'
                          : 'انضم لمجتمع الحديث لحفظ مشاركاتك ومزامنتها',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!_state.isLoggedIn) ...[
                      // Name input (for register or login)
                      _buildAuthField(
                        controller: nameCtrl,
                        label: 'الاسم أو اللقب',
                        icon: Icons.person_outline_rounded,
                        hint: 'مثال: عبد الله بن محمد',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // Email input
                      _buildAuthField(
                        controller: emailCtrl,
                        label: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        hint: 'name@example.com',
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Submit Auth Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            _state.login(
                              name.isNotEmpty ? name : 'عبد الله بن محمد',
                              email.isNotEmpty ? email : 'user@example.com',
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('مرحباً بك! تم تسجيل الدخول بنجاح 🌿', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            isRegister ? 'إنشاء الحساب' : 'تسجيل الدخول',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Toggle Register / Login
                      TextButton(
                        onPressed: () => setModalState(() => isRegister = !isRegister),
                        child: Text(
                          isRegister
                              ? 'لديك حساب بالفعل؟ تسجيل الدخول'
                              : 'ليس لديك حساب؟ اضغط لإنشاء حساب جديد',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ] else ...[
                      // Logged In view
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryGreen,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(_state.userName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Tajawal')),
                        subtitle: Text(_state.userEmail, style: TextStyle(color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText, fontFamily: 'Tajawal')),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () {
                            _state.logout();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تسجيل الخروج بنجاح', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                          ),
                          child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuthField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.primaryGreenDark : AppColors.primaryGreen,
            fontFamily: 'Tajawal',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.softCreamDark : AppColors.softCream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.cardBorderDark : AppColors.cardBorder,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: isDark ? AppColors.primaryTextDark : AppColors.primaryText,
            ),
            decoration: InputDecoration(
              icon: Icon(icon, size: 20, color: AppColors.gold),
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : AppColors.placeholder,
                fontSize: 13,
                fontFamily: 'Tajawal',
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  void _showAboutDialog() {
    final isDark = _state.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            AssetHelper.assetOrFallback(
              assetPath: 'assets/images/heart_leaf_emblem.png',
              width: 32,
              height: 32,
              fallback: const Icon(Icons.favorite, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 10),
            Text(
              'عن تطبيق «طيّب قلبك»',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.primaryTextDark : AppColors.primaryText,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '«طيّب قلبك» هو تطبيق روحي وتأملي يهدف إلى تقريب أحاديث الأربعين النووية لحياتنا اليومية، واستخلاص الهدايات والرسائل القلبية التي تبث السكينة والنور في النفوس.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  height: 1.8,
                  color: isDark ? AppColors.primaryTextDark : AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '📚 المصادر والتوثيق:',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.primaryGreenDark : AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• متن الأربعين النووية للإمام يحيى بن شرف النووي.\n• جامع العلوم والحكم للحافظ ابن رجب الحنبلي.\n• صحيح الإمام البخاري وصحيح الإمام مسلم.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  height: 1.7,
                  color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final isDark = _state.isDarkMode;
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'تواصل معنا واقترح 🌿',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.primaryTextDark : AppColors.primaryText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'يسعدنا سماع رأيك، أو أي فكرة تود إضافتها لتطوير التطبيق:',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.softCreamDark : AppColors.softCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.cardBorderDark : AppColors.cardBorder),
              ),
              child: TextField(
                controller: msgCtrl,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  color: isDark ? AppColors.primaryTextDark : AppColors.primaryText,
                ),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك أو اقتراحك هنا...',
                  hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.placeholder),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('شكراً لك! وصلتنا رسالتك وسنعمل بها بإذن الله 🌿', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('إرسال الاقتراح', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    Clipboard.setData(const ClipboardData(
      text: '🌿 تطبيق «طيّب قلبك» — هدايات وأحاديث الأربعين النووية بأسلوب روحي هادئ يملأ يومك طمأنينة وسكينة.',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط وعبارة المشاركة للأجر 🌿', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _pickTime(bool isMorning) async {
    final initial = isMorning ? _state.morningReminderTime : _state.eveningReminderTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: _state.isDarkMode ? Colors.white : AppColors.primaryText,
              surface: _state.isDarkMode ? AppColors.cardDark : AppColors.card,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isMorning) {
        _state.setMorningReminderTime(picked);
      } else {
        _state.setEveningReminderTime(picked);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ضبط وقت ${isMorning ? "تذكير الصباح" : "تذكير المساء"} على ${_formatTime(picked)} ✨',
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, child) {
        final isDark = _state.isDarkMode;
        final bg = isDark ? AppColors.backgroundDark : AppColors.background;
        final cardBg = isDark ? AppColors.cardDark : AppColors.card;
        final textColor = isDark ? AppColors.primaryTextDark : AppColors.primaryText;
        final subTextColor = isDark ? AppColors.secondaryTextDark : AppColors.secondaryText;
        final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorder;

        return Drawer(
          backgroundColor: bg,
          child: SafeArea(
            child: Column(
              children: [
                // 1. Profile Header Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.softCreamDark : AppColors.softCream,
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: Center(
                          child: Icon(
                            _state.isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                            color: AppColors.primaryGreen,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _state.userName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _state.isLoggedIn ? _state.userEmail : 'عضو في مجتمع طيّب قلبك',
                              style: TextStyle(
                                fontSize: 12,
                                color: subTextColor,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit / Auth Button
                      GestureDetector(
                        onTap: _showAuthModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _state.isLoggedIn ? 'حسابي' : 'دخول',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Settings & Menu Sections
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Section A: المظهر والثيم (Appearance)
                      _buildSectionHeader('المظهر والألوان', isDark),
                      _buildSettingsCard(
                        cardBg: cardBg,
                        borderColor: borderColor,
                        children: [
                          _buildSwitchTile(
                            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            iconColor: AppColors.gold,
                            title: 'الوضع الليلي (Dark Mode)',
                            subtitle: isDark ? 'مفعل — مريح للعين' : 'الوضع الفاتح مفعّل',
                            value: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onChanged: (val) => _state.toggleTheme(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Section B: التنبيهات والمواعيد (Daily Reminders)
                      _buildSectionHeader('مواعيد التنبيهات اليومية', isDark),
                      _buildSettingsCard(
                        cardBg: cardBg,
                        borderColor: borderColor,
                        children: [
                          // Morning Reminder
                          _buildTimeTile(
                            icon: Icons.wb_sunny_outlined,
                            iconColor: const Color(0xFFD69E2E),
                            title: 'تذكير رسالة الصباح',
                            subtitle: _formatTime(_state.morningReminderTime),
                            isEnabled: _state.morningReminderEnabled,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onToggle: (val) => _state.toggleMorningReminder(val),
                            onTapTime: () => _pickTime(true),
                          ),
                          Divider(height: 1, color: borderColor),

                          // Evening Reminder
                          _buildTimeTile(
                            icon: Icons.nights_stay_outlined,
                            iconColor: const Color(0xFF805AD5),
                            title: 'تذكير تأمل المساء',
                            subtitle: _formatTime(_state.eveningReminderTime),
                            isEnabled: _state.eveningReminderEnabled,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onToggle: (val) => _state.toggleEveningReminder(val),
                            onTapTime: () => _pickTime(false),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Section C: عن التطبيق والتواصل (About & Contact)
                      _buildSectionHeader('المعلومات والتواصل', isDark),
                      _buildSettingsCard(
                        cardBg: cardBg,
                        borderColor: borderColor,
                        children: [
                          _buildNavigationTile(
                            icon: Icons.info_outline_rounded,
                            title: 'من نحن وعن التطبيق',
                            textColor: textColor,
                            onTap: _showAboutDialog,
                          ),
                          Divider(height: 1, color: borderColor),
                          _buildNavigationTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'تواصل معنا واقترح فكرة',
                            textColor: textColor,
                            onTap: _showFeedbackDialog,
                          ),
                          Divider(height: 1, color: borderColor),
                          _buildNavigationTile(
                            icon: Icons.share_rounded,
                            title: 'شارك التطبيق وكن داعياً للخير 🌿',
                            textColor: textColor,
                            onTap: _shareApp,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // App Footer Quote
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '«طِبْ نفساً واستبشر بنور النبوة»',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.gold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إصدار 1.0.0 — الأربعين النووية',
                              style: TextStyle(
                                fontSize: 11,
                                color: subTextColor,
                                fontFamily: 'Tajawal',
                              ),
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.gold : AppColors.primaryGreen,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Tajawal'),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: subTextColor, fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTapTime,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Tajawal'),
                ),
                GestureDetector(
                  onTap: onTapTime,
                  child: Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 11, color: AppColors.gold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeColor: AppColors.primaryGreen,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Tajawal'),
              ),
            ),
            const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.placeholder),
          ],
        ),
      ),
    );
  }
}
