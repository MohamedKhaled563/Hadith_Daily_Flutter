import React from 'react';
import { Heart, Share2, BookOpen, RotateCw } from 'lucide-react';

interface ActionRowProps {
  isFavorite: boolean;
  onFavorite: () => void;
  onShare: () => void;
  onMeaning: () => void;
  onAnother: () => void;
}

export const ActionRow: React.FC<ActionRowProps> = ({
  isFavorite,
  onFavorite,
  onShare,
  onMeaning,
  onAnother,
}) => {
  return (
    <div className="flex items-center justify-around w-full px-2 py-1 select-none">
      {/* 1. Favorite button */}
      <button
        type="button"
        onClick={onFavorite}
        className="flex flex-col items-center gap-1.5 p-2 rounded-2xl transition-all duration-200 hover:bg-[#3C6B4A]/5 active:scale-95 group focus:outline-none"
      >
        <Heart
          className={`w-6 h-6 transition-transform duration-200 group-hover:scale-110 ${
            isFavorite
              ? 'text-[#D97D6C] fill-[#D97D6C]'
              : 'text-[#3C6B4A] dark:text-[#8FC49A]'
          }`}
        />
        <span
          className={`text-xs font-semibold ${
            isFavorite
              ? 'text-[#D97D6C]'
              : 'text-[#3C6B4A] dark:text-[#8FC49A]'
          }`}
        >
          {isFavorite ? 'محفوظ' : 'احفظ'}
        </span>
      </button>

      {/* 2. Share button */}
      <button
        type="button"
        onClick={onShare}
        className="flex flex-col items-center gap-1.5 p-2 rounded-2xl transition-all duration-200 hover:bg-[#3C6B4A]/5 active:scale-95 group focus:outline-none"
      >
        <Share2 className="w-6 h-6 text-[#3C6B4A] dark:text-[#8FC49A] transition-transform duration-200 group-hover:scale-110" />
        <span className="text-xs font-semibold text-[#3C6B4A] dark:text-[#8FC49A]">
          شارك
        </span>
      </button>

      {/* 3. Learn Meaning button */}
      <button
        type="button"
        onClick={onMeaning}
        className="flex flex-col items-center gap-1.5 p-2 rounded-2xl transition-all duration-200 hover:bg-[#3C6B4A]/5 active:scale-95 group focus:outline-none"
      >
        <BookOpen className="w-6 h-6 text-[#3C6B4A] dark:text-[#8FC49A] transition-transform duration-200 group-hover:scale-110" />
        <span className="text-xs font-semibold text-[#3C6B4A] dark:text-[#8FC49A]">
          اعرف المعنى
        </span>
      </button>

      {/* 4. Another Hadith button */}
      <button
        type="button"
        onClick={onAnother}
        className="flex flex-col items-center gap-1.5 p-2 rounded-2xl transition-all duration-200 hover:bg-[#3C6B4A]/5 active:scale-95 group focus:outline-none"
      >
        <RotateCw className="w-6 h-6 text-[#3C6B4A] dark:text-[#8FC49A] transition-transform duration-300 group-hover:rotate-180" />
        <span className="text-xs font-semibold text-[#3C6B4A] dark:text-[#8FC49A]">
          رسالة أخرى
        </span>
      </button>
    </div>
  );
};
