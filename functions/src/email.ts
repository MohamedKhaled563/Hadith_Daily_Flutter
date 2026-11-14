/**
 * The emails the app sends. Arabic, short, one idea each, no images and no
 * links: all of that helps them reach the inbox rather than the spam folder.
 * Where there is a code it is in the subject too, so most readers see it in
 * the phone's notification and never need to open the email.
 *
 * Copy follows the app's voice rules: no exclamation marks, no emoji, and
 * wording that does not assume the reader is a man.
 */

export const SENDER_NAME = "طيّب قلبك";

export interface Mail {
  subject: string;
  text: string;
  html: string;
}

interface Parts {
  subject: string;
  /** Paragraph before the code (or the only paragraphs, with no code). */
  lead: string[];
  code?: string;
  /** Paragraphs after the code. The last one is shown smaller and muted. */
  after: string[];
}

function render({subject, lead, code, after}: Parts): Mail {
  const greeting = "السلام عليكم،";
  const signature = "طيّب قلبك";

  const text = [
    greeting,
    "",
    ...lead.flatMap((p) => [p, ""]),
    ...(code ? [code, ""] : []),
    ...after.flatMap((p) => [p, ""]),
    signature,
  ].join("\n");

  const paragraph = (p: string, muted = false) =>
    `<p style="margin:0 0 ${muted ? 24 : 12}px;font-size:${muted ? 14 : 15}px;` +
    `${muted ? "color:#5b6660;" : ""}">${p}</p>`;

  const codeBlock = code
    ? `<p dir="ltr" style="margin:8px 0 20px;padding:16px 0;text-align:center;` +
      `font-family:'Courier New',monospace;font-size:34px;font-weight:bold;` +
      `letter-spacing:10px;color:#173628;background:#ffffff;` +
      `border:1px solid #d9cfa8;border-radius:12px;">${code}</p>`
    : "";

  const html = `<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${subject}</title></head>
<body style="margin:0;padding:0;background:#f4f1e8;">
<div style="max-width:480px;margin:0 auto;padding:32px 20px;font-family:Tahoma,Arial,sans-serif;color:#1f2a24;line-height:1.8;text-align:right;" dir="rtl">
<p style="margin:0 0 16px;font-size:16px;">${greeting}</p>
${lead.map((p) => paragraph(p)).join("\n")}
${codeBlock}
${after.map((p, i) => paragraph(p, i === after.length - 1)).join("\n")}
<p style="margin:0;font-size:15px;font-weight:bold;color:#173628;">${signature}</p>
</div>
</body>
</html>`;

  return {subject, text, html};
}

/** Confirms the address of a new email/password account. */
export function buildCodeEmail(code: string): Mail {
  return render({
    subject: `رمز تأكيد بريدك في طيّب قلبك: ${code}`,
    lead: ["هذا رمز تأكيد بريدك في طيّب قلبك:"],
    code,
    after: [
      "الرمز صالح لعشر دقائق، ويُكتب في شاشة التأكيد داخل التطبيق.",
      "إن لم يكن الطلب منك فلا حاجة لفعل شيء، ولن يُؤكَّد الحساب دون هذا الرمز.",
    ],
  });
}

/** Lets an email/password account choose a new password. */
export function buildResetEmail(code: string): Mail {
  return render({
    subject: `رمز إعادة تعيين كلمة المرور في طيّب قلبك: ${code}`,
    lead: ["هذا رمز إعادة تعيين كلمة المرور لحسابك في طيّب قلبك:"],
    code,
    after: [
      "الرمز صالح لعشر دقائق، ويُكتب في التطبيق مع كلمة المرور الجديدة.",
      "إن لم يكن الطلب منك فلا حاجة لفعل شيء، وتبقى كلمة المرور كما هي.",
    ],
  });
}

/**
 * Someone asked to reset the password of an account that has none: it signs
 * in with Google or Apple. Sending nothing would leave them waiting for a
 * code that never comes, so this says how they actually get in.
 */
export function buildProviderEmail(provider: "Google" | "Apple"): Mail {
  const button =
    provider === "Google" ? "«المتابعة باستخدام Google»" : "«المتابعة باستخدام Apple»";
  return render({
    subject: "الدخول إلى حسابك في طيّب قلبك",
    lead: [
      `وصلنا طلب لإعادة تعيين كلمة المرور لهذا البريد، لكن حسابك في طيّب قلبك لا يستخدم كلمة مرور، بل يُدخَل إليه عبر ${provider}.`,
      `للدخول يكفي اختيار ${button} في شاشة تسجيل الدخول.`,
    ],
    after: ["إن لم يكن الطلب منك فلا حاجة لفعل شيء."],
  });
}
