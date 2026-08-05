import { describe, it, expect } from '@ohos/hypium';
import {
  AggregateSearchPost,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  WaterfallCandidate,
  aggregateSearchQueryFromArgs,
  aggregateMediaCandidates,
  aggregateSearchResultFromParts,
  aggregateSearchSourcesFromArgs,
  aggregateXPostSearchPrompt,
  hackerNewsPostsFromComposioResult,
  normalizeAggregateSearchStatus,
  redditPostsFromComposioResult,
  unsupportedSourceStatus,
  xPostsFromComposioResult,
  zhihuPostsFromSearchPayload,
  zhihuSearchUrl,
  rankWaterfallCandidates
} from '@loop/agent-core';

interface QueryArgsFixture {
  query: string;
  sources?: string[];
  limit?: number;
}

function video(id: string, url: string): AggregateSearchVideo {
  return {
    id: id,
    source: 'youtube',
    provider: 'YouTube',
    title: 'Video ' + id,
    summary: '',
    url: url,
    thumbnail: '',
    publishedAt: '',
    duration: '',
    status: 'success',
    rows: []
  };
}

function post(id: string, url: string): AggregateSearchPost {
  return {
    id: id,
    source: 'hackernews',
    provider: 'HN',
    title: 'Post ' + id,
    author: '',
    handle: '',
    text: '',
    url: url,
    publishedAt: '',
    score: '',
    commentCount: '',
    status: 'success',
    rows: []
  };
}

function waterfallCandidate(
  id: string,
  source: string,
  title: string,
  summary: string,
  url: string,
  publishedAt: string,
  originalIndex: number
): WaterfallCandidate {
  return {
    id: id,
    source: source,
    mediaType: 'post',
    title: title,
    summary: summary,
    url: url,
    coverUrl: '',
    publishedAt: publishedAt,
    originalIndex: originalIndex
  };
}

const WATERFALL_NOW_MS: number = Date.parse('2026-08-06T12:00:00.000Z');

