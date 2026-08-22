import React, { useState } from 'react';
import { ChevronRight, Bookmark, ChevronLeft } from 'lucide-react';
import { Hadith } from '../types';
import { toArabicDigits } from '../utils';

interface LibraryScreenProps {
  hadiths: Hadith[];
  recentHadiths: Hadith[];
  favorites: number[];
  onSelectHadith: (hadith: Hadith) => void;
  onToggleFavorite: (hadithNumber: number) => void;
  onBack?: () => void;
}

export const LibraryScreen: React.FC<LibraryScreenProps> = ({
  hadiths,
  favorites,
  onSelectHadith,
  onToggleFavorite,
  onBack,
}) => {
  const [showOnlyFavorites, setShowOnlyFavorites] = useState(false);

  const displayedHadiths = showOnlyFavorites
    ? hadiths.filter((h) => favorites.includes(h.number))
    : hadiths;

  return (
    <div className="relative max-w-md mx-auto px-6 py-4 pb-28 text-right min-h-screen">
      {/* Background Sprigs */}
      <div className="fixed top-0 right-0 w-32 h-48 pointer-events-none opacity-30 z-0">
        <img
          src="/assets/botanical_top_right.svg"
          alt="Leaves"
          className="w-full h-full object-contain object-top-right"
        />
      </div>
      <div className="fixed bottom-0 left-0 w-32 h-48 pointer-events-none opacity-30 z-0">
        <img
          src="/assets/botanical_bottom_left.svg"
          alt="Leaves"
          className="w-full h-full object-contain object-bottom-left"
        />
      </div>

      {/* Top Header matching جميع الاحاديث.png */}
      <div className="relative z-10 flex items-center justify-between pb-3">
        {/* Back button */}
        <button
          type="button"
          onClick={onBack}
          className="w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 flex items-center justify-center text-[#26352C] dark:text-[#EDEAE0] shadow-sm hover:bg-[#F4EEE3]"
        >
          <ChevronRight className="w-6 h-6" />
        </button>

        {/* Center Heart Emblem */}
        <div className="flex flex-col items-center">
          <div className="w-12 h-12">
            <img
              src="/assets/heart_leaf_emblem.svg"
              alt="Heart Logo"
              className="w-full h-full object-contain"
            />
          </div>
          <div className="w-16 h-3 -mt-1 opacity-70">
            <img
              src="/assets/golden_divider.svg"
              alt="Divider"
              className="w-full h-full object-contain"
            />
          </div>
        </div>

        {/* Bookmark Filter button */}
        <button
          type="button"
          onClick={() => setShowOnlyFavorites(!showOnlyFavorites)}
          className={`w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 flex items-center justify-center shadow-sm transition-colors ${
            showOnlyFavorites
              ? 'text-[#B9A06A]'
              : 'text-[#26352C] dark:text-[#EDEAE0] hover:bg-[#F4EEE3]'
          }`}
        >
          <Bookmark className={`w-5 h-5 ${showOnlyFavorites ? 'fill-current' : ''}`} />
        </button>
      </div>

      {/* Title Area */}
      <div className="relative z-10 text-center my-4">
        <h1 className="text-2xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
          {showOnlyFavorites ? 'الأحاديث المحفوظة' : 'جميع الأحاديث'}
        </h1>
        <p className="text-xs sm:text-sm text-[#6E716C] dark:text-[#A7B3A9] font-kufi mt-1">
          استكشف و اقرأ الأحاديث النبوية و شرحها
        </p>
      </div>

      {/* Hadith List matching جميع الاحاديث.png */}
      <div className="relative z-10 space-y-3 my-5">
        {displayedHadiths.map((hadith, index) => {
          const isEven = index % 2 === 0;
          return (
            <div
              key={hadith.number}
              onClick={() => onSelectHadith(hadith)}
              className="bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 rounded-[22px] p-4 px-5 shadow-[0_2px_8px_rgba(0,0,0,0.02)] border border-[#D1BE93]/35 flex items-center justify-between gap-4 cursor-pointer hover:border-[#526B57]/50 transition-all group"
            >
              {/* Right Content in RTL: Number, Text snippet */}
              <div className="flex-1 min-w-0">
                <span className="text-xs font-bold text-[#B9A06A] font-kufi block mb-0.5">
                  الحديث {toArabicDigits(hadith.number)}
                </span>
                <p className="text-xs sm:text-[13px] text-[#26352C] dark:text-[#EDEAE0] font-naskh line-clamp-2 leading-relaxed">
                  {hadith.text}
                </p>
              </div>

              {/* Left Side: Decorative Badge (Flower / Leaf) + Chevron */}
              <div className="flex items-center gap-2.5 flex-shrink-0">
                <div className="w-10 h-10 rounded-full flex items-center justify-center">
                  <img
                    src={isEven ? '/assets/flower_badge.svg' : '/assets/leaf_badge.svg'}
                    alt="Badge"
                    className="w-full h-full object-contain"
                  />
                </div>

                <ChevronLeft className="w-4 h-4 text-[#AAA9A3] group-hover:text-[#526B57] transition-colors" />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
