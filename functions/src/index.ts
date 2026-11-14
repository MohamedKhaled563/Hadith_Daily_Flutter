/**
 * Email confirmation by code, for accounts made with an email and password.
 *
 * Why this runs here and not on the phone: anything inside the app can be read
 * or changed by someone determined enough. If the phone made the code it could
 * be read straight out of the app, and if the phone could mark an account
 * verified anyone could skip the step. So the code is made, stored (as an
 * HMAC, never in the clear), emailed and checked here, and only the Admin SDK
 * here can set `emailVerified`.
 *
 * Google and Apple sign-ins never come through this: those providers have
 * already verified the address.
 *
 * Firestore docs this owns (all closed to clients by the catch-all rule):
 *   emailCodes/{uid}        the live code's HMAC, expiry, attempts, send log
 *   emailCodeIps/{ipKey}    one network address's sends in the last day
 *   _emulatorEmailCodes     emulator only: where a test reads the code
 */
import {initializeApp} from "firebase-admin/app";
import {getAuth, UserRecord} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/options";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/https";
import {onSchedule} from "firebase-functions/scheduler";
import {defineSecret, defineString} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import nodemailer, {Transporter} from "nodemailer";

import {
  accountWaitMs,
  CODE_TTL_MS,
  DAY,
  hashCode,
  ipKey,
  ipWaitMs,
  isCodeShaped,
  MAX_ATTEMPTS,
  maskEmail,
  newCode,
  recentSends,
  RESEND_COOLDOWN_MS,
  sameHash,
} from "./codes.js";
import {buildCodeEmail, SENDER_NAME} from "./email.js";

initializeApp();

// A ceiling on parallel instances: if someone hammers these endpoints the
// bill and the Gmail account's sending limit are protected by the per-account
// and per-address caps first, and by this as a last resort.
setGlobalOptions({region: "us-central1", maxInstances: 5});

const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");
const OTP_PEPPER = defineSecret("OTP_PEPPER");
const MAIL_USER = defineString("MAIL_USER");
const CLEANUP_CREATED_AFTER = defineString("CLEANUP_CREATED_AFTER", {
  default: "",
});

const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

/** "Change email" is only offered on an account this young. */
const DISCARDABLE_FOR_MS = DAY;
/** Unverified accounts older than this are removed by the nightly cleanup. */
const UNVERIFIED_GRACE_MS = 7 * DAY;

const db = () => getFirestore();
const codeRef = (uid: string) => db().collection("emailCodes").doc(uid);

async function requireUser(request: CallableRequest): Promise<UserRecord> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return getAuth().getUser(request.auth.uid);
}

function isPasswordAccount(user: UserRecord): boolean {
  return user.providerData.some((p) => p.providerId === "password");
}

function callerIp(request: CallableRequest): string {
  return request.rawRequest.ip ?? "unknown";
}

// ------------------------------------------------------------- send ----

let transport: Transporter | undefined;

async function deliver(uid: string, to: string, code: string): Promise<void> {
  if (isEmulator) {
    // Never email from the emulator. The end-to-end test reads it from here.
    await db().collection("_emulatorEmailCodes").doc(uid).set({code, to});
    return;
  }
  const mail = buildCodeEmail(code);
  transport ??= nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      user: MAIL_USER.value(),
      // Google shows app passwords in groups of four; spaces are cosmetic.
      pass: GMAIL_APP_PASSWORD.value().replace(/\s+/g, ""),
    },
  });
  await transport.sendMail({
    from: {name: SENDER_NAME, address: MAIL_USER.value()},
    to,
    subject: mail.subject,
    text: mail.text,
    html: mail.html,
  });
}

/**
 * Emails a new code to the signed-in account's own address.
 *
 * Returns one of:
 *   {status: "sent", resendAfterSeconds, expiresInSeconds}
 *   {status: "wait", retryAfterSeconds}   a limit applies; nothing was sent
 *   {status: "verified"}                  nothing to do
 *
 * There is deliberately no way to ask for a code to *another* address: an
 * endpoint like that would let anyone use the app's sender to flood strangers'
 * inboxes, which is how a sender ends up in everyone's spam folder.
 */
