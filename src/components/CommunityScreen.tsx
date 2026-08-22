import React from 'react';
import { ChevronRight, Users, Heart, ChevronLeft, User } from 'lucide-react';
import { CommunityPost } from '../types';

interface CommunityScreenProps {
  posts: CommunityPost[];
  onToggleLike: (postId: string) => void;
  onSelectPost: (post: CommunityPost) => void;
  onOpenAddPost?: () => void;
  onBack?: () => void;
}

const TOP_10_COMMUNITY_DATA = [
  {
    id: '1',
    rank: 1,
    name: 'أسماء محمد',
    text: 'أكثر ما أثر فيّ هذا الحديث هو معنى طيب القلب...',
    hadithNumber: 10,
    likes: 128,
  },
  {
    id: '2',
    rank: 2,
    name: 'عبدالله خالد',
    text: 'حاولت اليوم أن أطبق معنى الحديث في تعاملي...',
    hadithNumber: 1,
    likes: 96,
  },
  {
    id: '3',
    rank: 3,
    name: 'هبة الرحمن',
    text: 'سعادتي الحقيقية عندما أرى طيب القلب يظهر...',
    hadithNumber: 13,
    likes: 89,
  },
  {
    id: '4',
    rank: 4,
    name: 'محمد علي',
    text: 'تعلمت أن الطيبة ليست ضعفاً، بل قوة عظيمة...',
    hadithNumber: 16,
    likes: 77,
  },
  {
    id: '5',
    rank: 5,
    name: 'نور مصطفى',
    text: 'التذكير اليومي بهذا الحديث يغير يومي بالكامل...',
    hadithNumber: 2,
    likes: 66,
  },
  {
    id: '6',
    rank: 6,
    name: 'سارة أحمد',
    text: 'أحاول دائماً أن أكون سبباً في راحة من حولي...',
    hadithNumber: 15,
    likes: 58,
  },
  {
    id: '7',
    rank: 7,
    name: 'ياسر الفاروق',
    text: 'عندما نُحسن النية، يرزقنا الله القبول والتوفيق...',
    hadithNumber: 1,
    likes: 49,
  },
  {
    id: '8',
    rank: 8,
    name: 'مريم حسن',
    text: 'الحديث يذكرني أن أبدأ يومي بابتسامة ونية طيبة...',
    hadithNumber: 18,
    likes: 41,
  },
  {
    id: '9',
    rank: 9,
    name: 'فاطمة الزهراء',
    text: 'جميل أن يكون هدفنا رضا الله في كل أفعالنا...',
    hadithNumber: 11,
    likes: 36,
  },
  {
    id: '10',
    rank: 10,
    name: 'أحمد إبراهيم',
    text: 'طيب القلب يجلب المحبة ويقرب القلوب من بعض...',
    hadithNumber: 12,
    likes: 32,
  },
];

