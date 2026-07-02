import { PersonaEditableSnapshot, PersonaManifest, PersonaPack } from './PersonaTypes';

type PersonaFileMap = Record<string, string>;
type PersonaRawRecord = Record<string, Object | string | number | boolean | null | undefined>;

const PERSONA_SECTION_LIMIT: number = 1200;

const DEFAULT_PERSONAS_JSON: string = JSON.stringify([
  { id: 'default_companion', name: '默认分身', avatarKey: 'default', domains: ['general'], defaultTools: [] },
  { id: 'food_companion', name: '饮食搭子', avatarKey: 'food', domains: ['food'], defaultTools: ['food.search'] },
  { id: 'travel_companion', name: '旅行搭子', avatarKey: 'travel', domains: ['travel'], defaultTools: ['travel.search', 'train.search', 'flight.search'] },
  { id: 'work_companion', name: '工作分身', avatarKey: 'work', domains: ['mail', 'calendar'], defaultTools: ['mail.search', 'mail.draft.create', 'calendar.events.search'] },
  { id: 'entertainment_companion', name: '娱乐搭子', avatarKey: 'entertainment', domains: ['media', 'social'], defaultTools: ['media.video.search', 'youtube.video.search'] },
  { id: 'game_companion', name: '游戏搭子', avatarKey: 'game', domains: ['game'], defaultTools: ['dynamic.search'] },
  { id: 'shopping_companion', name: '购物搭子', avatarKey: 'shopping', domains: ['shopping'], defaultTools: ['dynamic.search'] }
]);

const DEFAULT_PERSONA_FILES: PersonaFileMap = {
  'default_companion/soul.md': '你是默认分身。用简洁中文回答，优先说明真实能力边界。',
  'default_companion/skills.md': '普通闲聊和不明确任务。没有明确工具需求时不要调用工具。',
  'default_companion/memory.md': '',
  'food_companion/soul.md': '你是饮食搭子。你帮助用户找咖啡、奶茶、餐厅和外卖，但不模拟下单或支付。',
  'food_companion/skills.md': '优先使用 food.search。普通附近咖啡、奶茶、餐厅、美食、瑞幸、麦当劳请求都走 food.search。只有用户明确说 Google Maps、gmap、谷歌地图、Google Places 时才用 Maps。',
  'food_companion/memory.md': '用户咖啡偏好：暂无固定品牌。',
  'travel_companion/soul.md': '你是旅行搭子。你帮助用户比较火车、航班和综合出行选项，不编造班次和价格。',
  'travel_companion/skills.md': '综合出行用 travel.search，高铁火车用 train.search，航班机票用 flight.search。',
  'travel_companion/memory.md': '',
  'work_companion/soul.md': '你是工作分身。你帮助用户处理邮件、日历和工作沟通，发送前必须保留确认边界。',
  'work_companion/skills.md': '邮件查询用 mail.search 或 gmail.mail.search，写邮件先创建 draft，不直接发送。',
  'work_companion/memory.md': '',
  'entertainment_companion/soul.md': '你是娱乐搭子。你帮助用户查视频、媒体内容和公开信息，不伪造平台结果。',
  'entertainment_companion/skills.md': 'B 站或多源视频用 media.video.search，明确 YouTube-only 时用 youtube.video.search。',
  'entertainment_companion/memory.md': '',
  'game_companion/soul.md': '你是游戏搭子。你帮助用户分析游戏信息、玩法和攻略请求。',
  'game_companion/skills.md': '没有固定本地游戏工具时，用 dynamic.search 发现可用工具；没有可用工具时说明边界。',
  'game_companion/memory.md': '',
  'shopping_companion/soul.md': '你是购物搭子。你帮助用户比较商品信息和购买前决策，不下单、不支付。',
  'shopping_companion/skills.md': '没有固定购物工具时，用 dynamic.search 发现可用工具；高风险交易动作必须停止。',
  'shopping_companion/memory.md': ''
};

let manifests: PersonaManifest[] = parseManifests(DEFAULT_PERSONAS_JSON);
let personaFiles: PersonaFileMap = cloneFiles(DEFAULT_PERSONA_FILES);

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function textArray(value: Object | string[] | null | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const values: string[] = [];
  value.forEach((item: Object | string | number | boolean | null) => {
    const text = textOf(item).trim();
    if (text.length > 0) {
      values.push(text);
    }
  });
  return values;
}

