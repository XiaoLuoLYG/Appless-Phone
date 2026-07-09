export const COMPOSIO_USER_ID_PREFIX: string = 'aiphone-user-';

export function normalizeComposioUserId(value: string): string {
  const lower = value.trim().toLowerCase();
  let result = '';
  for (let index = 0; index < lower.length; index++) {
    const ch = lower.charAt(index);
    const ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9');
    if (ok) {
      result += ch;
    } else if (result.length > 0 && !result.endsWith('-')) {
      result += '-';
    }
  }
  while (result.endsWith('-')) {
    result = result.substring(0, result.length - 1);
  }
  return result.length > 0 ? result : COMPOSIO_USER_ID_PREFIX + 'local';
}

export function shortComposioUserId(value: string): string {
  const normalized = normalizeComposioUserId(value);
  return normalized.startsWith(COMPOSIO_USER_ID_PREFIX)
    ? normalized.substring(COMPOSIO_USER_ID_PREFIX.length)
    : normalized.substring(Math.max(0, normalized.length - 12));
}
