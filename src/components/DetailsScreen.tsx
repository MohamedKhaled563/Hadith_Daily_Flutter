import React, { useState, useEffect } from 'react';
import { ChevronRight, Bookmark, Bell, Copy, Share2, Check } from 'lucide-react';
import { Hadith } from '../types';

interface DetailsScreenProps {
  hadith: Hadith;
  isFavorite: boolean;
  onToggleFavorite: () => void;
  onShare: () => void;
  onBack: () => void;
}

export const DetailsScreen: React.FC<DetailsScreenProps> = ({
  hadith,
  isFavorite,
  onToggleFavorite,
  onShare,
  onBack,
}) => {
  const [copied, setCopied] = useState(false);
  const [reminderSet, setReminderSet] = useState(false);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [hadith.number]);

  const handleCopy = () => {
    const fullText = `نص الحديث:\n${hadith.text}\n\nشرح الحديث:\n${hadith.explanation || ''}\n\nالمصدر: ${hadith.source || ''}`;
    navigator.clipboard.writeText(fullText);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="relative max-w-md mx-auto px-6 py-4 pb-36 text-right min-h-screen">
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

      {/* Top Header matching شرح الحديث.png */}
      <div className="relative z-10 flex items-center justify-between pb-3">
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

        {/* Bookmark button */}
        <button
          type="button"
          onClick={onToggleFavorite}
          className={`w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 flex items-center justify-center shadow-sm transition-colors ${
            isFavorite
              ? 'text-[#B9A06A]'
              : 'text-[#26352C] dark:text-[#EDEAE0] hover:bg-[#F4EEE3]'
          }`}
        >
          <Bookmark className={`w-5 h-5 ${isFavorite ? 'fill-current' : ''}`} />
        </button>
      </div>

      {/* Card 1: نص الحديث (White Card) */}
      <div className="relative z-10 bg-[#FFFDFC] dark:bg-[#1E2B22] rounded-[24px] p-6 sm:p-7 shadow-[0_4px_16px_rgba(0,0,0,0.04)] dark:shadow-[0_4px_16px_rgba(0,0,0,0.3)] border border-[#D1BE93]/35 my-4 text-center">
        {/* Header with flower badge */}
        <div className="flex items-center justify-center gap-2 mb-4">
          <div className="w-5 h-5">
            <img src="/assets/flower_badge.svg" alt="Icon" className="w-full h-full" />
          </div>
          <span className="text-sm font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
            نص الحديث
          </span>
        </div>

        {/* Hadith Text */}
        <p className="text-base sm:text-lg font-medium text-[#26352C] dark:text-[#EDEAE0] font-naskh leading-[2.2] sm:leading-[2.4]">
          {hadith.text}
        </p>

        {/* Source */}
        {hadith.source && (
          <p className="text-xs text-[#6E716C] dark:text-[#A7B3A9] font-kufi mt-4">
            {hadith.source}
          </p>
        )}

        {/* Bottom Gold Divider */}
        <div className="w-20 h-4 mx-auto mt-3 opacity-70">
          <img
            src="/assets/golden_divider.svg"
            alt="Divider"
            className="w-full h-full object-contain"
          />
        </div>
      </div>

      {/* Card 2: شرح الحديث (Beige Card) */}
      <div className="relative z-10 bg-[#F7F3EB] dark:bg-[#243428] rounded-[24px] p-6 sm:p-7 shadow-[0_4px_16px_rgba(0,0,0,0.02)] border border-[#D1BE93]/35 my-4">
        {/* Header with book icon */}
        <div className="flex items-center justify-center gap-2 mb-4">
          <div className="w-5 h-5">
            <img src="/assets/leaf_badge.svg" alt="Icon" className="w-full h-full" />
          </div>
          <span className="text-sm font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
            شرح الحديث
          </span>
        </div>

        {/* Explanation paragraphs */}
        <div className="text-xs sm:text-sm text-[#26352C] dark:text-[#EDEAE0] font-kufi leading-[2] space-y-3">
          {hadith.explanation ? (
            hadith.explanation.split('\n\n').map((para, i) => <p key={i}>{para}</p>)
          ) : (
            <p>
              يوضح لنا النبي صلى الله عليه وسلم معاني هذا الحديث المبارك وأهمية تطبيقه في سائر شؤون الحياة، ليعيش المسلم في طمأنينة وسلام داخلي وصلاح في دينه ودنياه.
            </p>
          )}
        </div>

        {/* Benefits Box matching شرح الحديث.png */}
        <div className="mt-5 p-4 rounded-[18px] bg-[#EAE4D7]/80 dark:bg-[#1E2B22]/80 border border-[#D1BE93]/30">
          <div className="flex items-center gap-1.5 text-xs font-bold text-[#526B57] dark:text-[#8FC49A] font-kufi mb-2">
            <span>من فوائد الحديث</span>
            <span>🌿</span>
          </div>

          <ul className="text-xs text-[#26352C] dark:text-[#EDEAE0] font-kufi space-y-1.5 leading-relaxed">
            <li className="flex items-start gap-1.5">
              <span className="text-[#526B57]">•</span>
              <span>الحث على طيب القلب وإخلاص النية لله تعالى.</span>
            </li>
            <li className="flex items-start gap-1.5">
              <span className="text-[#526B57]">•</span>
              <span>العناية بطهارة الأقوال والأفعال واجتناب الشبهات.</span>
            </li>
            <li className="flex items-start gap-1.5">
              <span className="text-[#526B57]">•</span>
              <span>تطبيق الهدي النبوي في التعامل بالرحمة والإحسان.</span>
            </li>
          </ul>
        </div>
      </div>

      {/* Floating Bottom Action Bar matching شرح الحديث.png */}
      <div className="fixed bottom-4 inset-x-0 z-40 max-w-md mx-auto px-5 pointer-events-none">
        <div className="pointer-events-auto grid grid-cols-4 items-center py-2.5 px-3 rounded-[24px] bg-[#F7F3EB]/95 dark:bg-[#1E2B22]/95 backdrop-blur-md border border-[#D1BE93]/40 shadow-[0_8px_25px_rgba(0,0,0,0.06)] divide-x divide-[#D1BE93]/30 divide-x-reverse">
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
            onClick={onToggleFavorite}
            className={`flex flex-col items-center justify-center gap-1 transition-colors ${
              isFavorite ? 'text-[#B9A06A]' : 'text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57]'
            }`}
          >
            <Bookmark className={`w-4 h-4 ${isFavorite ? 'fill-current' : ''}`} />
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
            onClick={() => setReminderSet(!reminderSet)}
            className={`flex flex-col items-center justify-center gap-1 transition-colors ${
              reminderSet ? 'text-[#526B57]' : 'text-[#26352C] dark:text-[#EDEAE0] hover:text-[#526B57]'
            }`}
          >
            <Bell className={`w-4 h-4 ${reminderSet ? 'fill-current' : ''}`} />
            <span className="text-[11px] font-kufi font-medium">{reminderSet ? 'مفعل' : 'تذكير'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};
