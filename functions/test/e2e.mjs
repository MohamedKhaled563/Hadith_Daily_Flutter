// End-to-end check of the email code, against the local emulators:
// the real functions, the real firestore.rules, and the Auth emulator.
// No email is sent; in the emulator the functions leave the code in
// _emulatorEmailCodes/{uid}, which this reads with the emulator's owner key.
//
//   cd functions && npm run e2e
//
// Needs functions/.secret.local with OTP_PEPPER and GMAIL_APP_PASSWORD set to
// any test values (the file is git-ignored), and Java 21 or newer for the
// Firestore emulator. On this machine the system Java is 17, so point
// JAVA_HOME at Android Studio's bundled runtime first:
//
//   $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
//   $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

import assert from "node:assert/strict";

const PROJECT = "demo-email-code";
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const DOCS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const OWNER = {Authorization: "Bearer owner"};

let passed = 0;
async function step(name, body) {
  await body();
  passed++;
  console.log(`  ok  ${name}`);
}

async function json(url, init = {}) {
  const res = await fetch(url, {
    ...init,
    headers: {"Content-Type": "application/json", ...(init.headers ?? {})},
  });
  const text = await res.text();
  return {status: res.status, body: text ? JSON.parse(text) : null};
}

async function signUp(tag) {
  const email = `${tag}-${Date.now()}@example.test`;
  const {body} = await json(`${AUTH}/accounts:signUp?key=demo`, {
    method: "POST",
    body: JSON.stringify({email, password: "secret-pass-1", returnSecureToken: true}),
  });
  return {email, uid: body.localId, idToken: body.idToken};
}

async function call(name, idToken, data = {}) {
  const {body} = await json(`${FUNCTIONS}/${name}`, {
    method: "POST",
    headers: idToken ? {Authorization: `Bearer ${idToken}`} : {},
    body: JSON.stringify({data}),
  });
  if (body.error) return {error: body.error.status};
  return body.result;
}

async function sentCode(uid) {
  const {body} = await json(`${DOCS}/_emulatorEmailCodes/${uid}`, {headers: OWNER});
  return body.fields.code.stringValue;
}

async function isVerified(idToken) {
  const {body} = await json(`${AUTH}/accounts:lookup?key=demo`, {
    method: "POST",
    body: JSON.stringify({idToken}),
  });
  return body.users[0].emailVerified === true;
}

function wrongCode(code) {
  return String((Number(code) + 1) % 1_000_000).padStart(6, "0");
}

// An unsigned token the Firestore emulator accepts as-is, for rule checks.
function fakeToken(uid, {email, verified}) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  return `${b64({alg: "none", typ: "JWT"})}.${b64({
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    sub: uid,
    user_id: uid,
    iat: now,
    exp: now + 3600,
    auth_time: now,
    email,
    email_verified: verified,
    firebase: {sign_in_provider: "password", identities: {email: [email]}},
  })}.`;
}

async function createAs(token, collection, fields) {
  const encoded = Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [
      k,
      typeof v === "number" ? {integerValue: String(v)}
        : typeof v === "boolean" ? {booleanValue: v}
          : {stringValue: v},
    ]),
  );
  const {status} = await json(`${DOCS}/${collection}`, {
    method: "POST",
    headers: {Authorization: `Bearer ${token}`},
    body: JSON.stringify({fields: encoded}),
  });
  return status;
}

console.log("email code, end to end");

await step("signed-out callers are refused", async () => {
  assert.deepEqual(await call("sendEmailCode", null), {error: "UNAUTHENTICATED"});
});

const a = await signUp("a");

await step("a new account gets a code", async () => {
  const result = await call("sendEmailCode", a.idToken);
  assert.equal(result.status, "sent");
  assert.equal(result.expiresInSeconds, 600);
  assert.match(await sentCode(a.uid), /^[0-9]{6}$/);
});

await step("asking again straight away has to wait", async () => {
  const result = await call("sendEmailCode", a.idToken);
  assert.equal(result.status, "wait");
  assert.ok(result.retryAfterSeconds > 0 && result.retryAfterSeconds <= 60);
});

await step("the code is only ever six digits", async () => {
  assert.deepEqual(
    await call("verifyEmailCode", a.idToken, {code: "12"}),
    {error: "INVALID_ARGUMENT"},
  );
});

await step("a wrong code says how many tries are left", async () => {
  const code = await sentCode(a.uid);
  assert.deepEqual(
    await call("verifyEmailCode", a.idToken, {code: wrongCode(code)}),
    {status: "wrong", attemptsLeft: 4},
  );
  assert.equal(await isVerified(a.idToken), false);
});

