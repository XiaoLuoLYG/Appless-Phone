import { describe, it, expect } from '@ohos/hypium';
import { youtubeSearchUrl, youtubeVideoResultsFromSearchPayload } from '@loop/agent-core';

export default function youtubeApiClientTest() {
  describe('youTubeApiClient', () => {
    it('builds a search URL for public video search', 0, () => {
      const url = youtubeSearchUrl('qwen max 官方介绍', 'api-key-123');

      expect(url.indexOf('https://www.googleapis.com/youtube/v3/search?')).assertEqual(0);
      expect(url.indexOf('part=snippet')).assertLarger(-1);
      expect(url.indexOf('type=video')).assertLarger(-1);
      expect(url.indexOf('q=qwen%20max%20%E5%AE%98%E6%96%B9%E4%BB%8B%E7%BB%8D')).assertLarger(-1);
      expect(url.indexOf('key=api-key-123')).assertLarger(-1);
    });

    it('supports view-count ordering and five-result searches', 0, () => {
      const url = youtubeSearchUrl('world cup', 'api-key-123', 'viewCount', 5);

      expect(url.indexOf('order=viewCount')).assertLarger(-1);
      expect(url.indexOf('maxResults=5')).assertLarger(-1);
      expect(url.indexOf('q=world%20cup')).assertLarger(-1);
    });

    it('maps YouTube search payload into generic tool rows', 0, () => {
      const payload = '{"items":[{"id":{"videoId":"abc123"},"snippet":{"title":"Qwen Max official intro","channelTitle":"Qwen Channel","publishedAt":"2026-06-01T00:00:00Z","thumbnails":{"medium":{"url":"https://i.ytimg.com/vi/abc123/mqdefault.jpg"}}}}]}';
      const results = youtubeVideoResultsFromSearchPayload(payload, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('YouTube Data API');
      expect(results[0].toolName).assertEqual('youtube.video.search');
      expect(results[0].title).assertEqual('Qwen Max official intro');
      expect(results[0].rows[0].label).assertEqual('Channel');
      expect(results[0].rows[3].value).assertEqual('https://www.youtube.com/watch?v=abc123');
    });
  });
}