export const CommunityScreen: React.FC<CommunityScreenProps> = ({
  posts,
  onToggleLike,
  onSelectPost,
  onOpenAddPost,
  onBack,
}) => {
  const [likesState, setLikesState] = React.useState<Record<string, { likes: number; liked: boolean }>>(() => {
    const init: Record<string, { likes: number; liked: boolean }> = {};
    TOP_10_COMMUNITY_DATA.forEach((item) => {
      init[item.id] = { likes: item.likes, liked: false };
    });
    return init;
  });

  const handleLike = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setLikesState((prev) => {
      const current = prev[id] || { likes: 0, liked: false };
      const nextLiked = !current.liked;
      return {
        ...prev,
        [id]: {
          likes: current.likes + (nextLiked ? 1 : -1),
          liked: nextLiked,
        },
      };
    });
  };

  return (
    <div className="relative max-w-md mx-auto px-6 py-4 pb-28 text-right min-h-screen">
      {/* Botanical Background Sprigs */}
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

      {/* Top Header matching المجتمع.png */}
      <div className="relative z-10 flex items-center justify-between pb-3">
        {/* Back / Navigation button on right in RTL */}
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

      {/* Title Area */}
      <div className="relative z-10 text-center my-4">
        <h1 className="text-2xl font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi">
          مجتمع الحديث
        </h1>
        <p className="text-xs sm:text-sm text-[#6E716C] dark:text-[#A7B3A9] font-kufi mt-1">
          أفضل 10 مشاركات لهذا الأسبوع
        </p>
      </div>

      {/* 10 Community Cards List matching المجتمع.png */}
      <div className="relative z-10 space-y-2.5 my-5">
        {TOP_10_COMMUNITY_DATA.map((item) => {
          const postLike = likesState[item.id] || { likes: item.likes, liked: false };

          return (
            <div
              key={item.id}
              onClick={() =>
                onSelectPost({
                  id: item.id,
                  authorName: item.name,
                  message: item.text,
                  hadithNumber: item.hadithNumber,
                  likes: postLike.likes,
                  isLiked: postLike.liked,
                })
              }
              className="bg-[#FFFDFC]/90 dark:bg-[#1E2B22]/90 rounded-[20px] p-3.5 px-4 shadow-[0_2px_8px_rgba(0,0,0,0.02)] border border-[#D1BE93]/30 flex items-center justify-between gap-3 cursor-pointer hover:border-[#526B57]/40 transition-all"
            >
              {/* Right Side in RTL: Rank & Avatar & Text */}
              <div className="flex items-center gap-3 min-w-0 flex-1">
                {/* Rank Pill */}
                <div className="w-7 h-7 rounded-full bg-[#F4EEE3] dark:bg-[#2A3B30] text-[#B9A06A] dark:text-[#E2C78E] font-bold text-xs flex items-center justify-center flex-shrink-0 font-kufi">
                  {item.rank}
                </div>

                {/* Avatar */}
                <div className="w-9 h-9 rounded-full bg-[#EAE4D7] dark:bg-[#27382D] text-[#8C8F89] flex items-center justify-center flex-shrink-0">
                  <User className="w-5 h-5 opacity-70" />
                </div>

                {/* Name & Text */}
                <div className="min-w-0 flex-1">
                  <h3 className="text-sm font-bold text-[#26352C] dark:text-[#EDEAE0] font-kufi truncate">
                    {item.name}
                  </h3>
                  <p className="text-xs text-[#6E716C] dark:text-[#A7B3A9] font-naskh truncate mt-0.5">
                    {item.text}
                  </p>
                </div>
              </div>

              {/* Left Side in RTL: Heart + Like Count & Chevron Arrow */}
              <div className="flex items-center gap-2.5 flex-shrink-0">
                <button
                  type="button"
                  onClick={(e) => handleLike(item.id, e)}
                  className="flex items-center gap-1 text-xs text-[#6E716C] dark:text-[#A7B3A9] hover:text-red-500 transition-colors"
                >
                  <Heart
                    className={`w-4 h-4 ${
                      postLike.liked ? 'fill-red-500 text-red-500' : 'text-[#7D8F78]'
                    }`}
                  />
                  <span className="font-semibold">{postLike.likes}</span>
                </button>

                <ChevronLeft className="w-4 h-4 text-[#AAA9A3]" />
              </div>
            </div>
          );
        })}
      </div>

      {/* Bottom Encouragement Banner matching المجتمع.png */}
      <div className="relative z-10 pt-4 text-center">
        <button
          type="button"
          onClick={onOpenAddPost}
          className="inline-flex items-center gap-2 text-xs sm:text-sm text-[#526B57] dark:text-[#8FC49A] font-semibold font-kufi hover:opacity-80 transition-opacity"
        >
          <span>❖</span>
          <span>شارك رسالتك وكن سبباً في نشر الخير</span>
          <span>❖</span>
        </button>
      </div>
    </div>
  );
};
