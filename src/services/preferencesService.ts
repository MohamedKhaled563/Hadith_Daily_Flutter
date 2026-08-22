import { ThemeMode, ShareStyle, ReminderSettings } from '../types';

const STORAGE_KEYS = {
  FAVORITES: 'hadith_daily_favorites',
  HISTORY: 'hadith_daily_history',
  THEME_MODE: 'hadith_daily_theme_mode',
  SHARE_STYLE: 'hadith_daily_share_style',
  REMINDER: 'hadith_daily_reminder',
  ONBOARDING_DONE: 'hadith_daily_onboarding_done',
};

export class PreferencesService {
  private static instance: PreferencesService;

  private constructor() {}

  public static getInstance(): PreferencesService {
    if (!PreferencesService.instance) {
      PreferencesService.instance = new PreferencesService();
    }
    return PreferencesService.instance;
  }

  public getFavorites(): number[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.FAVORITES);
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  }

  public isFavorite(number: number): boolean {
    return this.getFavorites().includes(number);
  }

  public toggleFavorite(number: number): boolean {
    const current = this.getFavorites();
    let updated: number[];
    let isNowFavorite = false;
    if (current.includes(number)) {
      updated = current.filter((n) => n !== number);
      isNowFavorite = false;
    } else {
      updated = [...current, number];
      isNowFavorite = true;
    }
    localStorage.setItem(STORAGE_KEYS.FAVORITES, JSON.stringify(updated));
    return isNowFavorite;
  }

  public getHistory(): number[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.HISTORY);
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  }

  public addToHistory(number: number): void {
    const current = this.getHistory().filter((n) => n !== number);
    const updated = [number, ...current].slice(0, 20);
    localStorage.setItem(STORAGE_KEYS.HISTORY, JSON.stringify(updated));
  }

  public getThemeMode(): ThemeMode {
    return (localStorage.getItem(STORAGE_KEYS.THEME_MODE) as ThemeMode) || 'system';
  }

  public setThemeMode(mode: ThemeMode): void {
    localStorage.setItem(STORAGE_KEYS.THEME_MODE, mode);
  }

  public getShareStyle(): ShareStyle {
    return (localStorage.getItem(STORAGE_KEYS.SHARE_STYLE) as ShareStyle) || 'cream';
  }

  public setShareStyle(style: ShareStyle): void {
    localStorage.setItem(STORAGE_KEYS.SHARE_STYLE, style);
  }

  public getReminder(): ReminderSettings {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.REMINDER);
      return data ? JSON.parse(data) : { enabled: false, hour: 9, minute: 0 };
    } catch {
      return { enabled: false, hour: 9, minute: 0 };
    }
  }

  public setReminder(settings: ReminderSettings): void {
    localStorage.setItem(STORAGE_KEYS.REMINDER, JSON.stringify(settings));
  }

  public isOnboardingDone(): boolean {
    return localStorage.getItem(STORAGE_KEYS.ONBOARDING_DONE) === 'true';
  }

  public setOnboardingDone(done: boolean): void {
    localStorage.setItem(STORAGE_KEYS.ONBOARDING_DONE, done ? 'true' : 'false');
  }
}