export default function aggregateSearchClientTest() {
  describe('aggregateSearchClient', () => {
    it('extracts query and source defaults', 0, () => {
      const args: QueryArgsFixture = { query: 'openai codex', sources: ['youtube', 'x'], limit: 3 };

      expect(aggregateSearchQueryFromArgs('我想看看相关新闻', args)).assertEqual('openai codex');
      expect(aggregateSearchQueryFromArgs('我想看看有关 openai codex 的相关新闻和讨论', null)).assertEqual('openai codex');
      expect(aggregateSearchQueryFromArgs('openai codex 新闻讨论', null)).assertEqual('openai codex');
      expect(aggregateSearchSourcesFromArgs(args).join(',')).assertEqual('youtube,x');
      expect(aggregateSearchSourcesFromArgs(null).join(',')).assertEqual('youtube,bilibili,x,hackernews,reddit,zhihu');
    });

    it('deduplicates URLs and keeps source issue statuses', 0, () => {
      const status: AggregateSearchSourceStatus = unsupportedSourceStatus('zhihu', '未配置 ZHIHU_API_KEY（知乎 Access Secret）。');
      const result = aggregateSearchResultFromParts(
        'openai codex',
        [video('v1', 'https://example.test/a'), video('v2', 'https://example.test/a')],
        [post('p1', 'https://news.ycombinator.com/item?id=123'), post('p2', 'https://news.ycombinator.com/item?id=123')],
        [status]
      );

      expect(result.videos.length).assertEqual(1);
      expect(result.posts.length).assertEqual(1);
      expect(result.sourceStatuses[0].source).assertEqual('zhihu');
      expect(result.sourceStatuses[0].status).assertEqual('unsupported');
      expect(result.summary).assertEqual('1 video, 1 discussion');
    });

    it('normalizes source connection statuses truthfully', 0, () => {
      expect(normalizeAggregateSearchStatus('empty', 0)).assertEqual('empty');
      expect(normalizeAggregateSearchStatus('connected', 0)).assertEqual('empty');
      expect(normalizeAggregateSearchStatus('needs_auth', 0)).assertEqual('needs_auth');
      expect(normalizeAggregateSearchStatus('auth_required', 0)).assertEqual('needs_auth');
      expect(normalizeAggregateSearchStatus('limited', 0)).assertEqual('error');
      expect(normalizeAggregateSearchStatus('disabled', 0)).assertEqual('error');
    });

    it('builds X keyword prompts without converting OpenAI topics into handles', 0, () => {
      expect(aggregateXPostSearchPrompt('openai codex')).assertEqual('X 公开 post 搜索关键词: openai codex');
    });

    it('maps official Zhihu search payloads into post cards', 0, () => {
      const posts = zhihuPostsFromSearchPayload('{"code":0,"data":{"Items":[{"Title":"OpenAI Codex 有哪些讨论","ContentText":"<em>Codex</em> 的开发者讨论摘要","Url":"https://www.zhihu.com/question/1","AuthorName":"知乎用户","AuthorAvatar":"https://pic.example.com/avatar.jpg","VoteUpCount":12,"CommentCount":3,"EditTime":1780000000}]}}');

      expect(zhihuSearchUrl('openai codex').indexOf('/api/v1/content/zhihu_search')).assertLarger(-1);
      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('zhihu');
      expect(posts[0].title).assertEqual('OpenAI Codex 有哪些讨论');
      expect(posts[0].author).assertEqual('知乎用户');
      expect(posts[0].text.indexOf('<em>')).assertEqual(-1);
      expect(posts[0].score).assertEqual('12');
      expect(posts[0].commentCount).assertEqual('3');
      expect(JSON.stringify(posts[0].rows).indexOf('avatar.jpg')).assertLarger(-1);
    });

    it('turns dynamic text rows into readable post cards with images', 0, () => {
      const posts = hackerNewsPostsFromComposioResult({
        sourceTag: 'MCP',
        toolName: 'search_content',
        title: 'MCP 工具结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [
          { label: 'statuses 1', value: '{"text":"<p>OpenAI Codex 新讨论</p>","user":{"screen_name":"AI Daily"},"url":"https://news.ycombinator.com/item?id=1","thumbnail_pic":"https://img.example.com/codex.jpg","comments_count":4}' }
        ],
        rawPreview: 'raw'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('AI Daily');
      expect(posts[0].author).assertEqual('AI Daily');
      expect(posts[0].text.indexOf('<p>')).assertEqual(-1);
      expect(posts[0].text.indexOf('OpenAI Codex 新讨论')).assertLarger(-1);
      expect(posts[0].commentCount).assertEqual('4');
      expect(JSON.stringify(posts[0].rows).indexOf('codex.jpg')).assertLarger(-1);
    });

    it('maps Reddit Composio payloads from raw JSON into post cards', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"results":[{"kind":"Listing","data":{"children":[{"kind":"t3","data":{"title":"OpenAI Codex on Reddit","author":"dev_user","selftext":"Long Reddit discussion","permalink":"/r/OpenAI/comments/1/codex","ups":88,"num_comments":12,"thumbnail":"https://img.example.com/reddit.png","created_utc":1780000000}}]}}]}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('reddit');
      expect(posts[0].provider).assertEqual('Reddit');
      expect(posts[0].title).assertEqual('OpenAI Codex on Reddit');
      expect(posts[0].author).assertEqual('dev_user');
      expect(posts[0].url).assertEqual('https://www.reddit.com/r/OpenAI/comments/1/codex');
      expect(posts[0].score).assertEqual('88');
      expect(posts[0].commentCount).assertEqual('12');
      expect(posts[0].text).assertEqual('Long Reddit discussion');
      expect(JSON.stringify(posts[0].rows).indexOf('reddit.png')).assertLarger(-1);
    });

    it('maps Reddit Composio preview wrappers into post cards', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [
          { label: 'source', value: 'Composio' },
          { label: 'truncated', value: 'true' },
          { label: 'preview', value: '{"data":{"children":[{"data":{"title":"Readable Reddit post","author":"coder","selftext":"Readable body","permalink":"/r/OpenAI/comments/2/codex","ups":9,"num_comments":2}}]}}' }
        ],
        rawPreview: '{"source":"Composio","truncated":true,"preview":"{\\"data\\":{\\"children\\":[{\\"data\\":{\\"title\\":\\"Readable Reddit post\\",\\"author\\":\\"coder\\",\\"selftext\\":\\"Readable body\\",\\"permalink\\":\\"/r/OpenAI/comments/2/codex\\",\\"ups\\":9,\\"num_comments\\":2}}]}}"}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('Readable Reddit post');
      expect(posts[0].text).assertEqual('Readable body');
      expect(posts[0].url).assertEqual('https://www.reddit.com/r/OpenAI/comments/2/codex');
      expect(posts[0].score).assertEqual('9');
      expect(posts[0].commentCount).assertEqual('2');
    });

    it('maps X Composio payloads into aggregate discussion cards', 0, () => {
      const posts = xPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'x.post.search',
        title: 'Composio Twitter 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"data":[{"id":"x-1","text":"OpenAI Codex update","author_id":"user-1","created_at":"2026-07-20T01:00:00.000Z"}]}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('x');
      expect(posts[0].provider).assertEqual('X');
      expect(posts[0].text).assertEqual('OpenAI Codex update');
      expect(posts[0].publishedAt).assertEqual('2026-07-20T01:00:00.000Z');
    });

    it('skips non-success Hacker News rows', 0, () => {
      const posts = hackerNewsPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'HACKERNEWS_SEARCH_POSTS',
        title: 'Composio Hacker News 结果',
        status: 'needs_auth',
        summary: 'Composio 未配置：Hacker News 需要授权。',
        rows: [
          { label: '请求', value: '帮我用 Composio Hacker News 搜 openai codex 的帖子' },
          { label: '结果摘要', value: 'Composio 未配置：Hacker News 需要授权。' }
        ],
        rawPreview: 'raw'
      });

      expect(posts.length).assertEqual(0);
    });

    it('ranks exact and token query matches before weak matches', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('old-weak', 'x', 'Compiler notes', 'A general compiler note', 'https://x.test/weak', '2026-07-01T00:00:00.000Z', 3),
          waterfallCandidate('reddit-token', 'reddit', 'Codex tools for agents', 'A partial topic match', 'https://reddit.test/token', '2026-08-05T00:00:00.000Z', 2),
          waterfallCandidate('hn-exact', 'hackernews', 'Codex tools for OpenAI', 'All query terms in the title', 'https://news.test/exact', '2026-08-05T00:00:00.000Z', 1),
          waterfallCandidate('yt-exact', 'youtube', 'OpenAI Codex release', 'The exact topic is in the title', 'https://youtube.test/exact', '2026-08-06T10:00:00.000Z', 0)
        ],
        enabledSources: ['youtube', 'hackernews', 'reddit', 'x'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('yt-exact,hn-exact,reddit-token,old-weak');
      expect(ranked[0].reason).assertEqual('标题命中查询 · 24 小时内发布');
    });

    it('uses freshness then original order without random output', 0, () => {
      const candidates = [
        waterfallCandidate('same-old', 'youtube', 'OpenAI Codex', 'Same title', 'https://youtube.test/old', '2026-07-10T00:00:00.000Z', 0),
        waterfallCandidate('same-new', 'bilibili', 'OpenAI Codex', 'Same title', 'https://bilibili.test/new', '2026-08-06T11:00:00.000Z', 1),
        waterfallCandidate('same-invalid-date', 'x', 'OpenAI Codex', 'Same title', 'https://x.test/invalid', 'not-a-date', 2)
      ];
      const first = rankWaterfallCandidates({
        query: 'openai codex', candidates: candidates, enabledSources: ['youtube', 'bilibili', 'x'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS);
      const second = rankWaterfallCandidates({
        query: 'openai codex', candidates: candidates, enabledSources: ['youtube', 'bilibili', 'x'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(first.map((item) => item.id).join(',')).assertEqual('same-new,same-old,same-invalid-date');
      expect(second.map((item) => item.id).join(',')).assertEqual(first.map((item) => item.id).join(','));
      expect(first[2].reason).assertEqual('标题命中查询');
    });

    it('balances sources inside the same relevance tier', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('youtube-0', 'youtube', 'Earlier OpenAI Codex', '', 'https://youtube.test/0', '2026-08-01T00:00:00.000Z', -1),
          waterfallCandidate('youtube-1', 'youtube', 'OpenAI Codex', '', 'https://youtube.test/1', '2026-08-01T00:00:00.000Z', 0),
          waterfallCandidate('youtube-2', 'youtube', 'OpenAI Codex', '', 'https://youtube.test/2', '2026-08-01T00:00:00.000Z', 1),
          waterfallCandidate('x-1', 'x', 'OpenAI Codex', '', 'https://x.test/1', '2026-08-01T00:00:00.000Z', 2)
        ],
        enabledSources: ['youtube', 'x'],
        shownIds: ['youtube-0'],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('x-1,youtube-1,youtube-2');
    });

    it('deduplicates normalized links across video and post', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('duplicate-post', 'x', 'OpenAI Codex', 'Older duplicate', 'https://EXAMPLE.test/watch?id=7#comments', '2026-07-01T00:00:00.000Z', 1),
          waterfallCandidate('duplicate-video', 'youtube', 'OpenAI Codex', 'Newer duplicate', 'HTTPS://example.test/watch?id=7#top', '2026-08-06T10:00:00.000Z', 0),
          waterfallCandidate('different-query', 'reddit', 'OpenAI Codex', '', 'https://example.test/watch?id=8#top', '2026-08-06T10:00:00.000Z', 2)
        ],
        enabledSources: ['youtube', 'x', 'reddit'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('duplicate-video,different-query');
      expect(ranked[0].normalizedUrl).assertEqual('https://example.test/watch?id=7');
    });

    it('keeps only enabled sources and truthful reason signals', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('valid', 'youtube', 'OpenAI Codex', '', 'https://youtube.test/valid', '', 0),
          waterfallCandidate('disabled', 'x', 'OpenAI Codex', '', 'https://x.test/disabled', '2026-08-06T11:00:00.000Z', 1),
          waterfallCandidate('relative', 'youtube', 'OpenAI Codex', '', '/relative', '2026-08-06T11:00:00.000Z', 2),
          waterfallCandidate('empty-url', 'youtube', 'OpenAI Codex', '', '', '2026-08-06T11:00:00.000Z', 3)
        ],
        enabledSources: ['youtube'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: 'only show official'
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('valid');
      expect(ranked[0].reason).assertEqual('标题命中查询');
    });

    it('maps video image-text and post fields without inventing data', 0, () => {
      const videos: AggregateSearchVideo[] = [{
        id: 'video-1', source: 'youtube', provider: 'YouTube', title: 'Video title', summary: 'Video summary',
        url: 'https://youtube.test/video-1', thumbnail: 'https://img.test/video.jpg', publishedAt: '2026-08-06T10:00:00.000Z',
        duration: '1:00', status: 'success', rows: []
      }];
      const posts: AggregateSearchPost[] = [{
        id: 'post-1', source: 'x', provider: 'X', title: 'Post title', author: 'author', handle: '@author', text: 'Post body',
        url: 'https://x.test/post-1', publishedAt: '2026-08-06T09:00:00.000Z', score: '1', commentCount: '2', status: 'success',
        rows: [{ label: 'image', value: 'https://img.test/post.jpg' }]
      }, {
        id: 'post-2', source: 'x', provider: 'X', title: 'Post without image', author: '', handle: '', text: 'Body',
        url: 'https://x.test/post-2', publishedAt: '', score: '', commentCount: '', status: 'success', rows: []
      }];
      const candidates = aggregateMediaCandidates(videos, posts, 0);

      expect(candidates.length).assertEqual(3);
      expect(candidates[0].mediaType).assertEqual('video');
      expect(candidates[0].coverUrl).assertEqual('https://img.test/video.jpg');
      expect(candidates[1].mediaType).assertEqual('image_text');
      expect(candidates[1].summary).assertEqual('Post body');
      expect(candidates[2].mediaType).assertEqual('post');
      expect(candidates[2].coverUrl).assertEqual('');
    });
  });
}
