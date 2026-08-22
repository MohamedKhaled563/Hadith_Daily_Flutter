import React, { useState, useEffect, useCallback } from 'react';
import { Hadith, Insight, CommunityPost, TabType, ThemeMode, ShareStyle, ReminderSettings } from './types';
import { HadithRepository } from './services/hadithRepository';
import { PreferencesService } from './services/preferencesService';
import { HomeScreen } from './components/HomeScreen';
import { DailyMessageScreen } from './components/DailyMessageScreen';
import { CommunityScreen } from './components/CommunityScreen';
import { AddMessageScreen } from './components/AddMessageScreen';
import { LibraryScreen } from './components/LibraryScreen';
import { DetailsScreen } from './components/DetailsScreen';
import { BottomNav } from './components/BottomNav';
import { ShareModal } from './components/ShareModal';
import { Toast } from './components/Toast';

const DEFAULT_INSIGHTS: Insight[] = [
  {
    hadithNumber: 10,
    arabic: 'إن الله تعالى طيب لا يقبل إلا طيباً؛ فطيب قلبك بطهارة النية وصدق العمل وحلال الرزق.',
    english: 'God is pure and accepts only that which is pure; cleanse your heart with sincere intention.',
  },
  {
    hadithNumber: 1,
    arabic: 'قد يكون العمل نفسه عبادة عند شخص... وعادة عند آخر. والفرق يبدأ من النية.',
    english: 'The intention transforms daily habits into beloved acts of worship.',
  },
  {
    hadithNumber: 2,
    arabic: 'الإحسان أن تعبد الله كأنك تراه؛ استشعار قربه يملأ القلب سكينة وخشوعاً.',
    english: 'Excellence is to live with the conscious awareness of the Creator.',
  },
  {
    hadithNumber: 11,
    arabic: 'دع ما يريبك إلى ما لا يريبك؛ راحة الضمير وطمأنينة القلب أثمن ما تملكه.',
    english: 'Leave that which causes you doubt for that which brings clarity and peace.',
  },
  {
    hadithNumber: 12,
    arabic: 'سلامة قلبك تبدأ عندما تترك ما لا يعنيك، وتنشغل بما يصلح حالك ويقربك من ربك.',
    english: 'True mindfulness begins by letting go of matters that do not concern you.',
  },
  {
    hadithNumber: 13,
    arabic: 'اتساع قلبك لمحبة الخير للناس علامة اكتمال إيمانك ونقاء سريرتك.',
    english: 'Loving for others what you love for yourself is the essence of faith.',
  },
  {
    hadithNumber: 15,
    arabic: 'الكلمة الطيبة صدقة، والصمت عن الأذى سلامة لك ولمن حولك.',
    english: 'Speak good or remain silent; gentle words mend hearts.',
  },
  {
    hadithNumber: 16,
    arabic: 'لا تغضب؛ وصية نبوية جامعة تحفظ بها هدوءك وعلاقاتك وصفاء روحك.',
    english: 'Do not be overcome by anger; tranquility is the hallmark of strength.',
  },
];

const INITIAL_COMMUNITY_POSTS: CommunityPost[] = [
  {
    id: '1',
    authorName: 'أسماء محمد',
    message: 'أكثر ما أثر فيّ هذا الحديث هو معنى طيب القلب وصفاء السريرة في كل تفاصيل اليوم.',
    hadithNumber: 10,
    likes: 128,
  },
  {
    id: '2',
    authorName: 'عبدالله خالد',
    message: 'حاولت اليوم أن أطبق معنى الحديث في تعاملي مع أسرتي وزملائي، فوجدت بركة وسكينة.',
    hadithNumber: 1,
    likes: 96,
  },
  {
    id: '3',
    authorName: 'هبة الرحمن',
    message: 'سعادتي الحقيقية عندما أرى طيب القلب يظهر في الكلمة الطيبة والابتسامة الصادقة.',
    hadithNumber: 13,
    likes: 89,
  },
];

