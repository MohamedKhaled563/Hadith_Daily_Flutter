/// Catches the address typos that matter most here: a mistyped domain gives a
/// working account whose code, and later password reset, go nowhere.
///
/// Returns the corrected address when the domain is a known misspelling of a
/// common provider, otherwise null.
String? suggestEmailFix(String email) {
  final at = email.lastIndexOf('@');
  if (at <= 0) return null;
  final domain = email.substring(at + 1).toLowerCase();
  final fixed = _typos[domain];
  return fixed == null ? null : '${email.substring(0, at)}@$fixed';
}

/// A plain shape check: something@something.something, no spaces. Firebase
/// checks again; this only saves a round trip on obvious slips.
bool looksLikeEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);

const _typos = {
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.cm': 'gmail.com',
  'gmail.om': 'gmail.com',
  'hotmial.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'hotmail.co': 'hotmail.com',
  'hotmail.con': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outlook.co': 'outlook.com',
  'outlook.con': 'outlook.com',
  'yahooo.com': 'yahoo.com',
  'yaho.com': 'yahoo.com',
  'yahoo.co': 'yahoo.com',
  'yahoo.con': 'yahoo.com',
  'iclould.com': 'icloud.com',
  'iclod.com': 'icloud.com',
  'icloud.co': 'icloud.com',
};