await step("the right code confirms the account", async () => {
  const code = await sentCode(a.uid);
  assert.deepEqual(await call("verifyEmailCode", a.idToken, {code}), {status: "verified"});
  assert.equal(await isVerified(a.idToken), true);
  const {status} = await json(`${DOCS}/emailCodes/${a.uid}`, {headers: OWNER});
  assert.equal(status, 404, "the stored code is gone");
});

await step("a confirmed account needs nothing more", async () => {
  assert.deepEqual(await call("sendEmailCode", a.idToken), {status: "verified"});
  assert.deepEqual(
    await call("discardUnverifiedAccount", a.idToken),
    {error: "FAILED_PRECONDITION"},
  );
});

const b = await signUp("b");

await step("five wrong codes void the code, even the right one after", async () => {
  await call("sendEmailCode", b.idToken);
  const code = await sentCode(b.uid);
  const wrong = wrongCode(code);
  for (const left of [4, 3, 2, 1]) {
    assert.deepEqual(
      await call("verifyEmailCode", b.idToken, {code: wrong}),
      {status: "wrong", attemptsLeft: left},
    );
  }
  assert.deepEqual(
    await call("verifyEmailCode", b.idToken, {code: wrong}),
    {status: "too-many-attempts"},
  );
  assert.deepEqual(
    await call("verifyEmailCode", b.idToken, {code}),
    {status: "too-many-attempts"},
  );
  assert.equal(await isVerified(b.idToken), false);
});

const c = await signUp("c");

await step("an expired code is refused", async () => {
  await call("sendEmailCode", c.idToken);
  const code = await sentCode(c.uid);
  await json(`${DOCS}/emailCodes/${c.uid}?updateMask.fieldPaths=expiresAt`, {
    method: "PATCH",
    headers: OWNER,
    body: JSON.stringify({fields: {expiresAt: {timestampValue: "2000-01-01T00:00:00Z"}}}),
  });
  assert.deepEqual(await call("verifyEmailCode", c.idToken, {code}), {status: "expired"});
});

await step("checking with no code sent asks for one", async () => {
  const d = await signUp("d");
  assert.deepEqual(
    await call("verifyEmailCode", d.idToken, {code: "123456"}),
    {status: "no-code"},
  );
});

await step("a mistyped new account can be discarded, freeing its name", async () => {
  await json(`${DOCS}/usernames?documentId=name-of-c`, {
    method: "POST",
    headers: OWNER,
    body: JSON.stringify({fields: {uid: {stringValue: c.uid}}}),
  });
  await json(`${DOCS}/users?documentId=${c.uid}`, {
    method: "POST",
    headers: OWNER,
    body: JSON.stringify({fields: {email: {stringValue: c.email}}}),
  });

  assert.deepEqual(await call("discardUnverifiedAccount", c.idToken), {status: "deleted"});

  const name = await json(`${DOCS}/usernames/name-of-c`, {headers: OWNER});
  assert.equal(name.status, 404, "username released");
  const profile = await json(`${DOCS}/users/${c.uid}`, {headers: OWNER});
  assert.equal(profile.status, 404, "profile removed");
  const signIn = await json(`${AUTH}/accounts:signInWithPassword?key=demo`, {
    method: "POST",
    body: JSON.stringify({email: c.email, password: "secret-pass-1"}),
  });
  assert.equal(signIn.status, 400, "account gone");
});

console.log("password reset");

async function sentMail(key) {
  const {status, body} = await json(`${DOCS}/_emulatorEmailCodes/${key}`, {headers: OWNER});
  if (status !== 200) return null;
  return {code: body.fields.code.stringValue, subject: body.fields.subject.stringValue};
}