export const sendEmailCode = onCall(
  {secrets: [GMAIL_APP_PASSWORD, OTP_PEPPER]},
  async (request) => {
    const user = await requireUser(request);
    if (user.emailVerified) return {status: "verified"};
    if (!user.email || !isPasswordAccount(user)) {
      throw new HttpsError(
        "failed-precondition",
        "Only email and password accounts confirm by code.",
      );
    }

    const email = user.email;
    const now = Date.now();
    const code = newCode();
    const hash = hashCode(OTP_PEPPER.value(), user.uid, email, code);
    const ipRef = db().collection("emailCodeIps").doc(ipKey(callerIp(request)));

    const waitMs = await db().runTransaction(async (tx) => {
      const [codeSnap, ipSnap] = await tx.getAll(codeRef(user.uid), ipRef);
      const sends = recentSends(codeSnap.get("sends"), now);
      const ipSends = recentSends(ipSnap.get("sends"), now);
      const wait = Math.max(
        accountWaitMs(sends, now),
        ipWaitMs(ipSends, now),
      );
      if (wait > 0) return wait;

      tx.set(codeRef(user.uid), {
        hash,
        email,
        expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
        attempts: 0,
        sends: [...sends, now],
      });
      tx.set(ipRef, {
        sends: [...ipSends, now],
        expiresAt: Timestamp.fromMillis(now + DAY),
      });
      return 0;
    });

    if (waitMs > 0) {
      return {status: "wait", retryAfterSeconds: Math.ceil(waitMs / 1000)};
    }

    try {
      await deliver(user.uid, email, code);
    } catch (error) {
      logger.error("Confirmation email failed", {
        uid: user.uid,
        to: maskEmail(email),
        error: String(error),
      });
      throw new HttpsError("unavailable", "The email could not be sent.");
    }

    logger.info("Confirmation code sent", {
      uid: user.uid,
      to: maskEmail(email),
    });
    return {
      status: "sent",
      resendAfterSeconds: RESEND_COOLDOWN_MS / 1000,
      expiresInSeconds: CODE_TTL_MS / 1000,
    };
  },
);

// ----------------------------------------------------------- verify ----

type Check =
  | {status: "match"}
  | {status: "wrong"; attemptsLeft: number}
  | {status: "expired" | "too-many-attempts" | "no-code"};

/**
 * Checks a code the reader typed and, if it is right, marks the account's
 * email verified. The phone then refreshes its ID token so the security
 * rules see `email_verified: true` straight away.
 *
 * Returns one of:
 *   {status: "verified"}
 *   {status: "wrong", attemptsLeft}
 *   {status: "expired" | "too-many-attempts" | "no-code"}  ask for a new code
 */
export const verifyEmailCode = onCall(
  {secrets: [OTP_PEPPER]},
  async (request) => {
    const user = await requireUser(request);
    if (user.emailVerified) return {status: "verified"};

    const code = (request.data as {code?: unknown} | null)?.code;
    if (!isCodeShaped(code)) {
      throw new HttpsError("invalid-argument", "The code is six digits.");
    }
    if (!user.email) {
      throw new HttpsError("failed-precondition", "This account has no email.");
    }

    const email = user.email;
    const now = Date.now();
    const ref = codeRef(user.uid);

    // In a transaction so parallel guesses are counted one by one: the
    // attempt is recorded before the answer is known, and a burst of
    // requests cannot get more than MAX_ATTEMPTS tries at one code.
    const check = await db().runTransaction<Check>(async (tx) => {
      const snap = await tx.get(ref);
      const stored = snap.get("hash");
      if (typeof stored !== "string") return {status: "no-code"};

      // The code went to a different address than the account has now.
      if (snap.get("email") !== email) {
        tx.update(ref, {hash: FieldValue.delete()});
        return {status: "no-code"};
      }
      const expiresAt = snap.get("expiresAt") as Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() <= now) {
        return {status: "expired"};
      }
      const attempts = Number(snap.get("attempts") ?? 0);
      if (attempts >= MAX_ATTEMPTS) return {status: "too-many-attempts"};

      if (sameHash(hashCode(OTP_PEPPER.value(), user.uid, email, code), stored)) {
        return {status: "match"};
      }
      tx.update(ref, {attempts: attempts + 1});
      const attemptsLeft = MAX_ATTEMPTS - attempts - 1;
      return attemptsLeft > 0
        ? {status: "wrong", attemptsLeft}
        : {status: "too-many-attempts"};
    });

    if (check.status !== "match") return check;

    await getAuth().updateUser(user.uid, {emailVerified: true});
    await ref.delete();
    logger.info("Email confirmed by code", {uid: user.uid});
    return {status: "verified"};
  },
);

