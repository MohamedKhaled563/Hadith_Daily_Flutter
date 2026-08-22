import React from 'react';
import { Heart, ChevronLeft } from 'lucide-react';
import { Hadith } from '../types';
import { toArabicDigits } from '../utils';

interface FavoritesScreenProps {
  favorites: Hadith[];
  onSelectHadith: (hadith: Hadith) => void;
}

export const FavoritesScreen: React.FC<FavoritesScreenProps> = ({
  favorites,
  onSelectHadith,
}) => {
  return (
    <div className="max-w-lg mx-auto px-5 py-4 pb-28 min-h-full">
      {/* Header */}
      <div className="pt-2 pb-3">
        <h1 className="text-2xl font-bold text-[#2B2B25] dark:text-[#EDEAE0] font-kufi">
          المحفوظات
        </h1>
        <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9] font-medium mt-0.5">
          {favorites.length === 0
            ? 'احتفظ بالأحاديث التي تريد الرجوع إليها لاحقاً.'
            : `${toArabicDigits(favorites.length)} أحاديث محفوظة`}
        </p>
      </div>

      {/* Content */}
      {favorites.length === 0 ? (
        <div className="py-20 text-center flex flex-col items-center">
          <div className="w-20 h-20 rounded-full bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/20 flex items-center justify-center mb-5">
            <Heart className="w-9 h-9 text-[#3C6B4A] dark:text-[#8FC49A]" />
          </div>
          <h3 className="text-lg font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
            لسه مفيش أحاديث محفوظة
          </h3>
          <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9] mt-2 max-w-xs leading-relaxed">
            لما تلاقي حديث تحب ترجع له، احفظه من علامة القلب وهيظهر هنا.
          </p>
        </div>
      ) : (
        <div className="space-y-3 mt-4">
          {favorites.map((hadith) => (
            <div
              key={`fav-${hadith.number}`}
              onClick={() => onSelectHadith(hadith)}
              className="flex items-start gap-3.5 p-4 rounded-2xl bg-white/70 dark:bg-[#1E2B22] border border-[#E1DACB] dark:border-white/5 cursor-pointer hover:border-[#3C6B4A]/40 dark:hover:border-[#8FC49A]/40 transition-all select-none shadow-sm active:scale-[0.99]"
            >
              {/* Number Badge */}
              <div className="flex-shrink-0 w-10 h-10 rounded-full bg-[#3C6B4A]/10 dark:bg-[#3C6B4A]/30 flex items-center justify-center text-[#3C6B4A] dark:text-[#8FC49A] font-bold text-sm">
                {toArabicDigits(hadith.number)}
              </div>

              {/* Text */}
              <div className="flex-1 min-w-0">
                <h3 className="text-sm font-bold text-[#2B2B25] dark:text-[#EDEAE0] truncate">
                  {hadith.title}
                </h3>
                <p className="text-xs font-naskh text-[#7A7A6E] dark:text-[#A7B3A9] line-clamp-2 mt-1 leading-relaxed">
                  {hadith.text}
                </p>
                <div className="flex items-center gap-1 mt-2.5 text-[11px] font-bold text-[#3C6B4A] dark:text-[#8FC49A]">
                  <Heart className="w-3.5 h-3.5 fill-[#3C6B4A] dark:fill-[#8FC49A]" />
                  <span>محفوظ</span>
                </div>
              </div>

              {/* Chevron */}
              <ChevronLeft className="w-4 h-4 text-[#7A7A6E]/60 flex-shrink-0 mt-3" />
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
