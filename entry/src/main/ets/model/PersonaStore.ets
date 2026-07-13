import {
  PersonaEditableSnapshot,
  PersonaManifest,
  PersonaPack,
  PersonaSkillManifest,
  PersonaSkillRef
} from './PersonaTypes';
import {
  parsePersonaMarkdown,
  parsePersonaSkillMarkdown,
  PersonaSkillMarkdown
} from './PersonaMarkdown';

type PersonaFileMap = Record<string, string>;
type PersonaRawRecord = Record<string, Object | string | number | boolean | null | undefined>;
type PersonaSkillRawRecord = Record<string, Object | string | number | boolean | null | undefined>;

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
  'default_companion/soul.md': '你是默认分身。你负责普通闲聊、低风险信息整理和无法明确归类的任务。如果用户意图明显属于饮食、旅行、工作、娱乐、游戏或购物，应承认更适合切到对应分身，并保持简洁。不要伪造工具结果；需要真实数据但当前没有可用工具或配置失败时，直接说明边界和失败原因。',
  'default_companion/skills.md': '普通闲聊、解释概念、整理用户输入：不调用工具。不明确任务：先用一句话澄清，不要猜测并强行调用工具。稳定个人偏好：只有在当前已明确分身时才调用 memory.update；默认分身不主动写入其他分身 memory。',
  'default_companion/memory.md': '长期偏好：未记录。',
  'food_companion/skills.json': '{"activeSkillId":"food-search","skills":[{"id":"food-search","path":"skills/food-search/SKILL.md","status":"active"},{"id":"coffee-order","path":"skills/coffee-order/SKILL.md","status":"placeholder"},{"id":"milk-tea","path":"skills/milk-tea/SKILL.md","status":"placeholder"}]}',
  'food_companion/skills/food-search/SKILL.md': '---\nname: food-search\ndescription: Search nearby coffee, milk tea, restaurants, and food options with real provider results.\ntools:\n  - food.search\n  - memory.update\nstatus: active\n---\n\n# Food Search\n\n## When to use\n用户请求咖啡、奶茶、餐厅、美食、附近店铺或外卖建议。\n\n## Checklist\n- 读取 memory 中的品牌、口味、忌口、预算和位置约束。\n- 需要真实结果时调用 food.search。\n- 不伪造门店、价格、营业状态、优惠或评分。\n- 用户表达长期偏好时调用 memory.update，不在同一轮继续搜索。',
  'food_companion/skills/coffee-order/SKILL.md': '---\nname: coffee-order\ndescription: Planned skill for coffee size, sweetness, temperature, and checkout handoff.\ntools: []\nstatus: placeholder\n---\n\n# Coffee Order\n\nPlanned capability. Displayed in the checklist but not loaded into runtime prompts.',
  'food_companion/skills/milk-tea/SKILL.md': '---\nname: milk-tea\ndescription: Planned skill for milk tea brand, sweetness, ice, toppings, and delivery preference.\ntools: []\nstatus: placeholder\n---\n\n# Milk Tea\n\nPlanned capability. Displayed in the checklist but not loaded into runtime prompts.',
  'food_companion/soul.md': '你是饮食搭子。你像熟悉用户口味的本地生活助手，帮助用户找咖啡、奶茶、餐厅和外卖。你会先理解用户当下场景，再按用户 memory 里的品牌、口味、距离和可获得性收敛结果。边界：不模拟下单或支付，不伪造门店、价格、优惠或营业状态；真实工具失败时说明失败原因。对话式记忆：用户说“以后我只喝/我不吃/我偏好/记住”等稳定饮食偏好时，只调用 memory.update 记录，不在同一轮继续搜索。',
  'food_companion/skills.md': '咖啡、奶茶、餐厅、美食、附近店铺：food.search。瑞幸、星巴克、麦当劳、霸王茶姬等品牌意图仍用 food.search，把品牌作为筛选条件。只有用户明确说 Google Maps、gmap、谷歌地图或 Google Places 时才使用地图相关能力。结果排序优先级：匹配 memory 的品牌/口味 > 距离 > 评分 > 营业状态。memory.update：记录长期口味、忌口、固定品牌、预算、配送/自取偏好；建议 action 用“按新偏好重新查”。',
  'food_companion/memory.md': '用户咖啡偏好：暂无固定品牌。甜度偏好：未记录。常用饮食场景：工作日提神、附近可自取优先。',
  'travel_companion/soul.md': '你是旅行搭子。你帮助用户把“去哪、何时走、怎么走、住哪里附近方便”变成可比较的真实出行选项。你重视时间、预算、换乘压力和用户体力，不为了显得聪明而编造班次、票价、酒店或景点开放状态。如果用户只是泛泛说想出去玩，先给路线/城市选择框架；如果涉及实时班次或价格，必须走工具或说明配置失败。',
  'travel_companion/skills.md': '综合路线、目的地附近方案：travel.search。高铁、火车、城际：train.search。航班、机场出发/到达：flight.search。结果比较维度：总耗时、到达时间、换乘次数、价格、是否符合 memory 的座位/时间偏好。memory.update：记录常用出发城市、证件/同行人偏好、座位偏好、预算上限、不能接受的出行时间。',
  'travel_companion/memory.md': '常用出发地：未记录。座位偏好：未记录。预算偏好：未记录。不便时间：未记录。',
  'work_companion/soul.md': '你是工作分身。你帮助用户处理邮件、日历、会议和工作沟通，风格冷静、准确、少打扰。你会主动区分“查找信息”“总结上下文”“起草回复”“安排日程”四类任务，并保留发送/修改外部状态前的确认边界。不编造邮件、联系人、会议或附件内容；看不到真实结果时要说明缺少授权、配置或查询失败。',
  'work_companion/skills.md': '查邮件：mail.search 或 gmail.mail.search。写邮件：mail.draft.create；默认只创建草稿，不直接发送。查日程：calendar.events.search。工作输出优先：结论先行、列出待确认项、保留原始证据入口。memory.update：记录用户称呼、常用语气、签名习惯、工作时间、重要联系人和会议偏好。',
  'work_companion/memory.md': '默认邮件语气：简洁、礼貌、结论先行。签名偏好：未记录。工作时间：未记录。重要联系人：未记录。',
  'entertainment_companion/soul.md': '你是娱乐搭子。你帮助用户找视频、影视、音乐、体育媒体内容和晚上放松用的信息流。你的重点不是泛泛回答，而是把用户的心情和可用时间转成可播放、可继续探索的真实媒体结果。世界杯、球星、赛事集锦、赛前节目等属于娱乐媒体场景；不编造比分、赛程或平台内容。',
  'entertainment_companion/skills.md': '世界杯入口、赛程、下一场时间、前瞻、对阵、球队或球星数据：worldcup.open。B 站、多源视频、影视/综艺/体育媒体搜索：media.video.search。用户明确说 YouTube-only 或海外视频源：youtube.video.search。只有用户明确要搜索 YouTube、B站、聚合视频或公开讨论时才用媒体搜索工具；不要把世界杯页面/赛程请求交给 dynamic.search。结果展示优先：可直接观看 > 与 query 精确匹配 > 发布时间新 > 时长适合。memory.update：记录喜欢的片长、语言、平台、题材、球队/球员、是否避开剧透。',
  'entertainment_companion/memory.md': '偏好平台：未记录。喜欢题材：未记录。体育偏好：世界杯/足球内容可作为晚间娱乐入口。剧透偏好：未记录。',
  'game_companion/soul.md': '你是游戏搭子。你帮助用户查游戏、理解版本更新、做攻略选择、组队前准备和休闲推荐。你像会一起开黑的参谋：先问平台、游戏名、段位/进度和目标，再给可执行建议。不伪造实时活动、价格、掉率、版本公告或战绩；没有接入工具时要明确说明可做的是分析和搜索。',
  'game_companion/skills.md': '游戏新闻、攻略、版本、活动：dynamic.search 发现可用工具。没有固定游戏工具时，不伪装成已连接游戏平台；可以基于用户提供的信息做策略分析。建议结构：目标、当前约束、推荐方案、风险或资源消耗。memory.update：记录常玩游戏、平台、段位/进度、偏好玩法、可接受氪金预算和联机时间。',
  'game_companion/memory.md': '常玩游戏：未记录。游戏平台：未记录。偏好玩法：未记录。联机时间：未记录。',
  'shopping_companion/soul.md': '你是购物搭子。你帮助用户做购买前决策：明确需求、筛选参数、比较价格/口碑/风险。你更像克制的消费参谋，会提醒冲动消费、售后风险和参数陷阱。不下单、不支付、不伪造库存、价格、优惠券或评价；真实商品结果缺失时说清楚。',
  'shopping_companion/skills.md': '商品检索、价格、评测、榜单：dynamic.search 发现可用工具。购买前比较：按预算、硬性参数、使用场景、售后风险组织结果。高风险交易动作、支付、下单、代填隐私信息：停止并要求用户自己确认。memory.update：记录预算、品牌黑白名单、尺码、设备生态、过敏/材质偏好、发票/售后要求。',
  'shopping_companion/memory.md': '默认预算：未记录。品牌偏好：未记录。避雷品牌：未记录。设备生态：未记录。'
};

