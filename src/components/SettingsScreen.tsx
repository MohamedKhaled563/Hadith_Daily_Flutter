import React, { useState } from 'react';
import {
  Bell,
  Clock,
  Palette,
  Share2,
  BookOpen,
  Info,
  ChevronLeft,
  Check,
  Sparkles,
} from 'lucide-react';
import { ThemeMode, ShareStyle, ReminderSettings } from '../types';
import { toArabicDigits } from '../utils';

interface SettingsScreenProps {
  themeMode: ThemeMode;
  onThemeModeChange: (mode: ThemeMode) => void;
  shareStyle: ShareStyle;
  onShareStyleChange: (style: ShareStyle) => void;
  reminder: ReminderSettings;
  onReminderChange: (reminder: ReminderSettings) => void;
  onOpenOnboarding: () => void;
  onShowToast: (message: string) => void;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({
  themeMode,
  onThemeModeChange,
  shareStyle,
  onShareStyleChange,
  reminder,
  onReminderChange,
  onOpenOnboarding,
  onShowToast,
}) => {
  const [showThemeModal, setShowThemeModal] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);
  const [showTimeModal, setShowTimeModal] = useState(false);

  const themeLabels: Record<ThemeMode, string> = {
    system: 'حسب الجهاز',
    light: 'فاتح',
    dark: 'داكن',
  };

  const shareLabels: Record<ShareStyle, string> = {
    cream: 'الورق الكريمي',
    forest: 'الأخضر الهادئ',
    midnight: 'المساء',
  };

  const handleToggleReminder = async (enabled: boolean) => {
    if (enabled && 'Notification' in window) {
      if (Notification.permission !== 'granted') {
        const permission = await Notification.requestPermission();
        if (permission !== 'granted') {
          onShowToast('يمكنك تفعيل الإشعارات من إعدادات المتصفح.');
        }
      }
    }
    onReminderChange({
      ...reminder,
      enabled,
    });
    onShowToast(enabled ? 'تم تفعيل التذكير اليومي بنجاح' : 'تم إيقاف التذكير اليومي');
  };

  const formatTime = (hour: number, minute: number) => {
    const period = hour >= 12 ? 'م' : 'ص';
    const h12 = hour % 12 || 12;
    const mStr = minute < 10 ? `0${minute}` : `${minute}`;
    return `${toArabicDigits(h12)}:${toArabicDigits(mStr)} ${period}`;
  };

  return (
    <div className="max-w-lg mx-auto px-5 py-4 pb-28 min-h-full">
      {/* Header */}
      <div className="pt-2 pb-3">
        <h1 className="text-2xl font-bold text-[#2B2B25] dark:text-[#EDEAE0] font-kufi">
          الإعدادات
        </h1>
        <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9] font-medium mt-0.5">
          خلي التجربة على مزاجك، من غير ما نزحمها.
        </p>
      </div>

      <div className="space-y-6 mt-4">
        {/* Section 1: Daily Reminder */}
        <div>
          <h2 className="text-xs font-bold text-[#7A7A6E] dark:text-[#A7B3A9] mb-2 px-1">
            التذكير اليومي
          </h2>
          <div className="space-y-2">
            {/* Toggle Tile */}
            <div className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm">
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                  <Bell className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    حديثك اليومي
                  </h3>
                  <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                    {reminder.enabled
                      ? `يومياً الساعة ${formatTime(reminder.hour, reminder.minute)}`
                      : 'موقوف حالياً'}
                  </p>
                </div>
              </div>

