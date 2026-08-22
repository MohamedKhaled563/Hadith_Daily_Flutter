import React, { useState } from 'react';
import { BookOpen, Heart, Bell, Clock } from 'lucide-react';
import { toArabicDigits } from '../utils';

interface OnboardingModalProps {
  isOpen: boolean;
  onFinish: () => void;
  onSetReminder: (hour: number, minute: number) => void;
}

export const OnboardingModal: React.FC<OnboardingModalProps> = ({
  isOpen,
  onFinish,
  onSetReminder,
}) => {
  const [page, setPage] = useState(0);
  const [reminderHour, setReminderHour] = useState(9);
  const [reminderMinute, setReminderMinute] = useState(0);

  if (!isOpen) return null;

  const slides = [
    {
      icon: BookOpen,
      title: 'كل يوم حديث',
      body: 'دقيقة واحدة مع حديث من الأربعين النووية يرافق يومك.',
    },
    {
      icon: Heart,
      title: 'احفظ ما يلامس قلبك',
      body: 'احتفظ بالأحاديث التي تحب الرجوع إليها في أي وقت بسهولة.',
    },
    {
      icon: Bell,
      title: 'ولا تنسَ حديثك اليومي',
      body: 'اختار وقتاً بسيطاً نفتكرك فيه بحديث اليوم.',
    },
  ];

  const handleNext = () => {
    if (page < slides.length - 1) {
      setPage(page + 1);
    } else {
      onSetReminder(reminderHour, reminderMinute);
      onFinish();
    }
  };

  const currentSlide = slides[page];
  const IconComponent = currentSlide.icon;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-sm bg-[#F6F1E7] dark:bg-[#1A261F] rounded-[32px] p-6 shadow-2xl flex flex-col min-h-[480px] justify-between border border-[#E1DACB]/60 dark:border-white/10">
        {/* Skip button */}
        <div className="flex justify-start">
          <button
            type="button"
            onClick={onFinish}
            className="text-xs font-bold text-[#7A7A6E] dark:text-[#A7B3A9] hover:text-[#3C6B4A] dark:hover:text-[#8FC49A] px-2 py-1"
          >
            تخطي
          </button>
        </div>

        {/* Slide Content */}
        <div className="flex-1 flex flex-col items-center justify-center text-center px-4 py-4 animate-fade-in">
          {/* Icon Circle */}
          <div className="w-24 h-24 rounded-full bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A] mb-8 shadow-inner">
            <IconComponent className="w-11 h-11" />
          </div>

          {/* Title */}
          <h2 className="text-xl font-bold text-[#2B2B25] dark:text-[#EDEAE0] mb-3 font-kufi">
            {currentSlide.title}
          </h2>

          {/* Body */}
          <p className="text-sm text-[#7A7A6E] dark:text-[#A7B3A9] leading-relaxed max-w-[260px]">
            {currentSlide.body}
          </p>

          {/* Slide 3: Time Picker Widget */}
          {page === 2 && (
            <div className="mt-5 flex items-center justify-center gap-2 py-2 px-4 rounded-2xl bg-white/80 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/10">
              <Clock className="w-4 h-4 text-[#3C6B4A] dark:text-[#8FC49A]" />
              <span className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">وقت التذكير:</span>
              <select
                value={reminderHour}
                onChange={(e) => setReminderHour(parseInt(e.target.value, 10))}
                className="bg-transparent text-xs font-bold text-[#3C6B4A] dark:text-[#8FC49A] focus:outline-none cursor-pointer"
              >
                {Array.from({ length: 24 }).map((_, i) => (
                  <option key={i} value={i} className="bg-white dark:bg-[#1E2B22]">
                    {toArabicDigits(i < 10 ? `0${i}` : `${i}`)} ({i >= 12 ? 'م' : 'ص'})
                  </option>
                ))}
              </select>
              <span>:</span>
              <select
                value={reminderMinute}
                onChange={(e) => setReminderMinute(parseInt(e.target.value, 10))}
                className="bg-transparent text-xs font-bold text-[#3C6B4A] dark:text-[#8FC49A] focus:outline-none cursor-pointer"
              >
                {[0, 15, 30, 45].map((m) => (
                  <option key={m} value={m} className="bg-white dark:bg-[#1E2B22]">
                    {toArabicDigits(m < 10 ? `0${m}` : `${m}`)}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

        {/* Footer with Dots and Next/Finish button */}
        <div className="space-y-4 pt-2">
          {/* Pagination dots */}
          <div className="flex justify-center items-center gap-2">
            {slides.map((_, i) => (
              <div
                key={i}
                className={`transition-all duration-300 rounded-full h-1.5 ${
                  i === page
                    ? 'w-6 bg-[#3C6B4A] dark:bg-[#8FC49A]'
                    : 'w-1.5 bg-[#E1DACB] dark:bg-white/20'
                }`}
              />
            ))}
          </div>

          {/* Action button */}
          <button
            type="button"
            onClick={handleNext}
            className="w-full py-3.5 rounded-2xl bg-[#3C6B4A] hover:bg-[#325a3e] text-white font-bold text-sm shadow-md transition-all active:scale-98"
          >
            {page === slides.length - 1 ? 'ابدأ يومك' : 'التالي'}
          </button>
        </div>
      </div>
    </div>
  );
};
