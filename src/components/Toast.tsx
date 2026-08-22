import React from 'react';
import { CheckCircle2 } from 'lucide-react';

interface ToastProps {
  message: string | null;
}

export const Toast: React.FC<ToastProps> = ({ message }) => {
  if (!message) return null;

  return (
    <div className="fixed top-5 inset-x-0 z-50 flex justify-center px-4 pointer-events-none animate-fade-in">
      <div className="flex items-center gap-2 py-2.5 px-4 rounded-2xl bg-[#2B2B25]/90 dark:bg-white/95 text-white dark:text-[#2B2B25] text-xs sm:text-sm font-bold shadow-xl backdrop-blur-sm">
        <CheckCircle2 className="w-4 h-4 text-[#8FC49A] dark:text-[#3C6B4A]" />
        <span>{message}</span>
      </div>
    </div>
  );
};
