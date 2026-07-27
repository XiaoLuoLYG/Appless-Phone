import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceStore } from '@loop/agent-core';
import { AggregateSearchResult } from '@loop/agent-core';
import { aggregateSearchA2ui, aggregateStructuredDataResult, parseA2uiJsonl, resolveData } from '@loop/agent-core';

function sampleResult(): AggregateSearchResult {
  return {
    query: 'openai codex',
    videos: [{
      id: 'youtube-1',
      source: 'youtube',
      provider: 'YouTube',
      title: 'Codex demo',
      summary: 'Official video',
      url: 'https://www.youtube.com/watch?v=abc123',
      thumbnail: 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
      publishedAt: '2026-07-09T01:00:00Z',
      duration: '',
      status: 'success',
      rows: [{ label: 'Video ID', value: 'abc123' }]
    }],
    posts: [{
      id: 'hn-1',
      source: 'hackernews',
      provider: 'Hacker News',
      title: 'OpenAI Codex discussion',
      author: 'pg',
      handle: 'pg',
      text: 'Discussion row',
      url: 'https://news.ycombinator.com/item?id=123',
      publishedAt: '2026-07-09T01:00:00Z',
      score: '128',
      commentCount: '42',
      status: 'success',
      rows: [{ label: 'points', value: '128' }]
    }],
    sourceStatuses: [
      { source: 'youtube', label: 'YouTube', status: 'success', message: '1 result', count: 1 },
      { source: 'zhihu', label: '知乎', status: 'needs_auth', message: '未配置 ZHIHU_API_KEY（知乎 Access Secret）。', count: 0 }
    ],
    summary: '1 video, 1 discussion'
  };
}

function applyJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    expect(store.apply(envelope).error).assertEqual('');
  });
  return store;
}

export default function aggregateSearchA2uiTest() {
  describe('aggregateSearchA2ui', () => {
    it('emits aggregate search surface and data model', 0, () => {
      const store = applyJsonl(aggregateSearchA2ui('surface_aggregate', sampleResult()));
      const surface = store.getSurface();
      const result = resolveData(surface, '/aggregateSearch') as AggregateSearchResult;

      expect(surface.intent).assertEqual('aggregate_search');
      expect(surface.title).assertEqual('聚合搜索');
      expect(surface.components[1].dataPath).assertEqual('/aggregateSearch');
      expect(result.query).assertEqual('openai codex');
      expect(result.posts[0].title).assertEqual('OpenAI Codex discussion');
      expect(result.sourceStatuses[1].message.indexOf('ZHIHU_API_KEY')).assertLarger(-1);
    });

    it('uses real rows plus failed sources for partial and never partial without data', 0, () => {
      const partial = aggregateStructuredDataResult(sampleResult());
      const noDataFailure = sampleResult();
      noDataFailure.videos = [];
      noDataFailure.posts = [];
      noDataFailure.sourceStatuses = [
        { source: 'youtube', label: 'YouTube', status: 'error', message: 'timeout', count: 0 },
        { source: 'zhihu', label: '知乎', status: 'needs_auth', message: 'auth required', count: 0 }
      ];
      const failed = aggregateStructuredDataResult(noDataFailure);

      expect(partial.status).assertEqual('partial');
      expect(partial.sources.length).assertEqual(2);
      expect(failed.status).assertEqual('error');
      expect(failed.error?.code).assertEqual('AGGREGATE_PROVIDERS_FAILED');
    });

    it('uses empty only when every requested aggregate source completed without data', 0, () => {
      const emptyResult = sampleResult();
      emptyResult.videos = [];
      emptyResult.posts = [];
      emptyResult.sourceStatuses = [
        { source: 'youtube', label: 'YouTube', status: 'empty', message: '0 results', count: 0 },
        { source: 'bilibili', label: 'B 站', status: 'empty', message: '0 results', count: 0 }
      ];
      const empty = aggregateStructuredDataResult(emptyResult);

      expect(empty.status).assertEqual('empty');
      expect(empty.error === undefined).assertTrue();
      expect(JSON.stringify(empty.data).indexOf('updateComponents')).assertEqual(-1);
    });
  });
}
