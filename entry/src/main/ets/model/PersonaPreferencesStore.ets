import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PersonaEditableSnapshot } from './PersonaTypes';
import { applyPersonaEditableSnapshots, personaEditableSnapshots } from './PersonaStore';

const PERSONA_STORE_NAME: string = 'aiphone_persona_store';
const PERSONA_STORE_KEY: string = 'editable_personas';

function flushPreferences(store: preferences.Preferences): void {
  store.flush().catch((_error: Error) => {});
}

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function snapshotsFromJson(raw: string): PersonaEditableSnapshot[] {
  if (raw.trim().length === 0) {
    return [];
  }
  const parsed = JSON.parse(raw) as PersonaEditableSnapshot[];
  return Array.isArray(parsed) ? parsed : [];
}

export class PreferencesPersonaPackStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  private preferences(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.context, { name: PERSONA_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  loadSync(): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      applyPersonaEditableSnapshots(snapshotsFromJson(textFromValue(store.getSync(PERSONA_STORE_KEY, ''))));
    } catch (_error) {
    }
  }

  saveSync(): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(PERSONA_STORE_KEY, JSON.stringify(personaEditableSnapshots()));
      flushPreferences(store);
    } catch (_error) {
    }
  }
}
