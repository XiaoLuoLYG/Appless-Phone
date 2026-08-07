import { preferences } from '@kit.ArkData';
import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiMessage,
  DataResult,
  DataResultError,
  DataResultStatus,
  DynamicGenericToolResult,
  GenericStructuredData,
  LocalModelSettings
} from '@loop/agent-core';
import { A2uiLabelValueData } from '@loop/agent-core';
import {
  PublicPersonaSourceRef,
  PublicPersonaSnapshot,
  PublicPersonaCandidate,
  PublicPersonaInference,
  PublicPersonaProgress,
  PublicPersonaIdentity,
  parsePublicPersonaInference,
  parsePublicProfileUrl,
  publicPersonaCatalog,
  publicPersonaOwnershipBand,
  publicPersonaPreviewMarkdown,
  renderPublicPersonaMarkdown,
  replacePublicPersonaMbti,
  sanitizePublicPersonaSnapshot,
  scorePublicPersonaCandidate,
  hasRequiredPublicPersonaSections
} from '../main/ets/publicpersona/PublicPersonaModel';
import {
  PUBLIC_PERSONA_ONBOARDING_KEY,
  PUBLIC_PERSONA_SNAPSHOT_KEY,
  PublicPersonaStore
} from '../main/ets/publicpersona/PublicPersonaStore';
import {
  PublicPersonaClient,
  PublicPersonaModelCaller,
  PublicPersonaToolCaller
} from '../main/ets/publicpersona/PublicPersonaClient';
import { DirectModelCallResult } from '../main/ets/model/LocalModelClient';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();
  failPut: boolean = false;
  failDelete: boolean = false;

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    if (this.failPut) {
      throw new Error('put failed');
    }
    this.values.set(key, value);
  }

  deleteSync(key: string): void {
    if (this.failDelete) {
      throw new Error('delete failed');
    }
    this.values.delete(key);
  }

  flushSync(): void {}
}

interface MarkdownEnvelopeData {
  markdown: string;
}

interface MarkdownEnvelope {
  success: boolean;
  data: MarkdownEnvelopeData;
}

function nativePreferences(): preferences.Preferences {
  return new MemoryPreferences() as Object as preferences.Preferences;
}

function validSnapshot(): PublicPersonaSnapshot {
  const source: PublicPersonaSourceRef = {
    platform: 'github',
    profileUrl: 'https://github.com/ada',
    avatarUrl: 'https://github.com/ada.png',
    sourceUrls: ['https://github.com/ada'],
    fetchedAt: '2026-08-06T00:00:00.000Z'
  };
  return {
    schemaVersion: 1,
    personaMarkdown: [
      '# Ada Lovelace', '', '> 喜欢把复杂问题讲清楚。', '',
      '## 身份与经历', '- 软件先驱', '', '## 专长', '- 算法', '',
      '## 兴趣与偏好', '- 数学', '', '## 沟通风格', '- 结构化', '',
      '## 近期关注', '- 公开技术写作', '', '## 性格推断', 'ENTP · 68%', '',
      '## 已确认账号', '- [github](https://github.com/ada) · ada'
    ].join('\n'),
    primaryAvatarUrl: source.avatarUrl,
    sources: [source],
    generatedAt: '2026-08-06T00:00:00.000Z',
    mbtiHidden: false
  };
}

function dataResult(toolId: string, data: Object, status: DataResultStatus = 'success'): DataResult {
  return {
    toolId: toolId,
    outputSchema: 'object',
    status: status,
    sources: [],
    data: data,
    warnings: []
  };
}

function dynamicResult(
  toolName: string,
  status: string,
  rawPreview: string = '',
  rows: A2uiLabelValueData[] = []
): DynamicGenericToolResult {
  return {
    sourceTag: 'firecrawl',
    toolName: toolName,
    title: toolName,
    status: status,
    summary: status,
    rows: rows,
    rawPreview: rawPreview
  };
}

function dynamicDataResult(
  toolId: string,
  results: DynamicGenericToolResult[],
  status: DataResultStatus = 'success'
): DataResult {
  const data: GenericStructuredData = { results: results };
  return dataResult(toolId, data as Object, status);
}

function modelSettings(): LocalModelSettings {
  return {
    provider: 'test',
    baseUrl: 'https://model.invalid/v1',
    model: 'test-model',
    apiKey: '',
    customParametersJson: '{}',
    ignoreToolSurfaceUpdates: false
  };
}

function modelInferenceResult(mbtiType: string = 'ENTP'): DirectModelCallResult {
  return {
    ok: true,
    raw: JSON.stringify({
      titleName: 'Ada Lovelace', oneLineSummary: '喜欢把复杂问题讲清楚。',
      identityAndExperience: ['软件先驱'], expertise: ['算法'],
      interestsAndPreferences: ['数学'], communicationStyle: ['结构化'],
      recentFocus: ['公开技术写作'], personalityInference: ['偏好探索新想法'],
      mbtiType: mbtiType, mbtiConfidence: 68
    }),
    error: '', requestDebug: '', assistantDebug: ''
  };
}

interface ProfileFixture {
  displayName: string;
  username: string;
  avatarUrl: string;
  canonicalUrl?: string;
  linkedUrls?: string[];
  bio?: string;
  posts?: Object[];
  sourceUrls?: string[];
}

interface SearchRowFixture {
  url: string;
}

interface SearchFixture {
  results: SearchRowFixture[];
}

interface PostFixture {
  url: string;
  title: string;
  text: string;
  publishedAt: string;
  pinned: boolean;
}

interface PostsFixture {
  posts: PostFixture[];
}

interface FirecrawlFullReadFixture {
  publicBio: string;
  pinnedPosts: PostFixture[];
  latestPosts: PostFixture[];
}

interface EvidenceFixture {
  bio: string;
  posts: Object[];
  sourceUrls: string[];
}

