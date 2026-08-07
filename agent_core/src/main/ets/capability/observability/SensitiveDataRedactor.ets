const SENSITIVE_KEYS: string[] = [
  'authorization', 'token', 'access_token', 'refresh_token', 'password', 'secret', 'api_key', 'apikey', 'cookie'
];

export class SensitiveDataRedactor {
  redact(value: Object): Object {
    return this.redactValue(value) as Object;
  }

  private redactValue(value: Object | string | number | boolean | null): Object | string | number | boolean | null {
    if (value === null || typeof value !== 'object') {
      return value;
    }
    if (Array.isArray(value)) {
      return value.map((item: Object | string | number | boolean | null) => this.redactValue(item)) as Object;
    }
    const source = value as Record<string, Object | string | number | boolean | null>;
    const result: Record<string, Object | string | number | boolean | null> = {};
    Object.keys(source).forEach((key: string) => {
      const normalized = key.toLowerCase();
      result[key] = SENSITIVE_KEYS.indexOf(normalized) >= 0 ? '[REDACTED]' : this.redactValue(source[key]);
    });
    return result;
  }
}
