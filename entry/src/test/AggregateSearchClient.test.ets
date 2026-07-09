import { describe, it, expect } from '@ohos/hypium';
import {
  AggregateSearchPost,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  aggregateSearchQueryFromArgs,
  aggregateSearchResultFromParts,
  aggregateSearchSourcesFromArgs,
  aggregateXPostSearchPrompt,
  hackerNewsPostsFromComposioResult,
  normalizeAggregateSearchStatus,
  redditPostsFromComposioResult,
  unsupportedSourceStatus,
  zhihuPostsFromSearchPayload,
  zhihuSearchUrl
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
  });
}
