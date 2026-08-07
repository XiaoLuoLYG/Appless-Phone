export type PublicPersonaPlatform =
  'bilibili' | 'zhihu' | 'weibo' | 'xiaohongshu' | 'douyin' |
  'github' | 'x' | 'youtube' | 'linkedin' | 'reddit' | 'instagram';

export type PublicPersonaProviderState =
  'idle' | 'running' | 'success' | 'partial' | 'empty' |
  'needs_auth' | 'blocked_by_site' | 'rate_limited' |
  'credits_exhausted' | 'timeout' | 'error';

export type PublicPersonaPhase =
  'welcome' | 'input' | 'discovering' | 'awaiting_confirmation' |
  'reading' | 'summarizing' | 'complete' | 'error';

export type PublicPersonaOwnershipBand = 'high' | 'possible';

export interface PublicPersonaProbe {
  platform: PublicPersonaPlatform;
  label: string;
  domains: string[];
  profilePathPatterns: string[];
  displayUrlTemplate: string;
  probeUrlTemplate: string;
  usernamePattern: string;
  missingMarkers: string[];
}

export interface PublicPersonaIdentity {
  displayName: string;
  username: string;
  avatarUrl: string;
  canonicalUrl: string;
  linkedUrls: string[];
}

export interface PublicPersonaCandidate {
  id: string;
  platform: PublicPersonaPlatform;
  profileUrl: string;
  displayName: string;
  username: string;
  avatarUrl: string;
  exists: true;
  ownershipConfidence: number;
  ownershipBand: PublicPersonaOwnershipBand;
  selected: boolean;
  providerState: PublicPersonaProviderState;
  fetchedAt: string;
  sourceUrl: string;
}

export interface PublicPersonaPostEvidence {
  url: string;
  title: string;
  text: string;
  publishedAt: string;
  pinned: boolean;
}

export interface PublicPersonaAccountEvidence {
  platform: PublicPersonaPlatform;
  profileUrl: string;
  avatarUrl: string;
  displayName: string;
  username: string;
  bio: string;
  posts: PublicPersonaPostEvidence[];
  sourceUrls: string[];
  fetchedAt: string;
  providerState: PublicPersonaProviderState;
}

export interface PublicPersonaInference {
  titleName: string;
  oneLineSummary: string;
  identityAndExperience: string[];
  expertise: string[];
  interestsAndPreferences: string[];
  communicationStyle: string[];
  recentFocus: string[];
  personalityInference: string[];
  mbtiType: string;
  mbtiConfidence: number;
}

export interface PublicPersonaSourceRef {
  platform: PublicPersonaPlatform;
  profileUrl: string;
  avatarUrl: string;
  sourceUrls: string[];
  fetchedAt: string;
}

export interface PublicPersonaSnapshot {
  schemaVersion: 1;
  personaMarkdown: string;
  primaryAvatarUrl: string;
  sources: PublicPersonaSourceRef[];
  generatedAt: string;
  mbtiHidden: boolean;
}

export interface PublicPersonaProgress {
  completed: number;
  total: number;
  platform: PublicPersonaPlatform;
  state: PublicPersonaProviderState;
  message: string;
}

export interface PublicPersonaProfileUrl {
  platform: PublicPersonaPlatform;
  url: string;
}

