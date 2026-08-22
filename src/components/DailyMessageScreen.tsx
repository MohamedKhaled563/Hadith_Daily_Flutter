import React, { useState } from 'react';
import { ChevronRight, Bookmark, Bell, Copy, Share2, Check } from 'lucide-react';
import { Hadith, Insight } from '../types';

interface DailyMessageScreenProps {
  insight: Insight;
  hadith?: Hadith;
  onBack: () => void;
  onOpenHadith: (hadith: Hadith) => void;
  onShare: () => void;
}

export const DailyMessageScreen: React.FC<DailyMessageScreenProps> = ({
  insight,
  hadith,
  onBack,
  onOpenHadith,
  onShare,
}) => {
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [copied, setCopied] = useState(false);
  const [reminderSet, setReminderSet] = useState(false);

  const handleCopy = () => {
    const textToCopy = `${insight.arabic}\n\n${hadith ? `متصل بـ: ${hadith.title}` : ''}`;
    navigator.clipboard.writeText(textToCopy);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleToggleReminder = () => {
    setReminderSet(!reminderSet);
  };

  return (
    <div className="relative flex flex-col justify-between min-h-[calc(100vh-2rem)] max-w-md mx-auto px-6 py-4 pb-28 text-center select-none overflow-hidden">
      {/* Top Bar matching screenshot */}
      <div className="flex items-center justify-between w-full pt-1 z-20">
        {/* Back button on right in RTL / left */}
        <button
          type="button"
          onClick={onBack}
          className="w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/80 dark:bg-[#1E2B22]/80 flex items-center justify-center text-[#26352C] dark:text-[#EDEAE0] shadow-sm hover:bg-[#F4EEE3] transition-colors"
        >
          <ChevronRight className="w-6 h-6" />
        </button>

        {/* Center Heart + Leaf Emblem */}
        <div className="w-12 h-12 flex items-center justify-center">
          <img
            src="/assets/heart_leaf_emblem.svg"
            alt="Emblem"
            className="w-full h-full object-contain"
          />
        </div>

        {/* Bookmark button */}
        <button
          type="button"
          onClick={() => setIsBookmarked(!isBookmarked)}
          className={`w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/80 dark:bg-[#1E2B22]/80 flex items-center justify-center shadow-sm transition-colors ${
            isBookmarked
              ? 'text-[#B9A06A] fill-[#B9A06A]'
              : 'text-[#26352C] dark:text-[#EDEAE0] hover:bg-[#F4EEE3]'
          }`}
        >
          <Bookmark className={`w-5 h-5 ${isBookmarked ? 'fill-current' : ''}`} />
        </button>
      </div>

      {/* Main Message Card */}
      <div className="my-auto py-4 z-20">
        <div className="relative bg-[#FFFDFC] dark:bg-[#1E2B22] rounded-[28px] shadow-[0_12px_32px_rgba(0,0,0,0.04)] dark:shadow-[0_12px_32px_rgba(0,0,0,0.3)] border border-[#D1BE93]/30 p-8 sm:p-10 text-center overflow-hidden">
          {/* Top-Right Decorative Branch */}
          <div className="absolute top-0 right-0 w-24 h-24 pointer-events-none opacity-40">
            <img
              src="/assets/botanical_top_right.svg"
              alt="Leaf"
              className="w-full h-full object-contain object-top-right"
            />
          </div>

          {/* Bottom-Left Decorative Branch */}
          <div className="absolute bottom-0 left-0 w-24 h-24 pointer-events-none opacity-40">
            <img
              src="/assets/botanical_bottom_left.svg"
              alt="Leaf"
              className="w-full h-full object-contain object-bottom-left"
            />
          </div>

          {/* Quotation Marks */}
          <span className="text-4xl sm:text-5xl text-[#B9A06A] font-serif leading-none select-none block mb-3">
            ”
          </span>

          {/* Arabic Message */}
          <p className="text-xl sm:text-2xl font-semibold text-[#26352C] dark:text-[#EDEAE0] font-naskh leading-[2.1] sm:leading-[2.3] relative z-10">
            {insight.arabic}
          </p>

          {/* English Insight */}
          {insight.english && (
            <div className="mt-6 pt-4 border-t border-[#D1BE93]/30 relative z-10">
              <p className="text-xs sm:text-sm text-[#6E716C] dark:text-[#A7B3A9] italic font-kufi leading-relaxed">
                {insight.english}
              </p>
            </div>
          )}

          {/* Related Hadith Button */}
          {hadith && (
            <div className="mt-6 relative z-10">
              <button
                type="button"
                onClick={() => onOpenHadith(hadith)}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#F4EEE3] dark:bg-[#27382D] text-[#526B57] dark:text-[#8FC49A] text-xs sm:text-sm font-bold font-kufi border border-[#D1BE93]/30 hover:opacity-90 transition-opacity"
              >
                <span>شرح الحديث ({hadith.title})</span>
                <span className="text-xs">←</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Floating Bottom Action Bar matching screenshot */}
      <div className="z-20 w-full max-w-sm mx-auto">
        <div className="grid grid-cols-4 items-center py-2.5 px-3 rounded-[24px] bg-[#F7F3EB]/95 dark:bg-[#1E2B22]/95 backdrop-blur-md border border-[#D1BE93]/40 shadow-[0_8px_25px_rgba(0,0,0,0.06)] divide-x divide-[#D1BE93]/30 divide-x-reverse">
          {/* مشاركة (Share) */}
          <button
            type="button"
            onClick={onShare}
            className="flex flex-col items-center justify-center gap-1 text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57] transition-colors"
          >
            <Share2 className="w-4 h-4" />
            <span className="text-[11px] font-kufi font-medium">مشاركة</span>
          </button>

          {/* حفظ (Save) */}
          <button
            type="button"
            onClick={() => setIsBookmarked(!isBookmarked)}
            className={`flex flex-col items-center justify-center gap-1 transition-colors ${
              isBookmarked ? 'text-[#B9A06A]' : 'text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57]'
            }`}
          >
            <Bookmark className={`w-4 h-4 ${isBookmarked ? 'fill-current' : ''}`} />
            <span className="text-[11px] font-kufi font-medium">حفظ</span>
          </button>

          {/* نسخ (Copy) */}
          <button
            type="button"
            onClick={handleCopy}
            className="flex flex-col items-center justify-center gap-1 text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57] transition-colors"
          >
            {copied ? <Check className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
            <span className="text-[11px] font-kufi font-medium">{copied ? 'تم النسخ' : 'نسخ'}</span>
          </button>

          {/* تذكير (Reminder) */}
          <button
            type="button"
            onClick={handleToggleReminder}
            className={`flex flex-col items-center justify-center gap-1 transition-colors ${
              reminderSet ? 'text-[#526B57]' : 'text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57]'
            }`}
          >
            <Bell className={`w-4 h-4 ${reminderSet ? 'fill-current' : ''}`} />
            <span className="text-[11px] font-kufi font-medium">{reminderSet ? 'مفعل' : 'تذكير'}</span>
          </button>
        </div>
      </div>

      {/* Bottom Sunset Landscape */}
      <div className="absolute inset-x-0 bottom-0 h-48 pointer-events-none z-10 opacity-70 dark:opacity-30">
        <img
          src="/assets/sunset_landscape.svg"
          alt="Sunset Lake"
          className="w-full h-full object-cover object-bottom"
        />
      </div>
    </div>
  );
};
