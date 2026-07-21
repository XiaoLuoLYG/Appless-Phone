import { ComposioAuthConfigItem } from '@loop/agent-core';

export interface ComposioToolkitSummary {
  slug: string;
  name: string;
}

export interface ExternalAuthApp {
  slug: string;
  name: string;
  subtitle: string;
  source: string;
  url: string;
}

export const COMPOSIO_SUPPORTED_TOOLKITS: ComposioToolkitSummary[] = [
  { slug: 'gmail', name: 'Gmail' },
  { slug: 'github', name: 'GitHub' },
  { slug: 'googlecalendar', name: 'Google Calendar' },
  { slug: 'googledrive', name: 'Google Drive' },
  { slug: 'googledocs', name: 'Google Docs' },
  { slug: 'slack', name: 'Slack' },
  { slug: 'notion', name: 'Notion' },
  { slug: 'linear', name: 'Linear' },
  { slug: 'asana', name: 'Asana' },
  { slug: 'trello', name: 'Trello' },
  { slug: 'outlook', name: 'Outlook' },
  { slug: 'discord', name: 'Discord' },
  { slug: 'linkedin', name: 'LinkedIn' },
  { slug: 'whatsapp', name: 'WhatsApp' },
  { slug: 'instagram', name: 'Instagram' },
  { slug: 'youtube', name: 'YouTube' },
  { slug: 'x', name: 'X' },
  { slug: 'spotify', name: 'Spotify' },
  { slug: 'tiktok', name: 'TikTok' },
  { slug: 'ticketmaster', name: 'Ticketmaster' },
  { slug: 'hubspot', name: 'HubSpot' },
  { slug: 'salesforce', name: 'Salesforce' },
  { slug: 'reddit', name: 'Reddit' }
];

export const EXTERNAL_AUTH_APPS: ExternalAuthApp[] = [
  {
    slug: 'qqmail',
    name: 'QQ 邮箱',
    subtitle: '获取 IMAP/SMTP 授权码',
    source: 'QQ 邮箱官方页面 · 当前默认凭证',
    url: 'https://wx.mail.qq.com/list/readtemplate?name=app_intro.html#/agreement/authorizationCode'
  },
  {
    slug: 'luckin',
    name: '瑞幸咖啡',
    subtitle: '登录并查看 MCP Token',
    source: '瑞幸官方页面 · 当前默认凭证',
    url: 'https://open01.luckincoffeecdn.com/'
  },
  {
    slug: 'didi',
    name: '滴滴出行',
    subtitle: '登录并管理个人 MCP Key',
    source: '滴滴官方页面 · 当前默认凭证',
    url: 'https://mcp.didichuxing.com'
  }
];

export function composioToolkitDisplayName(toolkitSlug: string, fallback: string = ''): string {
  let slug = toolkitSlug.trim().toLowerCase().split(' ').join('').split('-').join('').split('_').join('');
  if (slug === 'twitter') {
    slug = 'x';
  } else if (slug === 'calendar') {
    slug = 'googlecalendar';
  } else if (slug === 'microsoftoutlook') {
    slug = 'outlook';
  } else if (slug === 'youtubev3' || slug === 'youtubedata') {
    slug = 'youtube';
  }
  for (let index = 0; index < COMPOSIO_SUPPORTED_TOOLKITS.length; index++) {
    if (COMPOSIO_SUPPORTED_TOOLKITS[index].slug === slug) {
      return COMPOSIO_SUPPORTED_TOOLKITS[index].name;
    }
  }
  for (let index = 0; index < EXTERNAL_AUTH_APPS.length; index++) {
    if (EXTERNAL_AUTH_APPS[index].slug === slug) {
      return EXTERNAL_AUTH_APPS[index].name;
    }
  }
  return fallback.trim().length > 0 ? fallback.trim() : toolkitSlug.trim();
}

export function composioAuthStatusLabel(status: string): string {
  if (status === 'connected') {
    return '已连接';
  }
  if (status === 'error') {
    return '异常';
  }
  if (status === 'disabled') {
    return '已停用';
  }
  return '待授权';
}

export function composioAuthActionLabel(item: ComposioAuthConfigItem): string {
  return item.status === 'connected' ? '重新授权' : '授权';
}

export function sortedComposioAuthConfigs(items: ComposioAuthConfigItem[]): ComposioAuthConfigItem[] {
  return items.slice().sort((left: ComposioAuthConfigItem, right: ComposioAuthConfigItem) => {
    const leftRank = left.status === 'connected' ? 0 : 1;
    const rightRank = right.status === 'connected' ? 0 : 1;
    if (leftRank !== rightRank) {
      return leftRank - rightRank;
    }
    return composioToolkitDisplayName(left.toolkitSlug, left.toolkitName)
      .localeCompare(composioToolkitDisplayName(right.toolkitSlug, right.toolkitName));
  });
}
