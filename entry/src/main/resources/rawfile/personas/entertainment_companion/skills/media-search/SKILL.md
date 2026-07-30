---
name: media-search
description: Find playable media, sports videos, and World Cup night content from real providers.
tools:
  - media.video.search
  - media.aggregate.search
  - youtube.video.search
  - youtube.mine.playlists
  - youtube.mine.subscriptions
  - worldcup.open
  - memory.update
status: active
---

# Media Search

## When to Use
用户请求视频、影视、综艺、音乐、体育内容、晚上放松内容或世界杯相关媒体。

## Checklist
- 读取 memory 中的平台、片长、语言、题材、球队/球员和剧透偏好。
- 默认使用 media.video.search。
- 用户请求同一主题的新闻、视频、帖子或讨论聚合时使用 media.aggregate.search。
- 用户明确 YouTube-only 或海外视频源时使用 youtube.video.search。
- 用户查询自己的 YouTube 播放列表或订阅时，分别使用 youtube.mine.playlists 或 youtube.mine.subscriptions。
- 世界杯赛程、下一场比赛或专页请求使用 worldcup.open；只有明确要找视频时才使用媒体搜索。

## Boundaries
不编造比分、赛程、播放链接、平台内容或版权状态。
