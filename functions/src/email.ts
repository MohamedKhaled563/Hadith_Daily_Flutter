/**
 * The confirmation email. Arabic, short, one idea, no images and no links:
 * all three help it reach the inbox rather than the spam folder. The code is
 * in the subject too, so most readers see it in the phone's notification and
 * never open the email.
 *
 * Copy follows the app's voice rules: no exclamation marks, no emoji, and
 * wording that does not assume the reader is a man.
 */

export const SENDER_NAME = "طيّب قلبك";

export interface CodeEmail {
  subject: string;
  text: string;
  html: string;
}

export function buildCodeEmail(code: string): CodeEmail {
  const subject = `رمز تأكيد بريدك في طيّب قلبك: ${code}`;

  const text = [
    "السلام عليكم،",
    "",
    "هذا رمز تأكيد بريدك في طيّب قلبك:",
    "",
    code,
    "",
    "الرمز صالح لعشر دقائق، ويُكتب في شاشة التأكيد داخل التطبيق.",
    "",
    "إن لم يكن الطلب منك فلا حاجة لفعل شيء، ولن يُؤكَّد الحساب دون هذا الرمز.",
    "",
    "طيّب قلبك",
  ].join("\n");

  const html = `<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${subject}</title></head>
<body style="margin:0;padding:0;background:#f4f1e8;">
<div style="max-width:480px;margin:0 auto;padding:32px 20px;font-family:Tahoma,Arial,sans-serif;color:#1f2a24;line-height:1.8;text-align:right;" dir="rtl">
<p style="margin:0 0 16px;font-size:16px;">السلام عليكم،</p>
<p style="margin:0 0 12px;font-size:16px;">هذا رمز تأكيد بريدك في طيّب قلبك:</p>
<p dir="ltr" style="margin:0 0 20px;padding:16px 0;text-align:center;font-family:'Courier New',monospace;font-size:34px;font-weight:bold;letter-spacing:10px;color:#173628;background:#ffffff;border:1px solid #d9cfa8;border-radius:12px;">${code}</p>
<p style="margin:0 0 12px;font-size:15px;">الرمز صالح لعشر دقائق، ويُكتب في شاشة التأكيد داخل التطبيق.</p>
<p style="margin:0 0 24px;font-size:14px;color:#5b6660;">إن لم يكن الطلب منك فلا حاجة لفعل شيء، ولن يُؤكَّد الحساب دون هذا الرمز.</p>
<p style="margin:0;font-size:15px;font-weight:bold;color:#173628;">طيّب قلبك</p>
</div>
</body>
</html>`;

  return {subject, text, html};
}
