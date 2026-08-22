import React, { useState } from 'react';
import { ChevronRight, Users, ChevronDown, Check } from 'lucide-react';
import { Hadith } from '../types';

interface AddMessageScreenProps {
  hadiths: Hadith[];
  onSubmit: (data: {
    message: string;
    hadithNumber: number;
    authorName: string;
    shareToCommunity: boolean;
  }) => void;
  onBack?: () => void;
}

export const AddMessageScreen: React.FC<AddMessageScreenProps> = ({
  hadiths,
  onSubmit,
  onBack,
}) => {
  const [message, setMessage] = useState('');
  const [hadithNumber, setHadithNumber] = useState<number>(hadiths[0]?.number || 1);
  const [authorName, setAuthorName] = useState('');
  const [shareToCommunity, setShareToCommunity] = useState(true);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!message.trim()) return;

    onSubmit({
      message: message.trim(),
      hadithNumber: Number(hadithNumber),
      authorName: authorName.trim() || 'فاعل خير',
      shareToCommunity,
    });
  };

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

      {/* Top Header matching اضف رسالة.png */}
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

        {/* Community / Users icon */}
        <div className="w-11 h-11 rounded-full border border-[#D1BE93]/40 bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 flex items-center justify-center text-[#26352C] dark:text-[#EDEAE0] shadow-sm">
          <Users className="w-5 h-5" />
        </div>
      </div>

      {/* Title matching اضف رسالة.png */}
      <div className="relative z-10 text-center my-4">
        <h1 className="text-2xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
          أضف رسالة
        </h1>
        <div className="w-20 h-4 mx-auto mt-1 opacity-80">
          <img
            src="/assets/golden_divider.svg"
            alt="Divider"
            className="w-full h-full object-contain"
          />
        </div>
      </div>

      {/* Form matching اضف رسالة.png */}
      <form onSubmit={handleSubmit} className="relative z-10 space-y-4 my-5">
        {/* Field 1: الرسالة 🌿 */}
        <div>
          <label className="flex items-center gap-1.5 text-xs font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi mb-1.5">
            <span>الرسالة</span>
            <span>🌿</span>
          </label>
          <textarea
            required
            rows={4}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="اكتب رسالتك هنا..."
            className="w-full rounded-[20px] bg-[#FFFDFC] dark:bg-[#1E2B22] border border-[#D1BE93]/40 p-4 text-sm font-naskh text-[#26352C] dark:text-[#EDEAE0] placeholder-[#A7A9A4] focus:outline-none focus:border-[#526B57] shadow-sm resize-none"
          />
        </div>

        {/* Field 2: الحديث 🌿 */}
        <div>
          <label className="flex items-center gap-1.5 text-xs font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi mb-1.5">
            <span>الحديث</span>
            <span>🌿</span>
          </label>
          <div className="relative">
            <select
              value={hadithNumber}
              onChange={(e) => setHadithNumber(Number(e.target.value))}
              className="w-full appearance-none rounded-[20px] bg-[#FFFDFC] dark:bg-[#1E2B22] border border-[#D1BE93]/40 p-3.5 pr-4 pl-10 text-xs sm:text-sm font-kufi text-[#26352C] dark:text-[#EDEAE0] focus:outline-none focus:border-[#526B57] shadow-sm cursor-pointer"
            >
              {hadiths.map((h) => (
                <option key={h.number} value={h.number}>
                  الحديث {h.number}: {h.title}
                </option>
              ))}
            </select>
            <ChevronDown className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-[#7A7E76] pointer-events-none" />
          </div>
        </div>

        {/* Field 3: الإسم 🌿 */}
        <div>
          <label className="flex items-center gap-1.5 text-xs font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi mb-1.5">
            <span>الإسم</span>
            <span>🌿</span>
          </label>
          <input
            type="text"
            value={authorName}
            onChange={(e) => setAuthorName(e.target.value)}
            placeholder="اكتب اسمك"
            className="w-full rounded-[20px] bg-[#FFFDFC] dark:bg-[#1E2B22] border border-[#D1BE93]/40 p-3.5 px-4 text-xs sm:text-sm font-kufi text-[#26352C] dark:text-[#EDEAE0] placeholder-[#A7A9A4] focus:outline-none focus:border-[#526B57] shadow-sm"
          />
        </div>

        {/* Checkbox: شارك في المجتمع */}
        <label className="flex items-center gap-2 cursor-pointer pt-1 select-none">
          <div
            onClick={() => setShareToCommunity(!shareToCommunity)}
            className={`w-5 h-5 rounded-md border flex items-center justify-center transition-colors ${
              shareToCommunity
                ? 'bg-[#526B57] border-[#526B57] text-white'
                : 'border-[#D1BE93]/60 bg-[#FFFDFC]'
            }`}
          >
            {shareToCommunity && <Check className="w-3.5 h-3.5 stroke-[3]" />}
          </div>
          <span className="text-xs text-[#26352C] dark:text-[#EDEAE0] font-kufi">
            شارك في المجتمع
          </span>
        </label>

        {/* Submit Button matching اضف رسالة.png */}
        <div className="pt-3">
          <button
            type="submit"
            className="w-full flex items-center justify-center gap-2 py-3.5 rounded-full bg-[#526B57] hover:bg-[#445948] active:scale-[0.99] text-white font-bold text-sm font-kufi shadow-md transition-all"
          >
            <span>شارك</span>
            <span>🌿</span>
          </button>
        </div>
      </form>
    </div>
  );
};
