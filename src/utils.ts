import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function toArabicDigits(num: number | string): string {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return num
    .toString()
    .split('')
    .map((c) => {
      const idx = western.indexOf(c);
      return idx > -1 ? arabic[idx] : c;
    })
    .join('');
}

export function getShortLabel(text: string, count: number = 5): string {
  const clean = text.replace(/["«»]/g, '').trim();
  const words = clean.split(/\s+/);
  const short = words.slice(0, count).join(' ');
  return words.length > count ? `${short}...` : short;
}