const PLATFORMS: PublicPersonaProbe[] = [
  {
    platform: 'bilibili', label: '哔哩哔哩', domains: ['space.bilibili.com'],
    profilePathPatterns: ['/[0-9]+$'], displayUrlTemplate: 'https://space.bilibili.com/{username}',
    probeUrlTemplate: 'https://space.bilibili.com/{username}', usernamePattern: '^[0-9]+$',
    missingMarkers: ['该账号不存在', '用户不存在']
  },
  {
    platform: 'zhihu', label: '知乎', domains: ['zhihu.com'],
    profilePathPatterns: ['/people/'], displayUrlTemplate: 'https://www.zhihu.com/people/{username}',
    probeUrlTemplate: 'https://www.zhihu.com/people/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['你访问的页面不存在', '用户不存在']
  },
  {
    platform: 'weibo', label: '微博', domains: ['weibo.com'],
    profilePathPatterns: ['/u/', '/[0-9]+$'], displayUrlTemplate: 'https://weibo.com/u/{username}',
    probeUrlTemplate: 'https://weibo.com/u/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['抱歉，您访问的页面不存在']
  },
  {
    platform: 'xiaohongshu', label: '小红书', domains: ['xiaohongshu.com', 'xhslink.com'],
    profilePathPatterns: ['/user/profile/'], displayUrlTemplate: 'https://www.xiaohongshu.com/user/profile/{username}',
    probeUrlTemplate: 'https://www.xiaohongshu.com/user/profile/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['用户不存在', '页面不存在']
  },
  {
    platform: 'douyin', label: '抖音', domains: ['douyin.com'],
    profilePathPatterns: ['/user/'], displayUrlTemplate: 'https://www.douyin.com/user/{username}',
    probeUrlTemplate: 'https://www.douyin.com/user/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['用户不存在', '页面不存在']
  },
  {
    platform: 'github', label: 'GitHub', domains: ['github.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://github.com/{username}',
    probeUrlTemplate: 'https://github.com/{username}', usernamePattern: '^[a-zA-Z0-9-]+$',
    missingMarkers: ['Not Found', '页面不存在']
  },
  {
    platform: 'x', label: 'X', domains: ['x.com', 'twitter.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://x.com/{username}',
    probeUrlTemplate: 'https://x.com/{username}', usernamePattern: '^[a-zA-Z0-9_]+$',
    missingMarkers: ['This account doesn’t exist', '页面不存在']
  },
  {
    platform: 'youtube', label: 'YouTube', domains: ['youtube.com'],
    profilePathPatterns: ['/@', '/channel/'], displayUrlTemplate: 'https://www.youtube.com/@{username}',
    probeUrlTemplate: 'https://www.youtube.com/@{username}', usernamePattern: '^[a-zA-Z0-9._-]+$',
    missingMarkers: ['This page isn’t available', '页面不存在']
  },
  {
    platform: 'linkedin', label: 'LinkedIn', domains: ['linkedin.com'],
    profilePathPatterns: ['/in/'], displayUrlTemplate: 'https://www.linkedin.com/in/{username}',
    probeUrlTemplate: 'https://www.linkedin.com/in/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['Page not found', '登录']
  },
  {
    platform: 'reddit', label: 'Reddit', domains: ['reddit.com'],
    profilePathPatterns: ['/user/', '/u/'], displayUrlTemplate: 'https://www.reddit.com/user/{username}',
    probeUrlTemplate: 'https://www.reddit.com/user/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    missingMarkers: ['This account may have been banned', '页面不存在']
  },
  {
    platform: 'instagram', label: 'Instagram', domains: ['instagram.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://www.instagram.com/{username}',
    probeUrlTemplate: 'https://www.instagram.com/{username}', usernamePattern: '^[a-zA-Z0-9._]+$',
    missingMarkers: ['Sorry, this page isn’t available', '页面不存在']
  }
];

const MBTI_TYPES: string[] = [
  'ISTJ', 'ISFJ', 'INFJ', 'INTJ', 'ISTP', 'ISFP', 'INFP', 'INTP',
  'ESTP', 'ESFP', 'ENFP', 'ENTP', 'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ'
];

interface PublicPersonaHostPath {
  host: string;
  path: string;
}

function isPlatform(value: string): boolean {
  for (let index = 0; index < PLATFORMS.length; index++) {
    if (PLATFORMS[index].platform === value) {
      return true;
    }
  }
  return false;
}

function platformForHost(host: string): PublicPersonaPlatform | null {
  const normalized = host.toLowerCase();
  for (let index = 0; index < PLATFORMS.length; index++) {
    const probe = PLATFORMS[index];
    for (let domainIndex = 0; domainIndex < probe.domains.length; domainIndex++) {
      const domain = probe.domains[domainIndex];
      if (probe.platform === 'bilibili') {
        if (normalized === domain) {
          return probe.platform;
        }
        continue;
      }
      if (normalized === domain || normalized.endsWith('.' + domain)) {
        return probe.platform;
      }
    }
  }
  return null;
}

function hostAndPath(value: string): PublicPersonaHostPath | null {
  const schemeEnd = value.indexOf('://');
  if (schemeEnd <= 0) {
    return null;
  }
  const authorityStart = schemeEnd + 3;
  let end = value.length;
  const slash = value.indexOf('/', authorityStart);
  if (slash >= 0 && slash < end) {
    end = slash;
  }
  const authority = value.substring(authorityStart, end);
  if (authority.length === 0 || authority.indexOf('@') >= 0 || authority.indexOf(':') >= 0) {
    return null;
  }
  const path = end < value.length ? value.substring(end) : '/';
  return { host: authority, path: path };
}

function normalizedProfileUrl(value: string): string {
  const trimmed = value.trim();
  if (trimmed.endsWith('/') && trimmed.length > 1) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

function profilePathAllowed(platform: PublicPersonaPlatform, path: string): boolean {
  const normalized = path.toLowerCase();
  if (normalized === '/' || normalized.indexOf('..') >= 0) {
    return false;
  }
  if (platform === 'github' || platform === 'x' || platform === 'instagram') {
    if (normalized.split('/').length !== 2 || normalized.substring(1).indexOf('/') >= 0) {
      return false;
    }
    const username = normalized.substring(1);
    const reserved: string[] = platform === 'github' ?
      ['settings', 'explore', 'topics', 'collections', 'trending', 'events', 'marketplace', 'notifications', 'login', 'signup', 'search', 'about'] :
      platform === 'x' ?
        ['home', 'explore', 'search', 'i', 'settings', 'notifications', 'messages', 'compose', 'login', 'signup'] :
        ['accounts', 'explore', 'direct', 'reels', 'stories', 'about', 'login', 'signup'];
    return reserved.indexOf(username) < 0;
  }
  if (platform === 'youtube') {
    return normalized.indexOf('/@') === 0 || normalized.indexOf('/channel/') === 0;
  }
  if (platform === 'linkedin') {
    return normalized.indexOf('/in/') === 0 && normalized.substring(4).indexOf('/') < 0;
  }
  if (platform === 'reddit') {
    return (normalized.indexOf('/user/') === 0 || normalized.indexOf('/u/') === 0) &&
      normalized.lastIndexOf('/') === (normalized.indexOf('/user/') === 0 ? 5 : 2);
  }
  if (platform === 'zhihu') {
    return normalized.indexOf('/people/') === 0 && normalized.substring(8).indexOf('/') < 0;
  }
  if (platform === 'bilibili') {
    return /^\/[0-9]+$/.test(normalized);
  }
  if (platform === 'weibo') {
    const userPath = normalized.indexOf('/u/') === 0 && normalized.substring(3).indexOf('/') < 0;
    const numericRoot = /^\/[0-9]+$/.test(normalized);
    return userPath || numericRoot;
  }
  if (platform === 'xiaohongshu') {
    return normalized.indexOf('/user/profile/') === 0 && normalized.substring(14).indexOf('/') < 0;
  }
  return normalized.indexOf('/user/') === 0 && normalized.substring(6).indexOf('/') < 0;
}

function profileUsername(platform: PublicPersonaPlatform, path: string): string {
  const normalized = path.toLowerCase();
  if (platform === 'github' || platform === 'x' || platform === 'instagram' || platform === 'bilibili') {
    return normalized.substring(1);
  }
  if (platform === 'zhihu' || platform === 'linkedin') {
    return normalized.substring(platform === 'zhihu' ? 8 : 4);
  }
  if (platform === 'weibo') {
    return normalized.indexOf('/u/') === 0 ? normalized.substring(3) : normalized.substring(1);
  }
  if (platform === 'xiaohongshu') {
    return normalized.substring(14);
  }
  if (platform === 'douyin' || platform === 'reddit') {
    const prefix = normalized.indexOf('/user/') === 0 ? 6 : normalized.indexOf('/u/') === 0 ? 3 : 6;
    return normalized.substring(prefix);
  }
  if (platform === 'youtube') {
    return normalized.indexOf('/@') === 0 ? normalized.substring(2) : normalized.substring(9);
  }
  return '';
}

function profileUsernameAllowed(platform: PublicPersonaPlatform, path: string): boolean {
  const username = profileUsername(platform, path);
  for (let index = 0; index < PLATFORMS.length; index++) {
    if (PLATFORMS[index].platform === platform) {
      try {
        return new RegExp(PLATFORMS[index].usernamePattern).test(username);
      } catch (_error) {
        return false;
      }
    }
  }
  return false;
}

function nonEmptyString(value: Object | string | number | boolean | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

function stringArray(value: Object | string | number | boolean | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const values: string[] = [];
  const raw = value as Object[];
  for (let index = 0; index < raw.length; index++) {
    if (typeof raw[index] === 'string' && (raw[index] as string).trim().length > 0) {
      values.push((raw[index] as string).trim());
    }
  }
  return values;
}

function markdownList(values: string[]): string {
  if (values.length === 0) {
    return '- 暂无公开信息';
  }
  return values.map((value: string): string => '- ' + value).join('\n');
}

function validHttps(value: string): boolean {
  return value.startsWith('https://') && value.indexOf(' ') < 0 && value.indexOf('\n') < 0;
}

function validTimestamp(value: string): boolean {
  return value.trim().length >= 10 && value.indexOf(' ') < 0 && value.indexOf('\n') < 0;
}

export function publicPersonaCatalog(): PublicPersonaProbe[] {
  return PLATFORMS.map((probe: PublicPersonaProbe): PublicPersonaProbe => ({
    platform: probe.platform,
    label: probe.label,
    domains: probe.domains.slice(),
    profilePathPatterns: probe.profilePathPatterns.slice(),
    displayUrlTemplate: probe.displayUrlTemplate,
    probeUrlTemplate: probe.probeUrlTemplate,
    usernamePattern: probe.usernamePattern,
    missingMarkers: probe.missingMarkers.slice()
  }));
}

export function parsePublicProfileUrl(value: string): PublicPersonaProfileUrl | null {
  const trimmed = value.trim();
  if (!/^https:\/\//i.test(trimmed) || trimmed.indexOf('?') >= 0 || trimmed.indexOf('#') >= 0) {
    return null;
  }
  const parts = hostAndPath(trimmed);
  if (parts === null) {
    return null;
  }
  const path = parts.path.endsWith('/') && parts.path.length > 1 ?
    parts.path.substring(0, parts.path.length - 1) : parts.path;
  const platform = platformForHost(parts.host);
  if (platform === null || !profilePathAllowed(platform, path) || !profileUsernameAllowed(platform, path)) {
    return null;
  }
  return { platform: platform, url: normalizedProfileUrl(trimmed) };
}

export function scorePublicPersonaCandidate(
  seed: PublicPersonaIdentity,
  candidate: PublicPersonaIdentity
): number {
  const seedUsername = seed.username.trim().replace(/^@/, '').toLowerCase();
  const candidateUsername = candidate.username.trim().replace(/^@/, '').toLowerCase();
  const seedName = seed.displayName.trim().toLowerCase();
  const candidateName = candidate.displayName.trim().toLowerCase();
  let score = 0;
  const usernameAliases: string[] = [];
  const addAlias = (value: string): void => {
    const alias = value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]/g, '');
    if (alias.length > 1 && usernameAliases.indexOf(alias) < 0) {
      usernameAliases.push(alias);
    }
  };
  addAlias(seedUsername);
  const nameTokens = seedName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
  addAlias(nameTokens.join(''));
  addAlias(nameTokens.slice().reverse().join(''));
  for (let index = 0; index < usernameAliases.length; index++) {
    const alias = usernameAliases[index];
    if (candidateUsername === alias) {
      score = Math.max(score, 0.55);
    } else if (candidateUsername.indexOf(alias) >= 0) {
      score = Math.max(score, 0.45);
    }
  }
  if (seedName.length > 0 && seedName === candidateName) {
    score += 0.25;
  }
  const seedLinks = [seed.canonicalUrl].concat(seed.linkedUrls);
  const canonical = candidate.canonicalUrl;
  const crossSiteLink = candidate.linkedUrls.some((url: string): boolean =>
    url !== canonical && seedLinks.indexOf(url) >= 0);
  if (canonical.length > 0 && (canonical === seed.canonicalUrl || crossSiteLink)) {
    score += 0.20;
  }
  if (score === 0 && seedName.length > 0 && candidateName.length > 0) {
    const seedTokens = seedName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
    const candidateTokens = candidateName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
    for (let index = 0; index < seedTokens.length; index++) {
      if (candidateTokens.indexOf(seedTokens[index]) >= 0) {
        score = 0.10;
        break;
      }
    }
  }
  return Math.min(1, Number(score.toFixed(2)));
}

export function publicPersonaOwnershipBand(confidence: number): PublicPersonaOwnershipBand | null {
  if (confidence >= 0.75) {
    return 'high';
  }
  if (confidence >= 0.45) {
    return 'possible';
  }
  return null;
}

function inferenceJsonText(raw: string): string {
  const trimmed = raw.trim();
  const start = trimmed.indexOf('{');
  const end = trimmed.lastIndexOf('}');
  return start >= 0 && end > start ? trimmed.substring(start, end + 1) : trimmed;
}

export function parsePublicPersonaInference(raw: string): PublicPersonaInference | null {
  try {
    const parsed = JSON.parse(inferenceJsonText(raw)) as Record<string, Object | string | number | boolean>;
    const firstString = (key: string): string => {
      const values = stringArray(parsed[key]);
      return values.length > 0 ? values[0] : nonEmptyString(parsed[key]);
    };
    const alternateName = firstString('name');
    const alternateMbtiRaw = firstString('MBTI') || firstString('mbti');
    if (alternateName.length > 0) {
      let alternateType = '';
      let alternateConfidence = 0;
      if (alternateMbtiRaw.length > 0) {
        const mbtiMatch = /\b(INFJ|ENFJ|ISFJ|ESFJ|INTJ|ENTJ|ISTJ|ESTJ|ISFP|ESFP|INFP|ENFP|ISTP|ESTP|INTP|ENTP)\b/i.exec(alternateMbtiRaw);
        if (mbtiMatch === null) {
          return null;
        }
        alternateType = mbtiMatch[1].toUpperCase();
        const confidenceMatch = /(\d{1,3})\s*%/.exec(alternateMbtiRaw);
        alternateConfidence = confidenceMatch === null ? 50 : Math.min(100, Number(confidenceMatch[1]));
      }
      const alternateStrings = (key: string): string[] => {
        const value = parsed[key];
        if (Array.isArray(value)) {
          return stringArray(value);
        }
        return nonEmptyString(value).length > 0 ? [nonEmptyString(value)] : [];
      };
      const experience = alternateStrings('education').concat(alternateStrings('occupation'));
      const expertise = alternateStrings('skills').concat(alternateStrings('platforms'));
      const interests = alternateStrings('interests');
      const recent = alternateStrings('projects');
      const summary = firstString('jobTitle') || firstString('occupation') ||
        (expertise.length > 0 ? expertise[0] : '公开资料画像');
      return {
        titleName: alternateName,
        oneLineSummary: summary,
        identityAndExperience: experience,
        expertise: expertise,
        interestsAndPreferences: interests,
        communicationStyle: [],
        recentFocus: recent,
        personalityInference: [],
        mbtiType: alternateType,
        mbtiConfidence: alternateConfidence
      };
    }
    const arrayFields: string[] = [
      'identityAndExperience', 'expertise', 'interestsAndPreferences',
      'communicationStyle', 'recentFocus', 'personalityInference'
    ];
    for (let index = 0; index < arrayFields.length; index++) {
      if (!Array.isArray(parsed[arrayFields[index]])) {
        return null;
      }
    }
    const type = nonEmptyString(parsed['mbtiType']);
    const confidence = parsed['mbtiConfidence'];
    if (MBTI_TYPES.indexOf(type.toUpperCase()) < 0 || typeof confidence !== 'number' || confidence < 0 || confidence > 100) {
      return null;
    }
    const result: PublicPersonaInference = {
      titleName: nonEmptyString(parsed['titleName']),
      oneLineSummary: nonEmptyString(parsed['oneLineSummary']),
      identityAndExperience: stringArray(parsed['identityAndExperience']),
      expertise: stringArray(parsed['expertise']),
      interestsAndPreferences: stringArray(parsed['interestsAndPreferences']),
      communicationStyle: stringArray(parsed['communicationStyle']),
      recentFocus: stringArray(parsed['recentFocus']),
      personalityInference: stringArray(parsed['personalityInference']),
      mbtiType: type.toUpperCase(),
      mbtiConfidence: Math.round(confidence)
    };
    return result.titleName.length > 0 && result.oneLineSummary.length > 0 ? result : null;
  } catch (_error) {
    return null;
  }
}

export function renderPublicPersonaMarkdown(
  inference: PublicPersonaInference,
  sources: PublicPersonaSourceRef[]
): string {
  const lines: string[] = [
    '# ' + inference.titleName,
    '',
    '> ' + inference.oneLineSummary,
    '',
    '## 身份与经历',
    markdownList(inference.identityAndExperience),
    '',
    '## 专长',
    markdownList(inference.expertise),
    '',
    '## 兴趣与偏好',
    markdownList(inference.interestsAndPreferences),
    '',
    '## 沟通风格',
    markdownList(inference.communicationStyle),
    '',
    '## 近期关注',
    markdownList(inference.recentFocus),
    '',
    '## 性格推断',
    inference.personalityInference.length > 0 ? markdownList(inference.personalityInference) : '- 暂无足够公开信息',
    '',
    inference.mbtiType.length > 0 ?
      inference.mbtiType + ' · ' + inference.mbtiConfidence.toString() + '%（基于公开资料的推测，不是测评结论）' :
      'MBTI 暂无（公开资料不足）',
    '',
    '## 已确认账号'
  ];
  for (let index = 0; index < sources.length; index++) {
    const source = sources[index];
    lines.push('- [' + source.platform + '](' + source.profileUrl + ') · ' + source.profileUrl.substring(source.profileUrl.lastIndexOf('/') + 1));
  }
  return lines.join('\n');
}

export function hasRequiredPublicPersonaSections(markdown: string): boolean {
  const required: string[] = [
    '# ', '## 身份与经历', '## 专长', '## 兴趣与偏好', '## 沟通风格',
    '## 近期关注', '## 性格推断', '## 已确认账号'
  ];
  for (let index = 0; index < required.length; index++) {
    if (markdown.indexOf(required[index]) < 0) {
      return false;
    }
  }
  return true;
}

export function publicPersonaPreviewMarkdown(markdown: string, hidden: boolean): string {
  if (!hidden) {
    return markdown;
  }
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const visible: string[] = [];
  let hiddenSection = false;
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    if (line.trim().startsWith('## ')) {
      hiddenSection = line.trim().startsWith('## MBTI');
    }
    if (hiddenSection || /^-?\s*[EI][SN][TF][JP] · [0-9]+%/.test(line.trim())) {
      continue;
    }
    visible.push(line);
  }
  return visible.join('\n');
}

export function replacePublicPersonaMbti(markdown: string, mbtiType: string, confidence: number): string {
  const type = mbtiType.trim().toUpperCase();
  if (MBTI_TYPES.indexOf(type) < 0 || confidence < 0 || confidence > 100) {
    return markdown;
  }
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const replacement = type + ' · ' + Math.round(confidence).toString() + '%（基于公开资料的推测，不是测评结论）';
  let inPersonality = false;
  for (let index = 0; index < lines.length; index++) {
    if (lines[index] === '## 性格推断') {
      inPersonality = true;
      continue;
    }
    if (inPersonality && lines[index].startsWith('## ')) {
      lines.splice(index, 0, replacement);
      return lines.join('\n');
    }
    if (inPersonality && /^[EI][SN][TF][JP] · [0-9]+%/.test(lines[index])) {
      lines[index] = replacement;
      return lines.join('\n');
    }
  }
  if (inPersonality) {
    lines.push(replacement);
  }
  return lines.join('\n');
}

export function sanitizePublicPersonaSnapshot(value: Object): PublicPersonaSnapshot | null {
  try {
    const raw = value as Record<string, Object | string | number | boolean | Object[]>;
    if (raw['schemaVersion'] !== 1 || typeof raw['personaMarkdown'] !== 'string' ||
      typeof raw['primaryAvatarUrl'] !== 'string' || typeof raw['generatedAt'] !== 'string' ||
      typeof raw['mbtiHidden'] !== 'boolean' || !hasRequiredPublicPersonaSections(raw['personaMarkdown'])) {
      return null;
    }
    if (!validHttps(raw['primaryAvatarUrl']) || !validTimestamp(raw['generatedAt'])) {
      return null;
    }
    const markdownLines = raw['personaMarkdown'].replace(/\r\n/g, '\n').split('\n');
    let inPersonality = false;
    for (let index = 0; index < markdownLines.length; index++) {
      const line = markdownLines[index].trim();
      if (line === '## 性格推断') {
        inPersonality = true;
        continue;
      }
      if (inPersonality && line.startsWith('## ')) {
        break;
      }
      if (inPersonality) {
        const mbti = /^([A-Za-z]{3,8})\s*·\s*(-?\d+(?:\.\d+)?)%/.exec(line);
        if (mbti !== null && (MBTI_TYPES.indexOf(mbti[1].toUpperCase()) < 0 ||
          Number.parseFloat(mbti[2]) < 0 || Number.parseFloat(mbti[2]) > 100)) {
          return null;
        }
      }
    }
    for (let index = 0; index < markdownLines.length; index++) {
      const mbti = /^-?\s*([A-Za-z]{3,8})\s*·\s*(-?\d+(?:\.\d+)?)%/.exec(markdownLines[index].trim());
      if (mbti !== null && (MBTI_TYPES.indexOf(mbti[1].toUpperCase()) < 0 ||
        Number.parseFloat(mbti[2]) < 0 || Number.parseFloat(mbti[2]) > 100)) {
        return null;
      }
    }
    const rawSources = raw['sources'];
    if (!Array.isArray(rawSources) || rawSources.length === 0) {
      return null;
    }
    const sources: PublicPersonaSourceRef[] = [];
    for (let index = 0; index < rawSources.length; index++) {
      const source = rawSources[index] as Record<string, Object | string | Object[]>;
      const platform = nonEmptyString(source['platform']);
      const profileUrl = nonEmptyString(source['profileUrl']);
      const avatarUrl = nonEmptyString(source['avatarUrl']);
      const fetchedAt = nonEmptyString(source['fetchedAt']);
      const parsed = parsePublicProfileUrl(profileUrl);
      const sourceUrls = stringArray(source['sourceUrls']);
      if (!isPlatform(platform) || parsed === null || parsed.platform !== (platform as PublicPersonaPlatform) ||
        !validHttps(avatarUrl) || !validTimestamp(fetchedAt) || sourceUrls.length === 0) {
        return null;
      }
      const filteredSourceUrls = sourceUrls.filter((url: string): boolean => validHttps(url));
      if (filteredSourceUrls.length === 0) {
        return null;
      }
      sources.push({
        platform: platform as PublicPersonaPlatform,
        profileUrl: parsed.url,
        avatarUrl: avatarUrl,
        sourceUrls: filteredSourceUrls,
        fetchedAt: fetchedAt
      });
    }
    const primary = raw['primaryAvatarUrl'] as string;
    if (sources.filter((source: PublicPersonaSourceRef): boolean => source.avatarUrl === primary).length === 0) {
      return null;
    }
    return {
      schemaVersion: 1,
      personaMarkdown: raw['personaMarkdown'] as string,
      primaryAvatarUrl: primary,
      sources: sources,
      generatedAt: raw['generatedAt'] as string,
      mbtiHidden: raw['mbtiHidden'] as boolean
    };
  } catch (_error) {
    return null;
  }
}