async function signInStatus(email, password) {
  const {status} = await json(`${AUTH}/accounts:signInWithPassword?key=demo`, {
    method: "POST",
    body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  return status;
}

const e = await signUp("e");

await step("a password account gets a reset code", async () => {
  const result = await call("sendPasswordResetCode", null, {email: e.email.toUpperCase()});
  assert.equal(result.status, "sent");
  const mail = await sentMail(`reset-${e.uid}`);
  assert.match(mail.code, /^[0-9]{6}$/);
  assert.match(mail.subject, /إعادة تعيين كلمة المرور/);
});

await step("asking again straight away has to wait", async () => {
  const result = await call("sendPasswordResetCode", null, {email: e.email});
  assert.equal(result.status, "wait");
});

await step("an unknown address gets the same answer", async () => {
  const result = await call("sendPasswordResetCode", null, {email: `nobody-${Date.now()}@example.test`});
  assert.equal(result.status, "sent");
});

await step("bad input is refused before anything is checked", async () => {
  const {code} = await sentMail(`reset-${e.uid}`);
  assert.deepEqual(
    await call("resetPasswordWithCode", null, {email: e.email, code, newPassword: "short"}),
    {error: "INVALID_ARGUMENT"},
  );
  assert.deepEqual(
    await call("sendPasswordResetCode", null, {email: "not-an-email"}),
    {error: "INVALID_ARGUMENT"},
  );
});

await step("a sign-up code is no good for a reset", async () => {
  await call("sendEmailCode", e.idToken);
  const signupCode = await sentCode(e.uid);
  const {code} = await sentMail(`reset-${e.uid}`);
  if (signupCode === code) return; // one in a million; nothing to test
  assert.deepEqual(
    await call("resetPasswordWithCode", null, {email: e.email, code: signupCode, newPassword: "new-pass-123"}),
    {status: "wrong", attemptsLeft: 4},
  );
});

await step("the right code sets the new password and confirms the address", async () => {
  const {code} = await sentMail(`reset-${e.uid}`);
  assert.deepEqual(
    await call("resetPasswordWithCode", null, {email: e.email, code, newPassword: "new-pass-123"}),
    {status: "reset"},
  );
  assert.equal(await signInStatus(e.email, "secret-pass-1"), 400, "old password refused");
  assert.equal(await signInStatus(e.email, "new-pass-123"), 200, "new password works");
  const {body} = await json(`${AUTH}/accounts:signInWithPassword?key=demo`, {
    method: "POST",
    body: JSON.stringify({email: e.email, password: "new-pass-123", returnSecureToken: true}),
  });
  assert.equal(await isVerified(body.idToken), true);
});

await step("a used reset code can't be used again", async () => {
  const {code} = await sentMail(`reset-${e.uid}`);
  assert.deepEqual(
    await call("resetPasswordWithCode", null, {email: e.email, code, newPassword: "another-pass-1"}),
    {status: "no-code"},
  );
});

await step("a Google account is told how it signs in, with no code", async () => {
  const email = `g-${Date.now()}@example.test`;
  const {body} = await json(`${AUTH}/accounts:signInWithIdp?key=demo`, {
    method: "POST",
    body: JSON.stringify({
      requestUri: "http://localhost",
      returnSecureToken: true,
      postBody: `providerId=google.com&id_token=${encodeURIComponent(
        JSON.stringify({sub: `g-${Date.now()}`, email, email_verified: true}),
      )}`,
    }),
  });
  assert.ok(body.localId, JSON.stringify(body));
  const result = await call("sendPasswordResetCode", null, {email});
  assert.equal(result.status, "sent");
  const mail = await sentMail(`reset-${body.localId}`);
  assert.equal(mail.code, "");
  assert.match(mail.subject, /الدخول إلى حسابك/);
});

console.log("rules");

const verified = fakeToken("rv", {email: "rv@example.test", verified: true});
const unverified = fakeToken("ru", {email: "ru@example.test", verified: false});
const post = (uid) => ({
  authorUid: uid,
  authorName: "اختبار",
  message: "رسالة",
  hadithNumber: 1,
  status: "pending",
  likeCount: 0,
});
const feedback = (uid, email) => ({
  authorUid: uid,
  userName: "اختبار",
  userEmail: email,
  message: "ملاحظة",
  read: false,
});

await step("a confirmed reader can post and send feedback", async () => {
  assert.equal(await createAs(verified, "communityMessages", post("rv")), 200);
  assert.equal(await createAs(verified, "feedbackMessages", feedback("rv", "rv@example.test")), 200);
});

await step("an unconfirmed reader cannot", async () => {
  assert.equal(await createAs(unverified, "communityMessages", post("ru")), 403);
  assert.equal(await createAs(unverified, "feedbackMessages", feedback("ru", "ru@example.test")), 403);
});

await step("feedback cannot claim someone else's address", async () => {
  assert.equal(await createAs(verified, "feedbackMessages", feedback("rv", "victim@example.com")), 403);
});

await step("the code collections are closed to every client", async () => {
  const {status} = await json(`${DOCS}/emailCodes/rv`, {
    headers: {Authorization: `Bearer ${verified}`},
  });
  assert.equal(status, 403);
});

console.log(`\n${passed} checks passed`);
