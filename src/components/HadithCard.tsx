import React from 'react';
import { Heart } from 'lucide-react';
import { Hadith } from '../types';
import { getShortLabel } from '../utils';

interface HadithCardProps {
  hadith: Hadith;
  compact?: boolean;
  onClick?: () => void;
}

export const HadithCard: React.FC<HadithCardProps> = ({ hadith, compact = false, onClick }) => {
  return (
    <div
      onClick={onClick}
      className={`relative w-full rounded-[32px] p-6 sm:p-9 text-center cursor-pointer transition-all duration-300 transform select-none shadow-[0_14px_30px_rgba(0,0,0,0.06)] dark:shadow-[0_14px_30px_rgba(0,0,0,0.3)] bg-gradient-to-b from-[#F3EEE3] to-[#E7EEE1] dark:from-[#1E2B22] dark:to-[#15201A] border border-[#E1DACB]/50 dark:border-white/5 ${
        onClick ? 'hover:scale-[1.01] active:scale-[0.99]' : ''
      }`}
    >
      {/* Top quotation mark */}
      <div className="text-[44px] leading-none font-black text-[#3C6B4A]/35 dark:text-[#8FC49A]/40 mb-3 select-none">
        ”
      </div>

      {/* Main Hadith text */}
      <p
        className={`font-naskh font-semibold text-[#2B2B25] dark:text-[#EDEAE0] leading-[1.8] tracking-normal ${
          compact ? 'text-lg sm:text-xl line-clamp-6' : 'text-xl sm:text-2xl'
        }`}
      >
        {hadith.text}
      </p>

      {/* Footer attribution */}
      <div className="mt-6 flex flex-col items-center">
        <div className="w-10 h-[1.5px] bg-[#E1DACB] dark:bg-white/10 mb-3" />
        <p className="text-xs sm:text-sm font-medium text-[#7A7A6E] dark:text-[#A7B3A9] leading-relaxed">
          من حديث: {getShortLabel(hadith.text, 6)}
        </p>
      </div>

      {/* Small decorative heart at bottom */}
      <div className="mt-4 flex justify-center">
        <Heart className="w-4 h-4 text-[#D97D6C]/80 fill-[#D97D6C]/30" />
      </div>
    </div>
  );
};
