import { preferences } from '@kit.ArkData';
import {
  PublicPersonaSnapshot,
  sanitizePublicPersonaSnapshot
} from './PublicPersonaModel';

export const PUBLIC_PERSONA_STORE_NAME: string = 'aiphone_public_persona';
export const PUBLIC_PERSONA_SNAPSHOT_KEY: string = 'snapshot_v1';
export const PUBLIC_PERSONA_ONBOARDING_KEY: string = 'onboarding_seen';

function storedText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

export class PublicPersonaStore {
  private store: preferences.Preferences;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  onboardingSeen(): boolean {
    const value = this.store.getSync(PUBLIC_PERSONA_ONBOARDING_KEY, false);
    return typeof value === 'boolean' && value;
  }

  markOnboardingSeen(): void {
    this.store.putSync(PUBLIC_PERSONA_ONBOARDING_KEY, true);
    this.store.flushSync();
  }

  load(): PublicPersonaSnapshot | null {
    try {
      const raw = storedText(this.store.getSync(PUBLIC_PERSONA_SNAPSHOT_KEY, ''));
      if (raw.trim().length === 0) {
        return null;
      }
      return sanitizePublicPersonaSnapshot(JSON.parse(raw) as Object);
    } catch (_error) {
      return null;
    }
  }

  save(snapshot: PublicPersonaSnapshot): boolean {
    try {
      const safe = sanitizePublicPersonaSnapshot(snapshot as Object);
      if (safe === null) {
        return false;
      }
      this.store.putSync(PUBLIC_PERSONA_SNAPSHOT_KEY, JSON.stringify(safe));
      this.store.flushSync();
      return this.load() !== null;
    } catch (_error) {
      return false;
    }
  }

  deleteSnapshot(): boolean {
    try {
      this.store.deleteSync(PUBLIC_PERSONA_SNAPSHOT_KEY);
      this.store.flushSync();
      return storedText(this.store.getSync(PUBLIC_PERSONA_SNAPSHOT_KEY, '')).trim().length === 0;
    } catch (_error) {
      return false;
    }
  }
}
