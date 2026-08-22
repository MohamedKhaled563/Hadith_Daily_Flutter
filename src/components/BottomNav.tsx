import React from 'react';
import { Home, Users, Share2 } from 'lucide-react';
import { TabType } from '../types';

interface BottomNavProps {
  currentTab: TabType;
  onTabChange: (tab: TabType) => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({
  currentTab,
  onTabChange,
}) => {
  // Exact 3 tabs from home page.png:
  // Left: المشاركة | Middle: جميع المجتمع | Right: الرئيسية
  return (
    <div className="fixed bottom-4 inset-x-0 z-40 max-w-md mx-auto px-5 pointer-events-none">
      <nav className="pointer-events-auto grid grid-cols-3 items-center py-2.5 px-3 rounded-[26px] bg-[#F7F3EB]/95 dark:bg-[#1E2B22]/95 backdrop-blur-md border border-[#D1BE93]/40 dark:border-white/10 shadow-[0_8px_30px_rgba(0,0,0,0.06)] dark:shadow-[0_8px_30px_rgba(0,0,0,0.4)] divide-x divide-[#D1BE93]/30 dark:divide-white/10 divide-x-reverse">
        {/* Tab 1: الرئيسية (Home) - Right in RTL */}
        <button
          type="button"
          onClick={() => onTabChange('home')}
          className={`flex flex-col items-center justify-center gap-1 py-1 transition-all ${
            currentTab === 'home'
              ? 'text-[#26352C] dark:text-[#EDEAE0] font-bold'
              : 'text-[#6E716C] dark:text-[#A7B3A9] hover:text-[#26352C]'
          }`}
        >
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${
              currentTab === 'home'
                ? 'bg-[#FFFDFC] dark:bg-[#2A3B30] shadow-sm text-[#26352C] dark:text-white'
                : 'text-[#6E716C] dark:text-[#A7B3A9]'
            }`}
          >
            <Home className="w-5 h-5 fill-current stroke-[1.8]" />
          </div>
          <span className="text-xs font-kufi">الرئيسية</span>
        </button>

        {/* Tab 2: جميع المجتمع (Community) - Center */}
        <button
          type="button"
          onClick={() => onTabChange('community')}
          className={`flex flex-col items-center justify-center gap-1 py-1 transition-all ${
            currentTab === 'community'
              ? 'text-[#26352C] dark:text-[#EDEAE0] font-bold'
              : 'text-[#6E716C] dark:text-[#A7B3A9] hover:text-[#26352C]'
          }`}
        >
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${
              currentTab === 'community'
                ? 'bg-[#FFFDFC] dark:bg-[#2A3B30] shadow-sm text-[#26352C] dark:text-white'
                : 'text-[#6E716C] dark:text-[#A7B3A9]'
            }`}
          >
            <Users className="w-5 h-5 fill-current stroke-[1.8]" />
          </div>
          <span className="text-xs font-kufi">جميع المجتمع</span>
        </button>

        {/* Tab 3: المشاركة (Share / Add message) - Left in RTL */}
        <button
          type="button"
          onClick={() => onTabChange('share')}
          className={`flex flex-col items-center justify-center gap-1 py-1 transition-all ${
            currentTab === 'share'
              ? 'text-[#26352C] dark:text-[#EDEAE0] font-bold'
              : 'text-[#6E716C] dark:text-[#A7B3A9] hover:text-[#26352C]'
          }`}
        >
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${
              currentTab === 'share'
                ? 'bg-[#FFFDFC] dark:bg-[#2A3B30] shadow-sm text-[#26352C] dark:text-white'
                : 'text-[#6E716C] dark:text-[#A7B3A9]'
            }`}
          >
            <Share2 className="w-5 h-5 stroke-[2]" />
          </div>
          <span className="text-xs font-kufi">المشاركة</span>
        </button>
      </nav>
    </div>
  );
};
