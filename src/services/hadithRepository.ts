import hadithsData from '../data/hadiths.json';
import { Hadith } from '../types';

export class HadithRepository {
  private static instance: HadithRepository;
  private hadiths: Hadith[] = hadithsData as Hadith[];

  private constructor() {}

  public static getInstance(): HadithRepository {
    if (!HadithRepository.instance) {
      HadithRepository.instance = new HadithRepository();
    }
    return HadithRepository.instance;
  }

  public getAll(): Hadith[] {
    return this.hadiths;
  }

  public getByNumber(num: number): Hadith | undefined {
    return this.hadiths.find((h) => h.number === num);
  }

  public getTodayHadith(date: Date = new Date()): Hadith {
    if (this.hadiths.length === 0) {
      throw new Error('No hadith data available');
    }
    const start = new Date(date.getFullYear(), 0, 1);
    const diff = date.getTime() - start.getTime();
    const oneDay = 1000 * 60 * 60 * 24;
    const dayOfYear = Math.floor(diff / oneDay);
    const index = Math.abs(dayOfYear) % this.hadiths.length;
    return this.hadiths[index];
  }

  public getRandomHadith(excludeNumber?: number): Hadith {
    if (this.hadiths.length <= 1) return this.hadiths[0];
    let pool = this.hadiths;
    if (excludeNumber !== undefined) {
      pool = this.hadiths.filter((h) => h.number !== excludeNumber);
    }
    const randomIndex = Math.floor(Math.random() * pool.length);
    return pool[randomIndex];
  }
}
