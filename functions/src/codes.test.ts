import {test} from "node:test";
import assert from "node:assert/strict";

import {
  accountWaitMs,
  DAY,
  hashCode,
  HOUR,
  ipWaitMs,
  isAcceptablePassword,
  isCodeShaped,
  normalizeEmail,
  maskEmail,
  MAX_SENDS_PER_IP_PER_DAY,
  MINUTE,
  newCode,
  recentSends,
  sameHash,
} from "./codes.js";

test("codes are six digits and keep leading zeros", () => {
  for (let i = 0; i < 2000; i++) {
    const code = newCode();
    assert.ok(isCodeShaped(code), code);
  }
});

test("only six ASCII digits count as a code", () => {
  assert.ok(isCodeShaped("012345"));
  for (const bad of ["12345", "1234567", "12a456", "١٢٣٤٥٦", " 12345", 123456, null]) {
    assert.equal(isCodeShaped(bad), false, String(bad));
  }
});

test("the hash depends on pepper, account, address and code", () => {
  const base = hashCode("pepper", "uid1", "a@b.com", "123456");
  assert.equal(base, hashCode("pepper", "uid1", " A@B.com ", "123456"));
  assert.notEqual(base, hashCode("other", "uid1", "a@b.com", "123456"));
  assert.notEqual(base, hashCode("pepper", "uid2", "a@b.com", "123456"));
  assert.notEqual(base, hashCode("pepper", "uid1", "c@b.com", "123456"));
  assert.notEqual(base, hashCode("pepper", "uid1", "a@b.com", "123457"));
  assert.ok(sameHash(base, base));
  assert.equal(sameHash(base, base.slice(0, -2)), false);
});

test("recentSends drops old and junk entries and sorts", () => {
  const now = 10 * DAY;
  assert.deepEqual(recentSends([now - 5, "x", now - DAY - 1, now - 9], now), [
    now - 9,
    now - 5,
  ]);
  assert.deepEqual(recentSends(undefined, now), []);
});

test("first send is free, then a one-minute cooldown", () => {
  const now = 10 * DAY;
  assert.equal(accountWaitMs([], now), 0);
  assert.equal(accountWaitMs([now - 20_000], now), 40_000);
  assert.equal(accountWaitMs([now - MINUTE], now), 0);
});

test("five sends in an hour block until the oldest leaves the hour", () => {
  const now = 10 * DAY;
  const sends = [50, 40, 30, 20, 10].map((m) => now - m * MINUTE);
  assert.equal(accountWaitMs(sends, now), 10 * MINUTE);
});

test("ten sends in a day block until the oldest leaves the day", () => {
  const now = 10 * DAY;
  const sends = Array.from({length: 10}, (_, i) => now - (20 - i) * HOUR);
  assert.equal(accountWaitMs(sends, now), 4 * HOUR);
});

test("one network address is capped per day", () => {
  const now = 10 * DAY;
  const under = Array.from({length: MAX_SENDS_PER_IP_PER_DAY - 1}, () => now - HOUR);
  assert.equal(ipWaitMs(under, now), 0);
  assert.equal(ipWaitMs([...under, now - HOUR], now), DAY - HOUR);
});

test("email addresses are normalized or refused", () => {
  assert.equal(normalizeEmail("  Ahmed@Gmail.COM "), "ahmed@gmail.com");
  for (const bad of ["", "ahmed", "a@b", "a b@c.com", 42, null]) {
    assert.equal(normalizeEmail(bad), null, String(bad));
  }
});

test("new passwords are 8 to 128 characters", () => {
  assert.equal(isAcceptablePassword("1234567"), false);
  assert.equal(isAcceptablePassword("12345678"), true);
  assert.equal(isAcceptablePassword("x".repeat(129)), false);
  assert.equal(isAcceptablePassword(12345678), false);
});

test("addresses are masked in logs", () => {
  assert.equal(maskEmail("ahmed@gmail.com"), "a…@gmail.com");
  assert.equal(maskEmail("broken"), "…");
});