export default function publicPersonaTest() {
  describe('publicPersonaModel', () => {
    it('keeps the agreed eleven-platform catalog', 0, () => {
      const platforms = publicPersonaCatalog().map((probe) => probe.platform);

      expect(platforms.length).assertEqual(11);
      expect(platforms.join(',')).assertEqual(
        'bilibili,zhihu,weibo,xiaohongshu,douyin,github,x,youtube,linkedin,reddit,instagram'
      );
      expect(platforms.indexOf('jike' as never)).assertEqual(-1);
      expect(platforms.indexOf('tiktok' as never)).assertEqual(-1);
    });

    it('only accepts an allowlisted public profile URL', 0, () => {
      const accepted = parsePublicProfileUrl('https://github.com/octocat');

      expect(accepted === null).assertFalse();
      expect(accepted?.platform).assertEqual('github');
      expect(accepted?.url).assertEqual('https://github.com/octocat');
      expect(parsePublicProfileUrl('javascript:alert(1)')).assertEqual(null);
      expect(parsePublicProfileUrl('https://github.com/octocat?token=secret')).assertEqual(null);
      expect(parsePublicProfileUrl('https://example.com/octocat')).assertEqual(null);
      const bilibili = parsePublicProfileUrl('https://space.bilibili.com/123456');
      expect(bilibili === null).assertFalse();
      expect(bilibili?.platform).assertEqual('bilibili');
    });

    it('requires HTTPS and a real profile path at the public boundary', 0, () => {
      expect(parsePublicProfileUrl('http://github.com/octocat')).assertEqual(null);
      expect(parsePublicProfileUrl('https://github.com/settings')).assertEqual(null);
      expect(parsePublicProfileUrl('https://x.com/home')).assertEqual(null);
      expect(parsePublicProfileUrl('https://space.bilibili.com/not-a-uid')).assertEqual(null);
      expect(parsePublicProfileUrl('https://www.youtube.com/watch')).assertEqual(null);
    });

    it('keeps Bilibili catalog paths aligned with its canonical uid URL', 0, () => {
      const bilibili = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'bilibili')[0];
      expect(bilibili === undefined).assertFalse();
      expect(bilibili?.domains.join(',')).assertEqual('space.bilibili.com');
      expect(bilibili?.profilePathPatterns.indexOf('/[0-9]+$')).assertLarger(-1);
      expect(parsePublicProfileUrl('https://space.bilibili.com/123456')?.url)
        .assertEqual('https://space.bilibili.com/123456');
      expect(parsePublicProfileUrl('https://www.bilibili.com/123456')).assertEqual(null);
      expect(parsePublicProfileUrl('https://mirror.space.bilibili.com/123456')).assertEqual(null);
    });

    it('keeps Weibo catalog paths aligned with real public profile roots', 0, () => {
      const weibo = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'weibo')[0];
      expect(weibo === undefined).assertFalse();
      expect(weibo?.profilePathPatterns.indexOf('/u/')).assertLarger(-1);
      expect(weibo?.profilePathPatterns.indexOf('/[0-9]+$')).assertLarger(-1);
      expect(parsePublicProfileUrl('https://weibo.com/u/123456') === null).assertFalse();
      expect(parsePublicProfileUrl('https://weibo.com/123456') === null).assertFalse();
      expect(parsePublicProfileUrl('https://weibo.com/p/handle')).assertEqual(null);
    });

    it('separates ownership confidence from account existence', 0, () => {
      const seed: PublicPersonaIdentity = {
        displayName: 'Ada Lovelace',
        username: 'ada',
        avatarUrl: 'https://github.com/ada.png',
        canonicalUrl: 'https://github.com/ada',
        linkedUrls: []
      };
      const exact = scorePublicPersonaCandidate(seed, seed);
      const weakCandidate: PublicPersonaIdentity = {
        displayName: 'A. Lovelace',
        username: 'ada_l',
        avatarUrl: 'https://example.com/a.png',
        canonicalUrl: 'https://example.com/ada_l',
        linkedUrls: []
      };
      const weak = scorePublicPersonaCandidate(seed, weakCandidate);

      expect(exact).assertEqual(1);
      expect(publicPersonaOwnershipBand(exact)).assertEqual('high');
      expect(publicPersonaOwnershipBand(0.6)).assertEqual('possible');
      expect(publicPersonaOwnershipBand(0.2)).assertEqual(null);
      expect(weak).assertEqual(0.45);
      expect(publicPersonaOwnershipBand(weak)).assertEqual('possible');
    });

    it('does not award ownership for a candidate self-link', 0, () => {
      const seed: PublicPersonaIdentity = {
        displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
        canonicalUrl: 'https://github.com/ada', linkedUrls: []
      };
      const selfLinked: PublicPersonaIdentity = {
        displayName: 'Different Name', username: 'ada', avatarUrl: 'https://x.com/ada.png',
        canonicalUrl: 'https://x.com/ada', linkedUrls: ['https://x.com/ada']
      };

      const confidence = scorePublicPersonaCandidate(seed, selfLinked);
      expect(confidence).assertEqual(0.55);
      expect(publicPersonaOwnershipBand(confidence)).assertEqual('possible');
    });

    it('renders fixed markdown sections and a revocable MBTI line', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace',
        oneLineSummary: '喜欢把复杂问题讲清楚。',
        identityAndExperience: ['软件先驱'],
        expertise: ['算法'],
        interestsAndPreferences: ['数学'],
        communicationStyle: ['结构化'],
        recentFocus: ['公开技术写作'],
        personalityInference: ['偏好探索新想法'],
        mbtiType: 'ENTP',
        mbtiConfidence: 68
      }));
      const sources: PublicPersonaSourceRef[] = [{
        platform: 'github',
        profileUrl: 'https://github.com/ada',
        avatarUrl: 'https://github.com/ada.png',
        sourceUrls: ['https://github.com/ada'],
        fetchedAt: '2026-08-06T00:00:00.000Z'
      }];

      expect(inference === null).assertFalse();
      const markdown = renderPublicPersonaMarkdown(inference as never, sources);
      expect(hasRequiredPublicPersonaSections(markdown)).assertTrue();
      expect(markdown).assertContain('ENTP · 68%');
      expect(markdown).assertContain('## 已确认账号');

      const fenced = '```json\n' + JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 68
      }) + '\n```';
      expect(parsePublicPersonaInference(fenced) === null).assertFalse();

      const replaced = replacePublicPersonaMbti(markdown, 'INFJ', 72);
      expect(replaced).assertContain('INFJ · 72%');
      expect(replaced).assertContain('## 已确认账号');
    });

    it('accepts the compact profile schema returned by the local model', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        name: 'Yige Luo', username: 'XiaoLuoLYG', jobTitle: 'AI engineer', education: ['公开教育经历'],
        interests: ['AI'], projects: ['公开项目'], skills: ['ArkTS'], MBTI: 'INTJ 72%'
      }));
      expect(inference === null).assertFalse();
      expect((inference as never as PublicPersonaInference).titleName).assertEqual('Yige Luo');
      expect((inference as never as PublicPersonaInference).mbtiType).assertEqual('INTJ');
      expect((inference as never as PublicPersonaInference).mbtiConfidence).assertEqual(72);
    });

    it('accepts array-valued compact output when MBTI is unavailable', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        name: ['Yige Luo'], username: ['XiaoLuoLYG'], platforms: ['github'],
        education: ['University of Cambridge (Master of Engineering)'],
        occupation: ['Senior AI Engineer at Huawei 2012 Lab'],
        interests: ['AI agents and multi-agent systems'], projects: ['GOD - real-time control room'],
        mbti: [], enneagram: [], bigFive: []
      }));
      expect(inference === null).assertFalse();
      expect((inference as never as PublicPersonaInference).titleName).assertEqual('Yige Luo');
      expect((inference as never as PublicPersonaInference).oneLineSummary).assertEqual('Senior AI Engineer at Huawei 2012 Lab');
      expect((inference as never as PublicPersonaInference).interestsAndPreferences[0]).assertEqual('AI agents and multi-agent systems');
      expect((inference as never as PublicPersonaInference).mbtiType).assertEqual('');
      expect((inference as never as PublicPersonaInference).mbtiConfidence).assertEqual(0);
    });

    it('requires inference arrays while allowing explicit empty arrays', 0, () => {
      const completeEmpty = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 0
      }));
      const missingExpertise = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 0
      }));

      expect(completeEmpty === null).assertFalse();
      expect(missingExpertise).assertEqual(null);
    });

    it('rejects unsupported inference and invalid persisted snapshots', 0, () => {
      expect(parsePublicPersonaInference('{"mbtiType":"not-mbti"}')).assertEqual(null);
      const invalidSnapshot: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: '# Ada',
        primaryAvatarUrl: 'https://example.com/not-owned.png',
        sources: [],
        generatedAt: '2026-08-06T00:00:00.000Z',
        mbtiHidden: false
      };
      expect(sanitizePublicPersonaSnapshot(invalidSnapshot)).assertEqual(null);

      const validSources: PublicPersonaSourceRef[] = [{
        platform: 'bilibili',
        profileUrl: 'https://space.bilibili.com/123456',
        avatarUrl: 'https://i0.hdslb.com/bfs/face/abc.jpg',
        sourceUrls: ['https://space.bilibili.com/123456'],
        fetchedAt: '2026-08-06T00:00:00.000Z'
      }];
      const validSnapshot: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: [
          '# Ada Lovelace',
          '',
          '> 喜欢把复杂问题讲清楚。',
          '',
          '## 身份与经历',
          '- 软件先驱',
          '',
          '## 专长',
          '- 算法',
          '',
          '## 兴趣与偏好',
          '- 数学',
          '',
          '## 沟通风格',
          '- 结构化',
          '',
          '## 近期关注',
          '- 公开技术写作',
          '',
          '## 性格推断',
          'ENTP · 68%',
          '',
          '## 已确认账号',
          '- [bilibili](https://space.bilibili.com/123456) · 123456'
        ].join('\n'),
        primaryAvatarUrl: 'https://i0.hdslb.com/bfs/face/abc.jpg',
        sources: validSources,
        generatedAt: '2026-08-06T00:00:00.000Z',
        mbtiHidden: false
      };
      expect(sanitizePublicPersonaSnapshot(validSnapshot) === null).assertFalse();
    });

    it('rejects invalid edited MBTI and filtered-empty source URLs', 0, () => {
      const baseline = validSnapshot();
      const invalidMbti: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown.replace('ENTP · 68%', 'ENFP · 101%'),
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: baseline.sources,
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };
      const invalidSourceUrls: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown,
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: [{
          platform: 'github', profileUrl: 'https://github.com/ada', avatarUrl: 'https://github.com/ada.png',
          sourceUrls: ['not-a-url'], fetchedAt: baseline.generatedAt
        }],
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };
      const invalidMbtiSection: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown + '\n\n## MBTI 推测\n- XXXX · 50%',
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: baseline.sources,
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };

      expect(sanitizePublicPersonaSnapshot(invalidMbti)).assertEqual(null);
      expect(sanitizePublicPersonaSnapshot(invalidSourceUrls)).assertEqual(null);
      expect(sanitizePublicPersonaSnapshot(invalidMbtiSection)).assertEqual(null);
    });

    it('hides MBTI content from the normal preview while retaining editable Markdown', 0, () => {
      const markdown = validSnapshot().personaMarkdown + '\n\n## MBTI 推测\n- ENTP · 68%';
      const hidden = publicPersonaPreviewMarkdown(markdown, true);
      const visible = publicPersonaPreviewMarkdown(markdown, false);

      expect(hidden.indexOf('## MBTI 推测')).assertEqual(-1);
      expect(hidden.indexOf('ENTP · 68%')).assertEqual(-1);
      expect(visible).assertContain('## MBTI 推测');
    });

    it('persists a snapshot and deletes only the snapshot data', 0, () => {
      const native = nativePreferences();
      const store = new PublicPersonaStore(native);
      expect(store.onboardingSeen()).assertFalse();
      store.markOnboardingSeen();
      store.save(validSnapshot());

      const reloaded = new PublicPersonaStore(native).load();
      expect(reloaded === null).assertFalse();
      expect(reloaded?.personaMarkdown).assertContain('Ada Lovelace');
      expect(reloaded?.sources.length).assertEqual(1);

      store.deleteSnapshot();
      expect(store.load()).assertEqual(null);
      expect(store.onboardingSeen()).assertTrue();
      expect(native.getSync(PUBLIC_PERSONA_SNAPSHOT_KEY, '')).assertEqual('');
      expect(native.getSync(PUBLIC_PERSONA_ONBOARDING_KEY, false)).assertTrue();
    });

    it('returns false when a snapshot save or delete cannot be verified', 0, () => {
      const native = new MemoryPreferences();
      const store = new PublicPersonaStore(native as Object as preferences.Preferences);
      native.failPut = true;
      expect(store.save(validSnapshot())).assertFalse();

      native.failPut = false;
      expect(store.save(validSnapshot())).assertTrue();
      native.failDelete = true;
      expect(store.deleteSnapshot()).assertFalse();
    });

    it('treats corrupt stored JSON as an empty persona', 0, () => {
      const native = nativePreferences();
      native.putSync(PUBLIC_PERSONA_SNAPSHOT_KEY, '{');
      expect(new PublicPersonaStore(native).load()).assertEqual(null);
    });

    it('parses the real GenericStructuredData envelope for seed and search reads', 0, async () => {
      const calls: string[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        calls.push(toolId + ':' + JSON.stringify(args));
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace',
            username: 'ada',
            avatarUrl: url.indexOf('x.com') >= 0 ? 'https://x.com/ada.png' : 'https://github.com/ada.png',
            canonicalUrl: url,
            linkedUrls: url.indexOf('x.com') >= 0 ? ['https://github.com/ada'] : []
          };
          const rawPreview = url.indexOf('x.com') >= 0 ?
            JSON.stringify({ answer: JSON.stringify(profile) }) : JSON.stringify(profile);
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', rawPreview)]);
        }
        const domains = JSON.stringify(args);
        if (domains.indexOf('x.com') >= 0) {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '', [
            { label: 'URL', value: 'https://x.com/ada' }
          ])]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (_progress): void => {});

      expect(candidates.length).assertEqual(2);
      expect(candidates.some((candidate): boolean => candidate.platform === 'x')).assertTrue();
      expect(calls.join('\n').indexOf('web.page.read:{"url":"https://x.com/ada"') >= 0).assertTrue();
    });

    it('falls back to Firecrawl markdown when scrape ignores the JSON answer request', 0, async () => {
      const markdown = [
        '![avatar](https://avatars.githubusercontent.com/u/56611624?v=4)',
        '# Yige Luo    XiaoLuoLYG',
        '',
        'Senior AI Engineer at Huawei 2012 Lab'
      ].join('\n');
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, _args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const envelope: MarkdownEnvelope = {
            success: true,
            data: { markdown: markdown }
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(envelope))]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/XiaoLuoLYG', (_progress): void => {});

      expect(candidates.length).assertEqual(1);
      expect(candidates[0].displayName).assertEqual('Yige Luo');
      expect(candidates[0].username).assertEqual('XiaoLuoLYG');
      expect(candidates[0].avatarUrl).assertEqual('https://avatars.githubusercontent.com/u/56611624?v=4');

      const snapshot = await client.buildSnapshot(candidates, modelSettings(), (_progress): void => {});
      expect(snapshot.sources.length).assertEqual(1);
      expect(snapshot.personaMarkdown).assertContain('Ada Lovelace');
    });

    it('parses raw Firecrawl markdown when the provider omits the JSON envelope', 0, async () => {
      const markdown = '![avatar](https://avatars.githubusercontent.com/u/56611624?v=4)\n# Yige Luo    XiaoLuoLYG\n\nSenior AI Engineer at Huawei 2012 Lab';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, _args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', markdown)]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/XiaoLuoLYG', (_progress): void => {});

      expect(candidates.length).assertEqual(1);
      expect(candidates[0].displayName).assertEqual('Yige Luo');
      expect(candidates[0].username).assertEqual('XiaoLuoLYG');
    });

    it('parses markdown carried in the provider answer field', 0, async () => {
      const markdown = '![avatar](https://avatars.githubusercontent.com/u/56611624?v=4)\n# Yige Luo    XiaoLuoLYG\n\nSenior AI Engineer at Huawei 2012 Lab';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, _args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify({ answer: markdown }))]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/XiaoLuoLYG', (_progress): void => {});

      expect(candidates.length).assertEqual(1);
      expect(candidates[0].username).assertEqual('XiaoLuoLYG');
    });

    it('asks the page provider to place identity JSON inside the answer envelope', 0, async () => {
      let seedQuestion = '';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          seedQuestion = (args as Record<string, Object | string>)['question'] as string;
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify({ answer: JSON.stringify(profile) }))]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (_progress): void => {});

      expect(candidates.length).assertEqual(1);
      expect(seedQuestion.indexOf('In the answer field') >= 0).assertTrue();
      expect(seedQuestion.indexOf('displayName') >= 0).assertTrue();
    });

    it('reads explicitly linked profiles before relying on search results and caps candidates at ten', 0, async () => {
      const linkedUrls: string[] = [];
      for (let index = 0; index < 12; index++) {
        linkedUrls.push('https://x.com/linked_' + index.toString());
      }
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          if (url === 'https://github.com/ada') {
            const seed: ProfileFixture = {
              displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
              canonicalUrl: url, linkedUrls: linkedUrls
            };
            return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(seed))]);
          }
          const linked: ProfileFixture = {
            displayName: 'Ada Lovelace', username: url.substring(url.lastIndexOf('/') + 1),
            avatarUrl: url + '.png', canonicalUrl: url, linkedUrls: ['https://github.com/ada']
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(linked))]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (_progress): void => {});

      expect(candidates.length).assertEqual(10);
      expect(candidates.some((candidate): boolean => candidate.profileUrl === 'https://x.com/linked_0')).assertTrue();
    });

    it('keeps an explicit LinkedIn seed through the public-search fallback when page read is unsupported', 0, async () => {
      let modelCalls = 0;
      let searchCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'error', 'Tool execution failed: site unsupported')], 'error');
        }
        if (toolId === 'web.research.search') {
          searchCalls++;
          if (searchCalls === 1) {
            return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
          }
          const result: DynamicGenericToolResult = {
            sourceTag: 'firecrawl', toolName: toolId, title: 'Yige Luo - Senior AI Engineer',
            status: 'success', summary: 'Senior AI Engineer at Huawei 2012 Riemann Lab',
            rows: [{ label: 'URL', value: 'https://www.linkedin.com/in/luoyige' }], rawPreview: ''
          };
          return dynamicDataResult(toolId, [result]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://www.linkedin.com/in/luoyige/', (_progress): void => {});

      expect(candidates.length).assertEqual(1);
      expect(candidates[0].platform).assertEqual('linkedin');
      expect(candidates[0].username).assertEqual('luoyige');
      expect(candidates[0].displayName).assertEqual('Yige Luo');
      const snapshot = await client.buildSnapshot(candidates, modelSettings(), (_progress): void => {});
      expect(snapshot.sources.length).assertEqual(1);
      expect(snapshot.sources[0].platform).assertEqual('linkedin');
      expect(modelCalls).assertEqual(1);
      expect(searchCalls).assertLarger(1);
    });

    it('searches case-insensitive identity aliases and accepts usernames containing an alias', 0, async () => {
      const queries: string[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: url.indexOf('x.com') >= 0 ? 'Different Public Name' : 'Yige Luo',
            username: url.indexOf('x.com') >= 0 ? 'abc_luoyige_abc' : 'XiaoLuoLYG',
            avatarUrl: url + '.png', canonicalUrl: url, linkedUrls: []
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        const query = (args as Record<string, Object | string>)['query'] as string;
        queries.push(query);
        if (JSON.stringify(args).indexOf('x.com') >= 0) {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '', [
            { label: 'URL', value: 'https://x.com/abc_luoyige_abc' }
          ])]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/XiaoLuoLYG', (_progress): void => {});

      expect(queries.some((query): boolean => query.indexOf('yigeluo') >= 0 && query.indexOf('luoyige') >= 0)).assertTrue();
      expect(candidates.some((candidate): boolean => candidate.username === 'abc_luoyige_abc')).assertTrue();
    });

    it('uses the same canonical name query for GitHub and LinkedIn seeds', 0, async () => {
      const queriesBySeed: string[][] = [[], []];
      const discover = async (seedUrl: string, bucket: string[]): Promise<void> => {
        const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
          if (toolId === 'web.page.read') {
            const url = (args as Record<string, Object | string>)['url'] as string;
            const profile: ProfileFixture = {
              displayName: 'Yige Luo',
              username: url.indexOf('linkedin.com') >= 0 ? 'luoyige' : 'XiaoLuoLYG',
              avatarUrl: url + '.png', canonicalUrl: url, linkedUrls: []
            };
            return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
          }
          const query = (args as Record<string, Object | string>)['query'] as string;
          if (bucket.length === 0) {
            bucket.push(query);
          }
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
        };
        const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
          (): string => '2026-08-06T00:00:00.000Z');
        await client.discover(seedUrl, (_progress): void => {});
      };

      await discover('https://github.com/XiaoLuoLYG', queriesBySeed[0]);
      await discover('https://www.linkedin.com/in/luoyige', queriesBySeed[1]);

      expect(queriesBySeed[0][0]).assertEqual(queriesBySeed[1][0]);
      expect(queriesBySeed[0][0].indexOf('yigeluo') >= 0).assertTrue();
      expect(queriesBySeed[0][0].indexOf('luoyige') >= 0).assertTrue();
    });

    it('aggregates mixed nested provider states before reading successful URLs', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: url.indexOf('x.com') >= 0 ? 'https://x.com/ada.png' : 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: url.indexOf('x.com') >= 0 ? ['https://github.com/ada'] : []
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        const query = JSON.stringify(args);
        if (query.indexOf('x.com') >= 0) {
          return dynamicDataResult(toolId, [
            dynamicResult(toolId, 'needs_auth'),
            dynamicResult(toolId, 'success', '', [{ label: 'URL', value: 'https://x.com/ada' }])
          ]);
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'empty')], 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      expect(candidates.length).assertEqual(2);
      expect(candidates.some((candidate): boolean => candidate.platform === 'x')).assertTrue();
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'partial')).assertTrue();
    });

    it('does not upgrade a provider error to success from a nested success result', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        const nestedData: GenericStructuredData = {
          results: [dynamicResult(toolId, 'success', '', [{ label: 'URL', value: 'https://x.com/ada' }])]
        };
        return {
          toolId: toolId,
          outputSchema: 'genericToolResults',
          status: 'error',
          sources: [],
          data: nestedData as Object,
          warnings: [],
          error: { code: 'PROVIDER_ERROR', message: 'provider failed after a nested result' }
        };
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      expect(candidates.length).assertEqual(1);
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'error')).assertTrue();
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'success')).assertFalse();
    });

    it('keeps a top error when nested success has no error object', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dataResult(toolId, profile as Object);
        }
        const nestedData: GenericStructuredData = {
          results: [dynamicResult(toolId, 'success', '', [{ label: 'URL', value: 'https://x.com/ada' }])]
        };
        return {
          toolId: toolId,
          outputSchema: 'genericToolResults',
          status: 'error',
          sources: [],
          data: nestedData as Object,
          warnings: []
        };
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      expect(candidates.length).assertEqual(1);
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'error')).assertTrue();
    });

    it('keeps a top error ahead of mixed nested success and needs_auth states', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        const nestedData: GenericStructuredData = {
          results: [
            dynamicResult(toolId, 'success', '', [{ label: 'URL', value: 'https://x.com/ada' }]),
            dynamicResult(toolId, 'needs_auth')
          ]
        };
        return {
          toolId: toolId,
          outputSchema: 'genericToolResults',
          status: 'error',
          sources: [],
          data: nestedData as Object,
          warnings: [],
          error: { code: 'TOP_ERROR', message: 'top provider failure' }
        };
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      expect(candidates.length).assertEqual(1);
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'error')).assertTrue();
      expect(progress.some((value): boolean => value.platform === 'x' && value.state === 'partial')).assertFalse();
    });

    it('does not upgrade top partial or empty from nested success', 0, async () => {
      const run = async (topStatus: DataResultStatus): Promise<PublicPersonaProgress[]> => {
        const progress: PublicPersonaProgress[] = [];
        const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
          if (toolId === 'web.page.read') {
            const url = (args as Record<string, Object | string>)['url'] as string;
            const profile: ProfileFixture = {
              displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
              canonicalUrl: url, linkedUrls: []
            };
            return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
          }
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '', [
            { label: 'URL', value: 'https://x.com/ada' }
          ])], topStatus);
        };
        const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
          (): string => '2026-08-06T00:00:00.000Z');
        await client.discover('https://github.com/ada', (value): void => { progress.push(value); });
        return progress;
      };

      const partial = await run('partial');
      const empty = await run('empty');
      expect(partial.some((value): boolean => value.platform === 'x' && value.state === 'partial')).assertTrue();
      expect(partial.some((value): boolean => value.platform === 'x' && value.state === 'success')).assertFalse();
      expect(empty.some((value): boolean => value.platform === 'x' && value.state === 'empty')).assertTrue();
      expect(empty.some((value): boolean => value.platform === 'x' && value.state === 'success')).assertFalse();
    });

    it('uses the confirmed candidate identity when full profile content omits identity fields', 0, async () => {
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        const url = (args as Record<string, Object | string>)['url'] as string;
        const content: EvidenceFixture = { bio: '公开简介', posts: [], sourceUrls: [url] };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(content))]);
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const snapshot = await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(snapshot.sources.length).assertEqual(1);
      expect(snapshot.sources[0].profileUrl).assertEqual(selected.profileUrl);
      expect(modelCalls).assertEqual(1);
    });

    it('maps Firecrawl full-read publicBio and pinned/latest posts into evidence', 0, async () => {
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        const url = (args as Record<string, Object | string>)['url'] as string;
        const answer: FirecrawlFullReadFixture = {
          publicBio: 'Yige Luo is a public AI engineer profile with published work.',
          pinnedPosts: [{ url: url + '/pinned', title: 'Pinned', text: 'Pinned public post', publishedAt: '', pinned: true }],
          latestPosts: [{ url: url + '/latest', title: 'Latest', text: 'Latest public post', publishedAt: '', pinned: false }]
        };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify({ answer: JSON.stringify(answer) }))]);
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:xiaoluolyg', platform: 'github', profileUrl: 'https://github.com/XiaoLuoLYG', displayName: 'Yige Luo',
        username: 'XiaoLuoLYG', avatarUrl: 'https://avatars.githubusercontent.com/u/56611624?v=4', exists: true,
        ownershipConfidence: 1, ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/XiaoLuoLYG'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const snapshot = await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(snapshot.sources.length).assertEqual(1);
      expect(snapshot.sources[0].profileUrl).assertEqual(selected.profileUrl);
      expect(modelCalls).assertEqual(1);
    });

    it('unwraps fenced JSON returned inside the Firecrawl answer envelope', 0, async () => {
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        const url = (args as Record<string, Object | string>)['url'] as string;
        const answer: FirecrawlFullReadFixture = {
          publicBio: 'A public profile with a fenced JSON response.',
          pinnedPosts: [],
          latestPosts: [{ url: url + '/latest', title: 'Latest', text: 'Public post', publishedAt: '', pinned: false }]
        };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify({
          answer: '```json\\n' + JSON.stringify(answer) + '\\n```'
        }))]);
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:fenced', platform: 'github', profileUrl: 'https://github.com/fenced', displayName: 'Fenced Profile',
        username: 'fenced', avatarUrl: 'https://github.com/fenced.png', exists: true,
        ownershipConfidence: 1, ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/fenced'
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const snapshot = await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(snapshot.sources.length).assertEqual(1);
    });

    it('keeps top PROVIDER_ERROR ahead of nested needs_auth and skips the model', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'x.post.search') {
          const needsAuthData: GenericStructuredData = {
            results: [dynamicResult(toolId, 'needs_auth', '')]
          };
          return {
            toolId: toolId,
            outputSchema: 'genericToolResults',
            status: 'error',
            sources: [],
            data: needsAuthData as Object,
            warnings: [],
            error: { code: 'PROVIDER_ERROR', message: 'provider returned a terminal result' }
          };
        }
        const url = (args as Record<string, Object | string>)['url'] as string;
        const payload: ProfileFixture = {
          displayName: 'Ada Lovelace', username: 'ada_x', avatarUrl: 'https://x.com/ada.png',
          canonicalUrl: url, linkedUrls: [], bio: '公开简介', posts: [], sourceUrls: [url]
        };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify({ answer: JSON.stringify(payload) }))]);
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'x:ada_x', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace',
        username: 'ada_x', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://x.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      let failed = false;
      try {
        await client.buildSnapshot([selected], modelSettings(), (value): void => { progress.push(value); });
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(modelCalls).assertEqual(0);
      expect(progress.some((value): boolean => value.state === 'error')).assertTrue();
      expect(progress.some((value): boolean => value.state === 'needs_auth')).assertFalse();
    });

    it('discovers only read-confirmed candidates and terminates all eleven probes', 0, async () => {
      const calls: string[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        calls.push(toolId + ':' + JSON.stringify(args));
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          if (url.indexOf('github.com/ada') >= 0) {
            const profile: ProfileFixture = {
              displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
              canonicalUrl: 'https://github.com/ada', linkedUrls: []
            };
            return dataResult(toolId, profile as Object);
          }
          if (url.indexOf('x.com/ada') >= 0) {
            const profile: ProfileFixture = {
              displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://x.com/ada.png',
              canonicalUrl: 'https://x.com/ada', linkedUrls: ['https://github.com/ada']
            };
            return dataResult(toolId, profile as Object);
          }
          return dataResult(toolId, new Object());
        }
        const search: SearchFixture = {
          results: [{ url: 'https://x.com/ada' }, { url: 'https://example.com/not-confirmed' }]
        };
        return dataResult(toolId, search as Object);
      };
      const modelCaller: PublicPersonaModelCaller = async (
        _settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[], _systemPrompt?: string
      ): Promise<DirectModelCallResult> => modelInferenceResult();
      const progress: PublicPersonaProgress[] = [];
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });
      const terminalPlatforms: string[] = progress.filter((value): boolean => value.state !== 'running').map((value): string => value.platform);

      expect(terminalPlatforms.length).assertEqual(11);
      expect(candidates.length).assertEqual(2);
      expect(candidates[0].avatarUrl).assertContain('https://');
      expect(candidates[1].username).assertEqual('ada');
      expect(calls.join('\n').indexOf('example.com/not-confirmed')).assertEqual(-1);
    });

    it('keeps discovery probes serial to avoid provider burst limits', 0, async () => {
      let activeSearches = 0;
      let maxActiveSearches = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, _args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: 'https://github.com/ada', linkedUrls: []
          };
          return dataResult(toolId, profile as Object);
        }
        activeSearches++;
        maxActiveSearches = Math.max(maxActiveSearches, activeSearches);
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 2));
        activeSearches--;
        const search: SearchFixture = { results: [] };
        return dataResult(toolId, search as Object, 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      await client.discover('https://github.com/ada', (_progress): void => {});

      expect(maxActiveSearches).assertEqual(1);
    });

    it('retries a provider 429 before declaring a platform unavailable', 0, async () => {
      let searchCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dataResult(toolId, profile as Object);
        }
        searchCalls++;
        if (searchCalls === 1) {
          const providerError: DataResultError = {
            code: 'PROVIDER_ERROR', message: 'Request failed with status code 429'
          };
          return {
            toolId: toolId, outputSchema: 'object', status: 'error', sources: [], data: new Object(), warnings: [],
            error: providerError
          };
        }
        const search: SearchFixture = { results: [] };
        return dataResult(toolId, search as Object, 'empty');
      };
      const progress: PublicPersonaProgress[] = [];
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z', 25);
      await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      expect(searchCalls).assertLarger(11);
      expect(progress.some((value): boolean => value.state === 'rate_limited')).assertFalse();
    });

    it('emits a timeout terminal when one platform probe never settles', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
            canonicalUrl: url, linkedUrls: []
          };
          return dataResult(toolId, profile as Object);
        }
        if (JSON.stringify(args).indexOf('x.com') >= 0) {
          return new Promise<DataResult>((_resolve: (value: DataResult) => void): void => {});
        }
        return dataResult(toolId, new Object(), 'empty');
      };
      const startedAt: number = Date.now();
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z', 25);
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });
      expect(Date.now() - startedAt).assertLess(1000);
      const terminals = progress.filter((value): boolean => value.state !== 'running');

      expect(candidates.length).assertEqual(1);
      expect(terminals.length).assertEqual(11);
      expect(terminals.some((value): boolean => value.platform === 'x' && value.state === 'timeout')).assertTrue();
      expect(terminals[terminals.length - 1].completed).assertEqual(11);
    });

    it('reads only selected accounts, caps posts, and keeps the excluded account out of model input', 0, async () => {
      const calls: string[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        calls.push(toolId + ':' + JSON.stringify(args));
        const url = (args as Record<string, Object | string>)['url'] as string;
        const posts: PostFixture[] = [];
        for (let index = 0; index < 35; index++) {
          posts.push({ url: 'https://github.com/ada/posts/' + index.toString(), title: 'Post', text: '公开内容', publishedAt: '', pinned: index === 0 });
        }
        if (toolId === 'x.post.search') {
          const postResponse: PostsFixture = { posts: posts };
          return dataResult(toolId, postResponse as Object);
        }
        const profile: ProfileFixture = {
          displayName: url.indexOf('x.com') >= 0 ? 'Ada Lovelace' : 'Ada Lovelace',
          username: url.indexOf('x.com') >= 0 ? 'ada_x' : 'ada',
          avatarUrl: url.indexOf('x.com') >= 0 ? 'https://x.com/ada.png' : 'https://github.com/ada.png',
          canonicalUrl: url,
          linkedUrls: [],
          bio: '公开简介', posts: posts, sourceUrls: [url]
        };
        return dataResult(toolId, profile as Object);
      };
      let modelPrompt = '';
      const modelCaller: PublicPersonaModelCaller = async (
        _settings: LocalModelSettings, prompt: string, _history: A2uiMessage[], _systemPrompt?: string
      ): Promise<DirectModelCallResult> => {
        modelPrompt = prompt;
        return modelInferenceResult();
      };
      const selected = [
        { id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1, ownershipBand: 'high', selected: true, providerState: 'success', fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada' },
        { id: 'x:ada_x', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace', username: 'ada_x', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 0.8, ownershipBand: 'high', selected: true, providerState: 'success', fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://x.com/ada' }
      ] as PublicPersonaCandidate[];
      const excluded = { id: 'reddit:other', platform: 'reddit', profileUrl: 'https://www.reddit.com/user/other', displayName: 'Other', username: 'other', avatarUrl: 'https://reddit.com/other.png', exists: true, ownershipConfidence: 0.5, ownershipBand: 'possible', selected: false, providerState: 'success', fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://www.reddit.com/user/other' } as PublicPersonaCandidate;
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const snapshot = await client.buildSnapshot(selected.concat([excluded]), modelSettings(), (_progress): void => {});

      expect(snapshot.sources.length).assertEqual(2);
      expect(snapshot.primaryAvatarUrl).assertEqual('https://github.com/ada.png');
      expect(calls.join('\n').indexOf('reddit')).assertEqual(-1);
      expect(modelPrompt.indexOf('other')).assertEqual(-1);
      expect(snapshot.personaMarkdown).assertContain('## 已确认账号');
    });

    it('deduplicates post evidence by URL before sending it to the model', 0, async () => {
      let modelPrompt = '';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        const url = (args as Record<string, Object | string>)['url'] as string;
        const posts: PostFixture[] = [
          { url: 'https://github.com/ada/posts/1', title: '一', text: '公开内容', publishedAt: '', pinned: false },
          { url: 'https://github.com/ada/posts/1', title: '一重复', text: '公开内容', publishedAt: '', pinned: false },
          { url: 'https://github.com/ada/posts/2', title: '二', text: '公开内容', publishedAt: '', pinned: false }
        ];
        const profile: ProfileFixture = {
          displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
          canonicalUrl: url, linkedUrls: [], bio: '公开简介', posts: posts, sourceUrls: [url]
        };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
      };
      const modelCaller: PublicPersonaModelCaller = async (
        _settings: LocalModelSettings, prompt: string, _history: A2uiMessage[], _systemPrompt?: string
      ): Promise<DirectModelCallResult> => {
        modelPrompt = prompt;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      const first = modelPrompt.indexOf('https://github.com/ada/posts/1');
      expect(first >= 0).assertTrue();
      expect(modelPrompt.indexOf('https://github.com/ada/posts/1', first + 1)).assertEqual(-1);
    });

    it('keeps full profile reads compact instead of requesting thirty posts', 0, async () => {
      let question = '';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          question = prompt + JSON.stringify(args);
          const profile: EvidenceFixture = {
            bio: '公开简介', posts: [], sourceUrls: ['https://github.com/ada']
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        return dataResult(toolId, new Object(), 'empty');
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(question.indexOf('at most 10 posts') >= 0).assertTrue();
      expect(question.indexOf('at most 30 posts')).assertEqual(-1);
    });

    it('does not call the model for identity-only full profile content', 0, async () => {
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string): Promise<DataResult> => {
        const content: EvidenceFixture = { bio: '', posts: [], sourceUrls: ['https://github.com/ada'] };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(content))]);
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      let failed = false;
      try {
        await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(modelCalls).assertEqual(0);
    });

    it('bounds the X post call with the injected probe timeout', 0, async () => {
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'x.post.search') {
          return new Promise<DataResult>((_resolve: (value: DataResult) => void): void => {});
        }
        const url = (args as Record<string, Object | string>)['url'] as string;
        const profile: EvidenceFixture = { bio: '公开简介', posts: [], sourceUrls: [url] };
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
      };
      const selected: PublicPersonaCandidate = {
        id: 'x:ada', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://x.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z', 25);
      const build = client.buildSnapshot([selected], modelSettings(), (_progress): void => {});
      const finished = await Promise.race<boolean>([
        build.then((): boolean => true).catch((): boolean => true),
        new Promise<boolean>((resolve: (value: boolean) => void): void => {
          setTimeout((): void => { resolve(false); }, 200);
        })
      ]);

      expect(finished).assertTrue();
    });

    it('deduplicates search URLs and reads at most the first ten rows', 0, async () => {
      const pageReads: string[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          pageReads.push(url);
          const profile: ProfileFixture = {
            displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://x.com/ada.png',
            canonicalUrl: url, linkedUrls: ['https://github.com/ada']
          };
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', JSON.stringify(profile))]);
        }
        if (JSON.stringify(args).indexOf('x.com') >= 0) {
          return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '', [
            { label: 'URL', value: 'https://x.com/ada' },
            { label: 'URL', value: 'https://x.com/ada' },
            { label: 'URL', value: 'https://x.com/other' },
            { label: 'URL', value: 'https://x.com/third' },
            { label: 'URL', value: 'https://x.com/fourth' },
            { label: 'URL', value: 'https://x.com/fifth' },
            { label: 'URL', value: 'https://x.com/sixth' },
            { label: 'URL', value: 'https://x.com/seventh' },
            { label: 'URL', value: 'https://x.com/eighth' },
            { label: 'URL', value: 'https://x.com/ninth' },
            { label: 'URL', value: 'https://x.com/tenth' },
            { label: 'URL', value: 'https://x.com/eleventh' }
          ])]);
        }
        return dataResult(toolId, new Object(), 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      await client.discover('https://github.com/ada', (_progress): void => {});

      expect(pageReads.filter((url: string): boolean => url === 'https://x.com/ada').length).assertEqual(1);
      expect(pageReads.filter((url: string): boolean => url === 'https://x.com/third').length).assertEqual(1);
      expect(pageReads.filter((url: string): boolean => url === 'https://x.com/tenth').length).assertEqual(1);
      expect(pageReads.indexOf('https://x.com/eleventh')).assertEqual(-1);
    });

    it('uses the strict X post query and page size', 0, async () => {
      let xArgs = '';
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'x.post.search') {
          xArgs = JSON.stringify(args);
          const posts: PostsFixture = { posts: [] };
          return dataResult(toolId, posts as Object);
        }
        const url = (args as Record<string, Object | string>)['url'] as string;
        const profile: ProfileFixture = {
          displayName: 'Ada Lovelace', username: 'ada_x', avatarUrl: 'https://x.com/ada.png',
          canonicalUrl: url, linkedUrls: [], bio: '公开简介', posts: [], sourceUrls: [url]
        };
        return dataResult(toolId, profile as Object);
      };
      const selected: PublicPersonaCandidate = {
        id: 'x:ada_x', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace',
        username: 'ada_x', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://x.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(xArgs).assertContain('"query":"from:ada_x"');
      expect(xArgs).assertContain('"pageSize":30');
    });

    it('keeps a public X profile when the post provider needs auth', 0, async () => {
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'x.post.search') {
          return {
            toolId: toolId, outputSchema: 'object', status: 'error', sources: [], data: new Object(), warnings: [],
            error: { code: 'AUTH_REQUIRED', message: 'X provider login required' }
          };
        }
        const url = (args as Record<string, Object | string>)['url'] as string;
        const profile: ProfileFixture = {
          displayName: 'Ada Lovelace', username: 'ada_x', avatarUrl: 'https://x.com/ada.png',
          canonicalUrl: url, linkedUrls: [], bio: '公开简介', posts: [], sourceUrls: [url]
        };
        return dataResult(toolId, profile as Object);
      };
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'x:ada_x', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace',
        username: 'ada_x', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://x.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const snapshot = await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});

      expect(snapshot.sources.length).assertEqual(1);
      expect(modelCalls).assertEqual(1);
    });

    it('does not call the model when all confirmed evidence is unavailable', 0, async () => {
      let modelCalls = 0;
      const toolCaller: PublicPersonaToolCaller = async (toolId: string): Promise<DataResult> => ({
        toolId: toolId, outputSchema: 'object', status: 'error', sources: [], data: new Object(), warnings: [],
        error: { code: 'AUTH_REQUIRED', message: 'login required' }
      });
      const modelCaller: PublicPersonaModelCaller = async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      };
      const selected: PublicPersonaCandidate = {
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace',
        username: 'ada', avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 1,
        ownershipBand: 'high', selected: true, providerState: 'success',
        fetchedAt: '2026-08-06T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      let failed = false;
      try {
        await client.buildSnapshot([selected], modelSettings(), (_progress): void => {});
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(modelCalls).assertEqual(0);
    });

    it('keeps a LinkedIn login wall terminal while completing other probes', 0, async () => {
      const progress: PublicPersonaProgress[] = [];
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        if (toolId === 'web.page.read') {
          const url = (args as Record<string, Object | string>)['url'] as string;
          if (url.indexOf('github.com/ada') >= 0 || url.indexOf('x.com/ada') >= 0) {
            const profile: ProfileFixture = {
              displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
              canonicalUrl: url, linkedUrls: ['https://github.com/ada']
            };
            return dataResult(toolId, profile as Object);
          }
          return dataResult(toolId, new Object(), 'empty');
        }
        const query = JSON.stringify(args);
        if (query.indexOf('linkedin.com') >= 0) {
          const loginWall: DataResult = {
            toolId: toolId, outputSchema: 'object', status: 'error', sources: [], data: new Object(), warnings: [],
            error: { code: 'AUTH_REQUIRED', message: 'login wall' }
          };
          return loginWall;
        }
        const search: SearchFixture = { results: [{ url: 'https://x.com/ada' }] };
        return dataResult(toolId, search as Object);
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-06T00:00:00.000Z');
      const candidates = await client.discover('https://github.com/ada', (value): void => { progress.push(value); });

      const linkedInTerminal = progress.filter((value): boolean => value.platform === 'linkedin' && value.state !== 'running');
      expect(linkedInTerminal.length).assertEqual(1);
      expect(linkedInTerminal[0].state).assertEqual('needs_auth');
      expect(candidates.some((candidate): boolean => candidate.platform === 'x')).assertTrue();
    });

    it('reinfers MBTI through the model and preserves the caller boundary', 0, async () => {
      let modelCalls = 0;
      const modelCaller: PublicPersonaModelCaller = async (
        _settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[], _systemPrompt?: string
      ): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult('INFJ');
      };
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        const profileUrl = (args as Record<string, Object | string>)['url'] as string;
        const profile: ProfileFixture = { displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png', canonicalUrl: profileUrl, linkedUrls: [], bio: '公开简介', posts: [], sourceUrls: [profileUrl] };
        return dataResult(toolId, profile as Object);
      };
      const client = new PublicPersonaClient(toolCaller, modelCaller, (): string => '2026-08-06T00:00:00.000Z');
      const result = await client.reinferMbti(validSnapshot(), modelSettings());

      expect(result.mbtiType).assertEqual('INFJ');
      expect(result.mbtiConfidence).assertEqual(68);
      expect(modelCalls).assertEqual(1);
    });
  });
}