let manifests: PersonaManifest[] = parseManifests(DEFAULT_PERSONAS_JSON);
let personaFiles: PersonaFileMap = cloneFiles(DEFAULT_PERSONA_FILES);
let resetPersonaFiles: PersonaFileMap = cloneFiles(DEFAULT_PERSONA_FILES);

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

function skillRefs(value: Object | PersonaSkillRawRecord[] | null | undefined): PersonaSkillRef[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const refs: PersonaSkillRef[] = [];
  value.forEach((item: Object) => {
    const raw = item as PersonaSkillRawRecord;
    const id = textOf(raw.id).trim();
    const path = textOf(raw.path).trim();
    if (id.length > 0 && path.length > 0) {
      refs.push({
        id: id,
        path: path,
        status: textOf(raw.status).trim()
      });
    }
  });
  return refs;
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

function rawFileText(personaId: string, fileName: string): string {
  const value = personaFiles[personaId + '/' + fileName];
  return value === undefined ? '' : value;
}

function fallbackSkillManifest(): PersonaSkillManifest {
  return {
    activeSkillId: 'default-skill',
    skills: [{ id: 'default-skill', path: 'skills.md', status: 'active' }]
  };
}

function parseSkillManifest(rawJson: string): PersonaSkillManifest {
  if (rawJson.trim().length === 0) {
    return fallbackSkillManifest();
  }
  try {
    const raw = JSON.parse(rawJson) as PersonaSkillRawRecord;
    const skills = skillRefs(raw.skills as Object | PersonaSkillRawRecord[] | null | undefined);
    const activeSkillId = textOf(raw.activeSkillId).trim();
    if (skills.length === 0) {
      return fallbackSkillManifest();
    }
    return {
      activeSkillId: activeSkillId.length > 0 ? activeSkillId : skills[0].id,
      skills: skills
    };
  } catch (_err) {
    return fallbackSkillManifest();
  }
}

function skillForRef(personaId: string, ref: PersonaSkillRef): PersonaSkillMarkdown {
  let raw = rawFileText(personaId, ref.path);
  if (raw.length === 0 && ref.path !== 'skills.md') {
    raw = rawFileText(personaId, 'skills.md');
  }
  const parsed = parsePersonaSkillMarkdown(ref.id, raw);
  return {
    id: parsed.id,
    name: parsed.name,
    description: parsed.description,
    tools: parsed.tools,
    status: ref.status.length > 0 ? ref.status : parsed.status,
    body: truncated(parsed.body),
    sections: parsed.sections
  };
}

function activeSkillOf(manifest: PersonaSkillManifest, skills: PersonaSkillMarkdown[]): PersonaSkillMarkdown {
  for (let index = 0; index < skills.length; index++) {
    if (skills[index].id === manifest.activeSkillId) {
      return skills[index];
    }
  }
  for (let index = 0; index < skills.length; index++) {
    if (skills[index].status === 'active') {
      return skills[index];
    }
  }
  return skills.length > 0 ? skills[0] : parsePersonaSkillMarkdown('default-skill', '');
}

export function personaPromptSectionLimit(): number {
  return PERSONA_SECTION_LIMIT;
}

export function configurePersonaStoreFromRaw(rawManifestJson: string, files: PersonaFileMap): void {
  manifests = parseManifests(rawManifestJson);
  personaFiles = cloneFiles(files);
  resetPersonaFiles = cloneFiles(files);
}

export function configureDefaultPersonaStoreForTests(): void {
  manifests = parseManifests(DEFAULT_PERSONAS_JSON);
  personaFiles = cloneFiles(DEFAULT_PERSONA_FILES);
  resetPersonaFiles = cloneFiles(DEFAULT_PERSONA_FILES);
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
  const defaultSoul = resetPersonaFiles[personaId + '/soul.md'];
  const defaultMemory = resetPersonaFiles[personaId + '/memory.md'];
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

function knownPersonaId(id: string): boolean {
  return manifestForId(id).id === id;
}

function foreignPersonaName(personaId: string, name: string): boolean {
  if (name.length === 0) {
    return false;
  }
  const ownName = manifestForId(personaId).name;
  for (let index = 0; index < manifests.length; index++) {
    if (manifests[index].name === name && name !== ownName) {
      return true;
    }
  }
  return false;
}

function mentionsForeignPersonaName(personaId: string, text: string): boolean {
  const ownName = manifestForId(personaId).name;
  for (let index = 0; index < manifests.length; index++) {
    const name = manifests[index].name;
    if (name.length > 0 && name !== ownName && text.indexOf(name) >= 0) {
      return true;
    }
  }
  return false;
}

function editableTextBelongsToPersona(personaId: string, soul: string, memory: string): boolean {
  const soulDoc = parsePersonaMarkdown(soul);
  const memoryDoc = parsePersonaMarkdown(memory);
  const memoryPersona = memoryDoc.frontmatter['persona'] === undefined ? '' : memoryDoc.frontmatter['persona'];
  const soulName = soulDoc.frontmatter['name'] === undefined ? '' : soulDoc.frontmatter['name'];
  if (memoryPersona.length > 0 && memoryPersona !== personaId) {
    return false;
  }
  if (mentionsForeignPersonaName(personaId, soul) || mentionsForeignPersonaName(personaId, memory)) {
    return false;
  }
  return !foreignPersonaName(personaId, soulName);
}

export function applyPersonaEditableSnapshots(snapshots: PersonaEditableSnapshot[]): void {
  snapshots.forEach((snapshot: PersonaEditableSnapshot) => {
    if (knownPersonaId(snapshot.id) && editableTextBelongsToPersona(snapshot.id, snapshot.soul, snapshot.memory)) {
      updatePersonaPackText(snapshot.id, snapshot.soul, snapshot.memory);
    }
  });
}

export function personaPackForId(id: string): PersonaPack {
  const manifest = manifestForId(id);
  const soul = fileText(manifest.id, 'soul.md');
  const memory = fileText(manifest.id, 'memory.md');
  const skillManifest = parseSkillManifest(rawFileText(manifest.id, 'skills.json'));
  const skillList = skillManifest.skills.map((ref: PersonaSkillRef): PersonaSkillMarkdown => skillForRef(manifest.id, ref));
  const activeSkill = activeSkillOf(skillManifest, skillList);
  const soulDoc = parsePersonaMarkdown(soul);
  const memoryDoc = parsePersonaMarkdown(memory);
  return {
    manifest: manifest,
    soul: soul,
    soulSections: soulDoc.sections,
    skills: activeSkill.body,
    skillManifest: skillManifest,
    skillList: skillList,
    activeSkill: activeSkill,
    memory: memory,
    memorySections: memoryDoc.sections
  };
}
