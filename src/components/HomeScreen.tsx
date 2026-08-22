import React from 'react';
import { Menu, User } from 'lucide-react';
import { Hadith, Insight } from '../types';

interface HomeScreenProps {
  hadith: Hadith;
  insight: Insight;
  onOpenDailyMessage: () => void;
  onOpenAllHadiths: () => void;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({
  onOpenDailyMessage,
  onOpenAllHadiths,
}) => {
  return (
    <div className="relative flex flex-col justify-between min-h-[calc(100vh-6rem)] max-w-md mx-auto px-6 py-4 pb-28 text-center select-none overflow-hidden">
      {/* Top Header matching home page.png */}
      <header className="flex items-center justify-between w-full pt-1 z-20">
        {/* Menu Icon on Left (RTL) */}
        <button
          type="button"
          onClick={onOpenAllHadiths}
          title="القائمة"
          className="w-10 h-10 rounded-full flex items-center justify-center text-[#26352C] dark:text-[#EDEAE0] hover:bg-[#F4EEE3]/70 transition-colors"
        >
          <Menu className="w-6 h-6 stroke-[2]" />
        </button>

        {/* User Greeting on Right (RTL) */}
        <div className="flex items-center gap-2.5">
          <span className="text-lg sm:text-xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
            أهلاً أميرة
          </span>
          <div className="w-9 h-9 rounded-full border-2 border-[#526B57]/50 dark:border-[#8FC49A]/50 flex items-center justify-center text-[#526B57] dark:text-[#8FC49A] bg-[#FFFDFC]/80 dark:bg-[#1E2B22]/80">
            <User className="w-5 h-5" />
          </div>
        </div>
      </header>

      {/* Central Content Area */}
      <div className="my-auto flex flex-col items-center justify-center py-4 z-20">
        {/* Guiding Question */}
        <div className="mb-4">
          <h2 className="text-2xl sm:text-3xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi leading-relaxed">
            هل سمعت
          </h2>
          <h2 className="text-2xl sm:text-3xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi leading-relaxed flex items-center justify-center gap-2 mt-1">
            <span>كلام النبي</span>
            <span className="text-base sm:text-lg text-[#526B57] dark:text-[#8FC49A] font-serif">ﷺ</span>
            <span>اليوم؟</span>
          </h2>
        </div>

        {/* Golden / Leaf divider under title */}
        <div className="w-28 h-5 my-2 flex items-center justify-center">
          <img
            src="/assets/golden_divider.svg"
            alt="Divider"
            className="w-full h-full object-contain opacity-85"
          />
        </div>

        {/* Central Circular Interactive Plate (matching home.png & home page.png) */}
        <button
          type="button"
          onClick={onOpenDailyMessage}
          className="group relative w-64 h-64 sm:w-72 sm:h-72 mt-4 rounded-full bg-gradient-to-b from-[#FFFDFC] via-[#F9F5EC] to-[#F1E8D9] dark:from-[#243428] dark:to-[#17231B] border-[3.5px] border-[#D1BE93] shadow-[0_16px_40px_rgba(185,160,106,0.3)] dark:shadow-[0_16px_40px_rgba(0,0,0,0.5)] flex flex-col items-center justify-center p-6 cursor-pointer transition-all duration-300 hover:scale-105 active:scale-95 focus:outline-none"
        >
          {/* Subtle Outer Concentric Ring */}
          <div className="absolute -inset-2.5 rounded-full border border-[#D1BE93]/40 pointer-events-none group-hover:scale-105 transition-transform duration-500" />

          {/* Top Heart + Leaf Emblem */}
          <div className="w-14 h-14 sm:w-16 sm:h-16 mb-2">
            <img
              src="/assets/heart_leaf_emblem.svg"
              alt="طيّب قلبك"
              className="w-full h-full object-contain"
            />
          </div>

          {/* "طيّب قلبك" Main Calligraphy Text */}
          <span className="text-3xl sm:text-4xl font-extrabold text-[#26352C] dark:text-[#EDEAE0] font-kufi tracking-tight">
            طيّب قلبك
          </span>

          {/* Small Gold Flourish */}
          <div className="w-20 h-4 my-2 opacity-80">
            <img
              src="/assets/golden_divider.svg"
              alt="Divider"
              className="w-full h-full object-contain"
            />
          </div>

          {/* Subtitle */}
          <span className="text-xs sm:text-[13px] text-[#526B57] dark:text-[#A7B3A9] font-medium font-kufi max-w-[200px] leading-snug">
            اضغط لاختبار رسالة عشوائية مربوطة بحديث
          </span>
        </button>
      </div>

      {/* Sunset Lake Watercolor Landscape Background at Bottom */}
      <div className="absolute inset-x-0 bottom-0 h-64 pointer-events-none z-10 opacity-90 dark:opacity-40">
        <img
          src="/assets/sunset_landscape.svg"
          alt="Sunset Lake"
          className="w-full h-full object-cover object-bottom"
        />
      </div>
    </div>
  );
};
