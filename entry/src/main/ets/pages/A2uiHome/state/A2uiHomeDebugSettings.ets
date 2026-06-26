export const A2UI_FOOD_PROVIDER_DELAY_MAX_MS: number = 30000;
export const A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS: number = 500;
export const A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS: number = 5000;

export function normalizeFoodProviderDelayMs(value: string): number {
  const parsed = Number.parseInt(value.trim());
  if (Number.isNaN(parsed) || parsed < 0) {
    return 0;
  }
  if (parsed > A2UI_FOOD_PROVIDER_DELAY_MAX_MS) {
    return A2UI_FOOD_PROVIDER_DELAY_MAX_MS;
  }
  return parsed;
}

export function normalizeFoodPartialThrottleMs(value: string): number {
  const parsed = Number.parseInt(value.trim());
  if (Number.isNaN(parsed)) {
    return A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS;
  }
  if (parsed < 0) {
    return 0;
  }
  if (parsed > A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS) {
    return A2UI_FOOD_PARTIAL_THROTTLE_MAX_MS;
  }
  return parsed;
}