export function App() {
  const repo = HadithRepository.getInstance();
  const prefs = PreferencesService.getInstance();

  const allHadiths = repo.getAll();

  const [currentTab, setCurrentTab] = useState<TabType>('home');
  const [selectedHadith, setSelectedHadith] = useState<Hadith | null>(null);
  const [currentInsight, setCurrentInsight] = useState<Insight>(DEFAULT_INSIGHTS[0]);
  const [showingDailyMessage, setShowingDailyMessage] = useState(false);
  const [communityPosts, setCommunityPosts] = useState<CommunityPost[]>(INITIAL_COMMUNITY_POSTS);

  const [favorites, setFavorites] = useState<number[]>(() => prefs.getFavorites());
  const [history, setHistory] = useState<number[]>(() => prefs.getHistory());
  const [themeMode] = useState<ThemeMode>(() => prefs.getThemeMode());
  const [shareStyle] = useState<ShareStyle>(() => prefs.getShareStyle());
  const [shareModalHadith, setShareModalHadith] = useState<Hadith | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Theme application
  useEffect(() => {
    const root = document.documentElement;
    if (themeMode === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
  }, [themeMode]);

  // Toast helper
  const showToast = useCallback((msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage((current) => (current === msg ? null : current));
    }, 2400);
  }, []);

  // Favorite toggle
  const handleToggleFavorite = useCallback(
    (num: number) => {
      const isFav = prefs.toggleFavorite(num);
      setFavorites(prefs.getFavorites());
      showToast(isFav ? 'تم حفظ الحديث في المحفوظات' : 'تمت إزالة الحديث من المحفوظات');
    },
    [prefs, showToast]
  );

  // Mark read history
  const handleMarkRead = useCallback(
    (num: number) => {
      prefs.addToHistory(num);
      setHistory(prefs.getHistory());
    },
    [prefs]
  );

  // Trigger random insight
  const handleOpenDailyMessage = () => {
    const random = DEFAULT_INSIGHTS[Math.floor(Math.random() * DEFAULT_INSIGHTS.length)];
    setCurrentInsight(random);
    setShowingDailyMessage(true);
  };

  const handleOpenDetails = (hadith: Hadith) => {
    setSelectedHadith(hadith);
    handleMarkRead(hadith.number);
  };

  const handleBackFromDetails = () => {
    setSelectedHadith(null);
  };

  const handleCommunityLike = (postId: string) => {
    setCommunityPosts((prev) =>
      prev.map((p) => {
        if (p.id === postId) {
          const isLiked = !p.isLiked;
          return {
            ...p,
            isLiked,
            likes: p.likes + (isLiked ? 1 : -1),
          };
        }
        return p;
      })
    );
  };

  const handleAddCommunityPost = (data: {
    message: string;
    hadithNumber: number;
    authorName: string;
    shareToCommunity: boolean;
  }) => {
    if (data.shareToCommunity) {
      const newPost: CommunityPost = {
        id: Date.now().toString(),
        authorName: data.authorName,
        message: data.message,
        hadithNumber: data.hadithNumber,
        likes: 0,
      };
      setCommunityPosts((prev) => [newPost, ...prev]);
    }
    showToast('تمت مشاركة رسالتك بنجاح بارك الله فيك');
    setCurrentTab('community');
  };

  const activeHadith = repo.getByNumber(currentInsight.hadithNumber) || allHadiths[0];

  return (
    <div className="relative min-h-screen bg-[#F8F3EA] dark:bg-[#15201A] text-[#26352C] dark:text-[#EDEAE0] transition-colors overflow-x-hidden font-kufi">
      {/* Corner Botanical Foliage */}
      <div className="fixed top-0 right-0 w-36 h-36 opacity-35 dark:opacity-20 pointer-events-none z-0">
        <img
          src="/assets/botanical_top_right.svg"
          alt="Leaves"
          className="w-full h-full object-contain"
        />
      </div>
      <div className="fixed bottom-0 left-0 w-36 h-36 opacity-35 dark:opacity-20 pointer-events-none z-0">
        <img
          src="/assets/botanical_bottom_left.svg"
          alt="Leaves"
          className="w-full h-full object-contain"
        />
      </div>

      {/* Main Container */}
      <main className="relative z-10">
        {selectedHadith ? (
          <DetailsScreen
            hadith={selectedHadith}
            isFavorite={favorites.includes(selectedHadith.number)}
            onBack={handleBackFromDetails}
            onToggleFavorite={() => handleToggleFavorite(selectedHadith.number)}
            onShare={() => setShareModalHadith(selectedHadith)}
          />
        ) : showingDailyMessage ? (
          <DailyMessageScreen
            insight={currentInsight}
            hadith={activeHadith}
            onBack={() => setShowingDailyMessage(false)}
            onOpenHadith={handleOpenDetails}
            onShare={() => setShareModalHadith(activeHadith)}
          />
        ) : currentTab === 'home' ? (
          <HomeScreen
            hadith={activeHadith}
            insight={currentInsight}
            onOpenDailyMessage={handleOpenDailyMessage}
            onOpenAllHadiths={() => setCurrentTab('library')}
          />
        ) : currentTab === 'community' ? (
          <CommunityScreen
            posts={communityPosts}
            onToggleLike={handleCommunityLike}
            onSelectPost={(post) => {
              const h = repo.getByNumber(post.hadithNumber);
              if (h) handleOpenDetails(h);
            }}
            onOpenAddPost={() => setCurrentTab('share')}
            onBack={() => setCurrentTab('home')}
          />
        ) : currentTab === 'share' ? (
          <AddMessageScreen
            hadiths={allHadiths}
            onSubmit={handleAddCommunityPost}
            onBack={() => setCurrentTab('home')}
          />
        ) : currentTab === 'library' ? (
          <LibraryScreen
            hadiths={allHadiths}
            recentHadiths={history
              .map((num) => repo.getByNumber(num))
              .filter((h): h is Hadith => !!h)}
            favorites={favorites}
            onSelectHadith={handleOpenDetails}
            onToggleFavorite={handleToggleFavorite}
            onBack={() => setCurrentTab('home')}
          />
        ) : null}
      </main>

      {/* Persistent Floating Bottom Navigation */}
      {!selectedHadith && !showingDailyMessage && (
        <BottomNav
          currentTab={currentTab}
          onTabChange={(tab) => {
            setCurrentTab(tab);
            setShowingDailyMessage(false);
          }}
        />
      )}

      {/* Share Modal */}
      {shareModalHadith && (
        <ShareModal
          hadith={shareModalHadith}
          defaultStyle={shareStyle}
          isOpen={true}
          onClose={() => setShareModalHadith(null)}
          onShowToast={showToast}
        />
      )}

      {/* Toast Notification */}
      <Toast message={toastMessage} />
    </div>
  );
}
export default App;
