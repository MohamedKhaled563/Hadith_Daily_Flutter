export interface Hadith {
  number: number;
  title: string;
  text: string;
  source: string | null;
  explanation: string;
}

export interface Insight {
  hadithNumber: number;
  arabic: string;
  english: string;
}

export interface CommunityPost {
  id: string;
  authorName: string;
  message: string;
  hadithNumber: number;
  likes: number;
  isLiked?: boolean;
}

export type ThemeMode = 'system' | 'light' | 'dark';

export type ShareStyle = 'cream' | 'forest' | 'midnight';

export interface ReminderSettings {
  enabled: boolean;
  hour: number;
  minute: number;
}

export type TabType = 'home' | 'community' | 'share' | 'library' | 'favorites' | 'settings';
