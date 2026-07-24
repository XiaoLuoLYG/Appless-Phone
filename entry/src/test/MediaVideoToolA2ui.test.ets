import { describe, it, expect } from '@ohos/hypium';
import { A2uiGenericToolResultData, GenericStructuredData } from '@loop/agent-core';
import {
  genericStructuredDataResult,
  isMediaVideoResult,
  mediaVideoPlaybackAction,
  mediaVideoStructuredDataA2ui
} from '@loop/agent-core';

function result(sourceTag: string, toolName: string, status: string, url: string): A2uiGenericToolResultData {
  return {
    sourceTag: sourceTag,
    toolName: toolName,
    title: 'Qwen Max official intro',
    status: status,
    summary: 'video result',
    rows: url.length > 0 ? [{ label: 'Watch URL', value: url }] : [],
    rawPreview: 'videoId=abc123'
  };
}

export default function mediaVideoToolA2uiTest() {
  describe('mediaVideoToolA2ui', () => {
    it('creates playback actions for YouTube and Bilibili success rows', 0, () => {
      const youtube = result('YouTube Data API', 'media.video.search', 'success', 'https://www.youtube.com/watch?v=abc123');
      const bilibili = result('哔哩哔哩', 'media.video.search', 'success', 'https://www.bilibili.com/video/BV1h57y6pE5o');

      expect(isMediaVideoResult(youtube)).assertTrue();
      expect(mediaVideoPlaybackAction(youtube)?.id).assertEqual('media.open.web');
      expect(mediaVideoPlaybackAction(youtube)?.label).assertEqual('跳转');
      expect(mediaVideoPlaybackAction(youtube)?.prompt).assertEqual('https://www.youtube.com/watch?v=abc123');
      expect(mediaVideoPlaybackAction(bilibili)?.id).assertEqual('media.open.web');
      expect(mediaVideoPlaybackAction(bilibili)?.label).assertEqual('跳转');
      expect(mediaVideoPlaybackAction(bilibili)?.kind).assertEqual('client');
      expect(mediaVideoPlaybackAction(bilibili)?.variant).assertEqual('primary');
      expect(mediaVideoPlaybackAction(bilibili)?.prompt).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
    });

    it('does not create playback actions for errors or rows without official URLs', 0, () => {
      const errorRow = result('哔哩哔哩', 'media.video.search', 'error', 'https://www.bilibili.com/video/BV1h57y6pE5o');
      const missingUrl = result('哔哩哔哩', 'media.video.search', 'success', '');
      const nonUrl = result('哔哩哔哩', 'media.video.search', 'success', 'not-a-url');
      const playlist = result('Composio YouTube', 'youtube.mine.playlists', 'success', 'https://www.youtube.com/playlist?list=PL123');

      expect(mediaVideoPlaybackAction(errorRow)).assertEqual(null);
      expect(mediaVideoPlaybackAction(missingUrl)).assertEqual(null);
      expect(mediaVideoPlaybackAction(nonUrl)).assertEqual(null);
      expect(isMediaVideoResult(playlist)).assertTrue();
      expect(mediaVideoPlaybackAction(playlist)?.prompt).assertEqual('https://www.youtube.com/playlist?list=PL123');
    });

    it('classifies multi-source media data and renders the same result object', 0, () => {
      const youtube = result('YouTube Data API', 'media.video.search', 'success', 'https://www.youtube.com/watch?v=abc123');
      const bilibili = result('哔哩哔哩', 'media.video.search', 'error', '');
      bilibili.summary = 'Bilibili provider unavailable';
      const structured = genericStructuredDataResult('media.video.search', 'mediaVideos', [youtube, bilibili]);
      const data = structured.data as GenericStructuredData;
      const jsonl = mediaVideoStructuredDataA2ui('surface_media_structured', 'media.video.search', data);

      expect(structured.status).assertEqual('partial');
      expect(structured.sources.length).assertEqual(2);
      expect(data.results[0].rawPreview).assertEqual('videoId=abc123');
      expect(jsonl.indexOf('https://www.youtube.com/watch?v=abc123')).assertLarger(-1);
      expect(JSON.stringify(structured.data).indexOf('updateComponents')).assertEqual(-1);
    });

    it('keeps YouTube empty distinct from provider error', 0, () => {
      const emptyRow = result('YouTube Data API', 'youtube.video.search', 'success', '');
      emptyRow.title = '没有找到 YouTube 视频';
      const errorRow = result('YouTube Data API', 'youtube.video.search', 'error', '');
      errorRow.summary = 'YOUTUBE_API_KEY missing';

      const empty = genericStructuredDataResult('youtube.video.search', 'youtubeVideos', [emptyRow]);
      const failed = genericStructuredDataResult('youtube.video.search', 'youtubeVideos', [errorRow]);

      expect(empty.status).assertEqual('empty');
      expect(failed.status).assertEqual('error');
      expect(failed.error?.message.indexOf('YOUTUBE_API_KEY')).assertLarger(-1);
    });
  });
}