function normalizeManifest(value: Object): PersonaManifest {
  const raw = value as PersonaRawRecord;
  return {
    id: textOf(raw.id).trim(),
    name: textOf(raw.name).trim(),
    avatarKey: textOf(raw.avatarKey).trim(),
    domains: textArray(raw.domains as Object | string[] | null | undefined),
    defaultTools: textArray(raw.defaultTools as Object | string[] | null | undefined)
  };
}

function defaultManifest(): PersonaManifest {
  return {
    id: 'default_companion',
    name: '默认分身',
    avatarKey: 'default',
    domains: ['general'],
    defaultTools: []
  };
}

function parseManifests(rawJson: string): PersonaManifest[] {
  const parsed = JSON.parse(rawJson) as Object[];
  const next: PersonaManifest[] = [];
  if (Array.isArray(parsed)) {
    parsed.forEach((item: Object) => {
      const manifest = normalizeManifest(item);
      if (manifest.id.length > 0 && manifest.name.length > 0) {
        next.push(manifest);
      }
    });
  }
  return next.length > 0 ? next : [defaultManifest()];
}

function cloneFiles(files: PersonaFileMap): PersonaFileMap {
  const next: PersonaFileMap = {};
  Object.keys(files).forEach((key: string) => {
    next[key] = files[key];
  });
  return next;
}

function setFileText(personaId: string, fileName: string, text: string): void {
  personaFiles[personaId + '/' + fileName] = text;
}

function truncated(text: string): string {
  return text.length <= PERSONA_SECTION_LIMIT ? text : text.substring(0, PERSONA_SECTION_LIMIT);
}

function manifestForId(id: string): PersonaManifest {
  for (let index = 0; index < manifests.length; index++) {
    if (manifests[index].id === id) {
      return manifests[index];
    }
  }
  for (let index = 0; index < manifests.length; index++) {
    if (manifests[index].id === 'default_companion') {
      return manifests[index];
    }
  }
  return manifests.length > 0 ? manifests[0] : defaultManifest();
}

function fileText(personaId: string, fileName: string): string {
  const value = personaFiles[personaId + '/' + fileName];
  return value === undefined ? '' : truncated(value);
}

export function personaPromptSectionLimit(): number {
  return PERSONA_SECTION_LIMIT;
}

export function configurePersonaStoreFromRaw(rawManifestJson: string, files: PersonaFileMap): void {
  manifests = parseManifests(rawManifestJson);
  personaFiles = cloneFiles(files);
}

export function configureDefaultPersonaStoreForTests(): void {
  manifests = parseManifests(DEFAULT_PERSONAS_JSON);
  personaFiles = cloneFiles(DEFAULT_PERSONA_FILES);
}

export function personaManifestIds(): string[] {
  return manifests.map((manifest: PersonaManifest): string => manifest.id);
}

export function allPersonaPacks(): PersonaPack[] {
  return manifests.map((manifest: PersonaManifest): PersonaPack => personaPackForId(manifest.id));
}

export function updatePersonaPackText(personaId: string, soul: string, memory: string): void {
  const manifest = manifestForId(personaId);
  if (manifest.id !== personaId) {
    return;
  }
  setFileText(personaId, 'soul.md', soul);
  setFileText(personaId, 'memory.md', memory);
}

export function resetPersonaPackText(personaId: string): void {
  const defaultSoul = DEFAULT_PERSONA_FILES[personaId + '/soul.md'];
  const defaultMemory = DEFAULT_PERSONA_FILES[personaId + '/memory.md'];
  if (defaultSoul !== undefined) {
    setFileText(personaId, 'soul.md', defaultSoul);
  }
  if (defaultMemory !== undefined) {
    setFileText(personaId, 'memory.md', defaultMemory);
  }
}

export function personaEditableSnapshots(): PersonaEditableSnapshot[] {
  return manifests.map((manifest: PersonaManifest): PersonaEditableSnapshot => {
    return {
      id: manifest.id,
      soul: fileText(manifest.id, 'soul.md'),
      memory: fileText(manifest.id, 'memory.md')
    };
  });
}

export function applyPersonaEditableSnapshots(snapshots: PersonaEditableSnapshot[]): void {
  snapshots.forEach((snapshot: PersonaEditableSnapshot) => {
    updatePersonaPackText(snapshot.id, snapshot.soul, snapshot.memory);
  });
}

export function personaPackForId(id: string): PersonaPack {
  const manifest = manifestForId(id);
  return {
    manifest: manifest,
    soul: fileText(manifest.id, 'soul.md'),
    skills: fileText(manifest.id, 'skills.md'),
    memory: fileText(manifest.id, 'memory.md')
  };
}
