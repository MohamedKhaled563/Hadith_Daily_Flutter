import {createHash, createHmac, randomInt, timingSafeEqual} from "node:crypto";

/**
 * The rules for a confirmation code, kept free of Firebase so they can be
 * unit-tested on their own (codes.test.ts).
 */

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;
export const DAY = 24 * HOUR;

/** How long a code stays usable after it is sent. */
export const CODE_TTL_MS = 10 * MINUTE;
/** Wrong guesses allowed on one code before it is void. */
export const MAX_ATTEMPTS = 5;
/** Gap between two sends to the same account. */
export const RESEND_COOLDOWN_MS = MINUTE;
export const MAX_SENDS_PER_HOUR = 5;
export const MAX_SENDS_PER_DAY = 10;
/** Sends from one network address a day, across every account. */
export const MAX_SENDS_PER_IP_PER_DAY = 30;

/** Six digits, leading zeros kept, from the OS's secure random source. */
export function newCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export function isCodeShaped(value: unknown): value is string {
  return typeof value === "string" && /^[0-9]{6}$/.test(value);
}

/**
 * What gets stored instead of the code. An HMAC rather than a plain hash:
 * a six-digit code has only a million values, so a plain hash could be
 * reversed in a moment by anyone who read the stored doc. Without the pepper,
 * which lives only in Secret Manager, the stored value is useless. The uid
 * and address are mixed in so a code is only ever good for the account and
 * the inbox it was sent to.
 */
export function hashCode(
  pepper: string,
  uid: string,
  email: string,
  code: string,
): string {
  return createHmac("sha256", pepper)
    .update(`${uid}\n${email.trim().toLowerCase()}\n${code}`)
    .digest("hex");
}

/** Constant-time comparison, so response timing says nothing about a guess. */
export function sameHash(a: string, b: string): boolean {
  const left = Buffer.from(a, "hex");
  const right = Buffer.from(b, "hex");
  return left.length === right.length && timingSafeEqual(left, right);
}

/** Send times (ms) from the last day, oldest first; ignores junk. */
export function recentSends(stored: unknown, now: number): number[] {
  if (!Array.isArray(stored)) return [];
  return stored
    .filter((t): t is number => typeof t === "number" && now - t < DAY)
    .sort((a, b) => a - b);
}

/**
 * How long an account must wait before another code can be sent, in ms.
 * Zero means it can be sent now. [sends] must come from [recentSends].
 */
export function accountWaitMs(sends: number[], now: number): number {
  const waits = [0];
  const last = sends[sends.length - 1];
  if (last !== undefined) waits.push(last + RESEND_COOLDOWN_MS - now);

  const lastHour = sends.filter((t) => now - t < HOUR);
  if (lastHour.length >= MAX_SENDS_PER_HOUR) {
    waits.push(lastHour[lastHour.length - MAX_SENDS_PER_HOUR] + HOUR - now);
  }
  if (sends.length >= MAX_SENDS_PER_DAY) {
    waits.push(sends[sends.length - MAX_SENDS_PER_DAY] + DAY - now);
  }
  return Math.max(...waits);
}

/** Same idea for one network address: a daily cap only. */
export function ipWaitMs(sends: number[], now: number): number {
  if (sends.length < MAX_SENDS_PER_IP_PER_DAY) return 0;
  return sends[sends.length - MAX_SENDS_PER_IP_PER_DAY] + DAY - now;
}

/** `ahmed@gmail.com` → `a…@gmail.com`, for logs and nothing else. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf("@");
  if (at <= 0) return "…";
  return `${email.slice(0, 1)}…${email.slice(at)}`;
}

/**
 * A short, stable key for a network address. Hashed so the rate-limit docs
 * never hold anyone's IP address.
 */
export function ipKey(ip: string): string {
  return createHash("sha256").update(ip).digest("hex").slice(0, 32);
}