              {/* Switch */}
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={reminder.enabled}
                  onChange={(e) => handleToggleReminder(e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-[#E1DACB] dark:bg-white/20 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#3C6B4A]"></div>
              </label>
            </div>

            {/* Time Picker Tile */}
            {reminder.enabled && (
              <div
                onClick={() => setShowTimeModal(true)}
                className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                    <Clock className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                      وقت التذكير
                    </h3>
                    <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                      اختار الوقت الأنسب لك
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-1.5 text-xs font-bold text-[#3C6B4A] dark:text-[#8FC49A]">
                  <span>{formatTime(reminder.hour, reminder.minute)}</span>
                  <ChevronLeft className="w-4 h-4 text-[#7A7A6E]/60" />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Section 2: Appearance */}
        <div>
          <h2 className="text-xs font-bold text-[#7A7A6E] dark:text-[#A7B3A9] mb-2 px-1">
            المظهر
          </h2>
          <div
            onClick={() => setShowThemeModal(true)}
            className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                <Palette className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                  المظهر
                </h3>
                <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                  {themeLabels[themeMode]}
                </p>
              </div>
            </div>
            <ChevronLeft className="w-4 h-4 text-[#7A7A6E]/60" />
          </div>
        </div>

        {/* Section 3: Share Template */}
        <div>
          <h2 className="text-xs font-bold text-[#7A7A6E] dark:text-[#A7B3A9] mb-2 px-1">
            المشاركة
          </h2>
          <div
            onClick={() => setShowShareModal(true)}
            className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                <Share2 className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                  التصميم الافتراضي
                </h3>
                <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                  {shareLabels[shareStyle]}
                </p>
              </div>
            </div>
            <ChevronLeft className="w-4 h-4 text-[#7A7A6E]/60" />
          </div>
        </div>

        {/* Section 4: About & Onboarding */}
        <div>
          <h2 className="text-xs font-bold text-[#7A7A6E] dark:text-[#A7B3A9] mb-2 px-1">
            عن التطبيق
          </h2>
          <div className="space-y-2">
            <div
              onClick={onOpenOnboarding}
              className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
            >
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                  <Sparkles className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    جولة تعريفية
                  </h3>
                  <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                    إعادة عرض شاشات البداية
                  </p>
                </div>
              </div>
              <ChevronLeft className="w-4 h-4 text-[#7A7A6E]/60" />
            </div>

            <div className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm">
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                  <BookOpen className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    الأربعون النووية
                  </h3>
                  <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                    قراءة يومية هادئة مع شرح ومشاركة
                  </p>
                </div>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 shadow-sm">
              <div className="flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A]">
                  <Info className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    Hadith Daily
                  </h3>
                  <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
                    نسخة الويب السريعة • الإصدار 1.0.0
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Theme Picker Modal */}
      {showThemeModal && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-fade-in">
          <div className="w-full max-w-md bg-[#F6F1E7] dark:bg-[#1A261F] rounded-t-[28px] sm:rounded-[28px] p-6 shadow-2xl">
            <h3 className="text-base font-bold text-[#2B2B25] dark:text-[#EDEAE0] mb-4">
              اختار المظهر
            </h3>
            <div className="space-y-2">
              {(['system', 'light', 'dark'] as ThemeMode[]).map((mode) => (
                <div
                  key={mode}
                  onClick={() => {
                    onThemeModeChange(mode);
                    setShowThemeModal(false);
                  }}
                  className="flex items-center justify-between p-3.5 rounded-xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
                >
                  <span className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    {themeLabels[mode]}
                  </span>
                  {themeMode === mode && (
                    <Check className="w-4 h-4 text-[#3C6B4A] dark:text-[#8FC49A]" />
                  )}
                </div>
              ))}
            </div>
            <button
              type="button"
              onClick={() => setShowThemeModal(false)}
              className="w-full mt-4 py-3 rounded-xl bg-[#3C6B4A]/10 dark:bg-white/10 text-xs font-bold text-[#3C6B4A] dark:text-[#8FC49A]"
            >
              إلغاء
            </button>
          </div>
        </div>
      )}

      {/* Share Style Picker Modal */}
      {showShareModal && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-fade-in">
          <div className="w-full max-w-md bg-[#F6F1E7] dark:bg-[#1A261F] rounded-t-[28px] sm:rounded-[28px] p-6 shadow-2xl">
            <h3 className="text-base font-bold text-[#2B2B25] dark:text-[#EDEAE0] mb-4">
              التصميم الافتراضي للمشاركة
            </h3>
            <div className="space-y-2">
              {(['cream', 'forest', 'midnight'] as ShareStyle[]).map((s) => (
                <div
                  key={s}
                  onClick={() => {
                    onShareStyleChange(s);
                    setShowShareModal(false);
                  }}
                  className="flex items-center justify-between p-3.5 rounded-xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 cursor-pointer hover:border-[#3C6B4A]/40 transition-all select-none"
                >
                  <span className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
                    {shareLabels[s]}
                  </span>
                  {shareStyle === s && (
                    <Check className="w-4 h-4 text-[#3C6B4A] dark:text-[#8FC49A]" />
                  )}
                </div>
              ))}
            </div>
            <button
              type="button"
              onClick={() => setShowShareModal(false)}
              className="w-full mt-4 py-3 rounded-xl bg-[#3C6B4A]/10 dark:bg-white/10 text-xs font-bold text-[#3C6B4A] dark:text-[#8FC49A]"
            >
              إلغاء
            </button>
          </div>
        </div>
      )}

      {/* Time Picker Modal */}
      {showTimeModal && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-fade-in">
          <div className="w-full max-w-md bg-[#F6F1E7] dark:bg-[#1A261F] rounded-t-[28px] sm:rounded-[28px] p-6 shadow-2xl">
            <h3 className="text-base font-bold text-[#2B2B25] dark:text-[#EDEAE0] mb-4">
              حدد وقت التذكير اليومي
            </h3>
            <div className="flex items-center justify-center gap-4 my-6">
              {/* Hour input */}
              <div className="flex flex-col items-center">
                <span className="text-xs text-[#7A7A6E] mb-1">الساعة</span>
                <select
                  value={reminder.hour}
                  onChange={(e) =>
                    onReminderChange({ ...reminder, hour: parseInt(e.target.value, 10) })
                  }
                  className="py-2.5 px-4 rounded-xl bg-white dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/10 text-lg font-bold text-[#2B2B25] dark:text-[#EDEAE0] focus:outline-none focus:ring-2 focus:ring-[#3C6B4A]"
                >
                  {Array.from({ length: 24 }).map((_, i) => (
                    <option key={i} value={i}>
                      {toArabicDigits(i < 10 ? `0${i}` : `${i}`)} ({i >= 12 ? 'م' : 'ص'})
                    </option>
                  ))}
                </select>
              </div>

              <span className="text-2xl font-bold text-[#3C6B4A] mt-5">:</span>

              {/* Minute input */}
              <div className="flex flex-col items-center">
                <span className="text-xs text-[#7A7A6E] mb-1">الدقيقة</span>
                <select
                  value={reminder.minute}
                  onChange={(e) =>
                    onReminderChange({ ...reminder, minute: parseInt(e.target.value, 10) })
                  }
                  className="py-2.5 px-4 rounded-xl bg-white dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/10 text-lg font-bold text-[#2B2B25] dark:text-[#EDEAE0] focus:outline-none focus:ring-2 focus:ring-[#3C6B4A]"
                >
                  {[0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55].map((m) => (
                    <option key={m} value={m}>
                      {toArabicDigits(m < 10 ? `0${m}` : `${m}`)}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <button
              type="button"
              onClick={() => {
                setShowTimeModal(false);
                onShowToast('تم تحديث وقت التذكير بنجاح');
              }}
              className="w-full py-3 rounded-xl bg-[#3C6B4A] text-white text-sm font-bold shadow active:scale-95"
            >
              حفظ
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
