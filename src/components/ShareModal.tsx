import React, { useState, useRef } from 'react';
import { X, Download, Share2, Copy, Check } from 'lucide-react';
import { toPng } from 'html-to-image';
import { Hadith, ShareStyle } from '../types';

interface ShareModalProps {
  hadith: Hadith;
  defaultStyle?: ShareStyle;
  isOpen: boolean;
  onClose: () => void;
  onShowToast: (message: string) => void;
}

export const ShareModal: React.FC<ShareModalProps> = ({
  hadith,
  defaultStyle = 'cream',
  isOpen,
  onClose,
  onShowToast,
}) => {
  const [style, setStyle] = useState<ShareStyle>(defaultStyle);
  const [isExporting, setIsExporting] = useState(false);
  const [copiedText, setCopiedText] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

  if (!isOpen) return null;

  const styleConfigs = {
    cream: {
      name: 'الورق الكريمي',
      bgClass: 'bg-[#F7F2E8] border border-[#E1DACB]',
      titleColor: 'text-[#3C6B4A]',
      textColor: 'text-[#2B2B25]',
      sourceColor: 'text-[#7A7A6E]',
      dividerColor: 'bg-[#3C6B4A]/30',
      brandColor: 'text-[#7A7A6E]/70',
    },
    forest: {
      name: 'الأخضر الهادئ',
      bgClass: 'bg-[#315A46] border border-[#3C6B4A]',
      titleColor: 'text-[#D5B37A]',
      textColor: 'text-[#F5F1E8]',
      sourceColor: 'text-[#EAF2EC]/85',
      dividerColor: 'bg-[#D5B37A]/50',
      brandColor: 'text-[#F5F1E8]/60',
    },
    midnight: {
      name: 'المساء',
      bgClass: 'bg-[#142019] border border-[#1E2B22]',
      titleColor: 'text-[#D5B37A]',
      textColor: 'text-[#F5F1E8]',
      sourceColor: 'text-[#EDEAE0]/80',
      dividerColor: 'bg-[#D5B37A]/50',
      brandColor: 'text-[#F5F1E8]/50',
    },
  };

  const currentCfg = styleConfigs[style];

  const handleDownloadImage = async () => {
    if (!cardRef.current) return;
    try {
      setIsExporting(true);
      const dataUrl = await toPng(cardRef.current, {
        cacheBust: true,
        pixelRatio: 2,
      });
      const link = document.createElement('a');
      link.download = `hadith_${hadith.number}_${style}.png`;
      link.href = dataUrl;
      link.click();
      onShowToast('تم حفظ بطاقة الحديث كصورة بنجاح!');
    } catch (err) {
      console.error('Error generating image', err);
      onShowToast('حدث خطأ أثناء تحميل الصورة.');
    } finally {
      setIsExporting(false);
    }
  };

  const handleNativeShare = async () => {
    const shareText = `«${hadith.text}»\n${hadith.source ? `— ${hadith.source}\n` : ''}\n(من تطبيق حديثك اليوم - الأربعون النووية)`;
    if (navigator.share) {
      try {
        await navigator.share({
          title: `حديثك اليوم - ${hadith.title}`,
          text: shareText,
        });
        onShowToast('تمت المشاركة بنجاح');
      } catch {
        // User cancelled or not supported
      }
    } else {
      // Fallback to copy
      handleCopyText();
    }
  };

  const handleCopyText = async () => {
    const shareText = `«${hadith.text}»\n${hadith.source ? `— ${hadith.source}\n` : ''}\n(من تطبيق حديثك اليوم - الأربعون النووية)`;
    try {
      await navigator.clipboard.writeText(shareText);
      setCopiedText(true);
      onShowToast('تم نسخ نص الحديث إلى الحافظة!');
      setTimeout(() => setCopiedText(false), 2000);
    } catch {
      onShowToast('تعذر نسخ النص.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fade-in">
      <div className="relative w-full max-w-lg bg-[#F6F1E7] dark:bg-[#1A261F] rounded-[28px] p-5 sm:p-6 shadow-2xl overflow-hidden max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#E1DACB] dark:border-white/10">
          <div>
            <h3 className="text-lg font-bold text-[#2B2B25] dark:text-[#EDEAE0]">
              اختار شكل المشاركة
            </h3>
            <p className="text-xs text-[#7A7A6E] dark:text-[#A7B3A9]">
              نفس الحديث، بثلاث شخصيات بصرية مختلفة
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2 rounded-full text-[#7A7A6E] hover:text-[#2B2B25] dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Style Selector Tabs */}
        <div className="grid grid-cols-3 gap-2 my-4">
          {(['cream', 'forest', 'midnight'] as ShareStyle[]).map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => setStyle(s)}
              className={`py-2 px-2 text-xs font-bold rounded-xl transition-all ${
                style === s
                  ? 'bg-[#3C6B4A] text-white shadow-md'
                  : 'bg-black/5 dark:bg-white/5 text-[#7A7A6E] dark:text-[#A7B3A9] hover:bg-black/10'
              }`}
            >
              {styleConfigs[s].name}
            </button>
          ))}
        </div>

        {/* Card Preview Container */}
        <div className="flex-1 overflow-y-auto py-2 px-1 flex items-center justify-center">
          <div
            ref={cardRef}
            className={`w-full rounded-[24px] p-6 sm:p-8 text-center transition-all duration-300 ${currentCfg.bgClass} shadow-lg`}
          >
            <div className={`text-base sm:text-lg font-bold ${currentCfg.titleColor} mb-4 font-kufi`}>
              حديثك اليوم
            </div>

            <p className={`font-naskh text-lg sm:text-xl font-semibold leading-[1.8] ${currentCfg.textColor} mb-4`}>
              {hadith.text}
            </p>

            {hadith.source && (
              <div className="flex flex-col items-center gap-2 mt-4 pt-4">
                <div className={`w-12 h-[1.5px] ${currentCfg.dividerColor}`} />
                <p className={`text-xs sm:text-sm font-medium ${currentCfg.sourceColor}`}>
                  {hadith.source}
                </p>
              </div>
            )}

            <div className={`mt-5 text-[11px] font-bold tracking-wider ${currentCfg.brandColor}`}>
              Hadith Daily • الأربعون النووية
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="grid grid-cols-3 gap-2 mt-4 pt-3 border-t border-[#E1DACB] dark:border-white/10">
          <button
            type="button"
            onClick={handleDownloadImage}
            disabled={isExporting}
            className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-[#3C6B4A] hover:bg-[#345c40] text-white text-xs sm:text-sm font-bold transition-all shadow active:scale-95 disabled:opacity-50"
          >
            <Download className="w-4 h-4" />
            <span>{isExporting ? 'جاري...' : 'تحميل صورة'}</span>
          </button>

          <button
            type="button"
            onClick={handleNativeShare}
            className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-[#3C6B4A]/10 hover:bg-[#3C6B4A]/20 dark:bg-white/10 text-[#3C6B4A] dark:text-[#8FC49A] text-xs sm:text-sm font-bold transition-all active:scale-95"
          >
            <Share2 className="w-4 h-4" />
            <span>مشاركة</span>
          </button>

          <button
            type="button"
            onClick={handleCopyText}
            className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-[#3C6B4A]/10 hover:bg-[#3C6B4A]/20 dark:bg-white/10 text-[#3C6B4A] dark:text-[#8FC49A] text-xs sm:text-sm font-bold transition-all active:scale-95"
          >
            {copiedText ? <Check className="w-4 h-4 text-green-600" /> : <Copy className="w-4 h-4" />}
            <span>{copiedText ? 'تم النسخ' : 'نسخ النص'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};