// ---------------------------------------------------------- discard ----

/**
 * Everything an email account owns that is keyed by its uid, so it can be
 * removed with the account. Mirrors the app's AccountDeletionService for the
 * parts an account can have before its email is confirmed.
 */
async function deleteAccountData(uid: string): Promise<void> {
  const names = await db()
    .collection("usernames")
    .where("uid", "==", uid)
    .get();
  await Promise.all(names.docs.map((doc) => doc.ref.delete()));
  await db().recursiveDelete(db().collection("users").doc(uid));
  await db().collection("scores").doc(uid).delete();
  await codeRef(uid).delete();
}

/**
 * Deletes a brand-new account whose email turned out to be wrong, so the
 * reader can sign up again with the right one and keep the same name. Done
 * here rather than with `User.delete()` on the phone, which can demand a
 * fresh sign-in first, the last thing someone stuck on a typo needs.
 *
 * Only for an unverified email account less than a day old: an older account
 * may have history worth keeping, and goes through the normal account
 * deletion in settings instead.
 */
export const discardUnverifiedAccount = onCall(async (request) => {
  const user = await requireUser(request);
  const age = Date.now() - Date.parse(user.metadata.creationTime);
  if (user.emailVerified || !isPasswordAccount(user) || age > DISCARDABLE_FOR_MS) {
    throw new HttpsError(
      "failed-precondition",
      "Only a new, unconfirmed email account can be discarded this way.",
    );
  }
  await deleteAccountData(user.uid);
  await getAuth().deleteUser(user.uid);
  logger.info("Unconfirmed account discarded", {uid: user.uid});
  return {status: "deleted"};
});

// ---------------------------------------------------------- cleanup ----

/**
 * Nightly: removes email accounts nobody confirmed within a week, which frees
 * the address and the display name they were holding.
 *
 * Off until CLEANUP_CREATED_AFTER (functions/.env) is set, and it only ever
 * looks at accounts created on or after that date. Older accounts were made
 * by app versions with no code screen and are never removed by this.
 */
export const cleanupUnverifiedAccounts = onSchedule(
  {schedule: "every day 03:30", timeZone: "Africa/Cairo"},
  async () => {
    const startsFrom = Date.parse(CLEANUP_CREATED_AFTER.value());
    if (Number.isNaN(startsFrom)) {
      logger.info("Unverified-account cleanup is off");
      return;
    }
    const createdBefore = Date.now() - UNVERIFIED_GRACE_MS;
    let removed = 0;
    let pageToken: string | undefined;
    do {
      const page = await getAuth().listUsers(1000, pageToken);
      for (const user of page.users) {
        const created = Date.parse(user.metadata.creationTime);
        const passwordOnly =
          user.providerData.length === 1 &&
          user.providerData[0].providerId === "password";
        if (
          user.emailVerified ||
          !passwordOnly ||
          created < startsFrom ||
          created > createdBefore
        ) {
          continue;
        }
        await deleteAccountData(user.uid);
        await getAuth().deleteUser(user.uid);
        removed++;
      }
      pageToken = page.pageToken;
    } while (pageToken);
    logger.info("Unverified-account cleanup done", {removed});
  },
);
