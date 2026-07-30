import { ComposioAuthConfigItem } from '@loop/agent-core';

export interface ComposioToolkitSummary {
  slug: string;
  name: string;
  requiresAuth?: boolean;
}

export interface ExternalAuthApp {
  slug: string;
  name: string;
  subtitle: string;
  source: string;
  url: string;
  requiresAuth?: boolean;
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
  { slug: 'reddit', name: 'Reddit' },
  { slug: 'hackernews', name: 'Hacker News', requiresAuth: false }
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
  },
  {
    slug: 'googlemaps',
    name: 'Google Maps',
    subtitle: '无需用户授权',
    source: '内置能力',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'bilibili',
    name: 'Bilibili',
    subtitle: '无需用户授权',
    source: '公开内容能力',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'wecom',
    name: 'WeCom',
    subtitle: '无需用户授权',
    source: '当前本地配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'paypal',
    name: 'PayPal',
    subtitle: '无需用户授权',
    source: '当前支付配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'stripe',
    name: 'Stripe',
    subtitle: '无需用户授权',
    source: '当前支付配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'googlepay',
    name: 'Google Pay',
    subtitle: '无需用户授权',
    source: '系统支付入口',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'amap',
    name: 'Amap',
    subtitle: '无需用户授权',
    source: '当前地图配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'baidumaps',
    name: 'Baidu Maps',
    subtitle: '无需用户授权',
    source: '当前地图配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'tencentmaps',
    name: 'Tencent Maps',
    subtitle: '无需用户授权',
    source: '当前地图配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'meituan',
    name: 'Meituan',
    subtitle: '无需用户授权',
    source: '当前本地配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'taobao',
    name: 'Taobao',
    subtitle: '无需用户授权',
    source: '当前本地配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'mcdonalds',
    name: 'McDonald’s',
    subtitle: '无需用户授权',
    source: '当前本地配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'kfc',
    name: 'KFC',
    subtitle: '无需用户授权',
    source: '当前本地配置',
    url: '',
    requiresAuth: false
  },
  {
    slug: 'zhihu',
    name: 'Zhihu',
    subtitle: '无需用户授权',
    source: '当前内容配置',
    url: '',
    requiresAuth: false
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
  if (status === 'success') {
    return '无需授权';
  }
  if (status === 'error') {
    return '异常';
  }
  if (status === 'disabled') {
    return '待配置';
  }
  return '待授权';
}

export function composioAuthActionLabel(item: ComposioAuthConfigItem): string {
  return item.status === 'connected' ? '重新授权' : '授权';
}

export function sortedComposioAuthConfigs(items: ComposioAuthConfigItem[]): ComposioAuthConfigItem[] {
  const visible = items.slice();
  for (let index = 0; index < COMPOSIO_SUPPORTED_TOOLKITS.length; index++) {
    const toolkit = COMPOSIO_SUPPORTED_TOOLKITS[index];
    const matches = visible.filter((item: ComposioAuthConfigItem) =>
      composioToolkitDisplayName(item.toolkitSlug, item.toolkitName) === toolkit.name);
    if (matches.length === 0) {
      visible.push({
        authConfigId: '',
        toolkitSlug: toolkit.slug,
        toolkitName: toolkit.name,
        logoUrl: '',
        authScheme: '',
        management: '',
        status: toolkit.requiresAuth === false ? 'success' : 'disabled',
        connectedAccountId: '',
        connectedAccountLabel: '',
        lastConnectedAt: '',
        canExecute: toolkit.requiresAuth === false
      });
    }
  }
  return visible.sort((left: ComposioAuthConfigItem, right: ComposioAuthConfigItem) => {
    const leftRank = left.status === 'connected' ? 0 : 1;
    const rightRank = right.status === 'connected' ? 0 : 1;
    if (leftRank !== rightRank) {
      return leftRank - rightRank;
    }
    return composioToolkitDisplayName(left.toolkitSlug, left.toolkitName)
      .localeCompare(composioToolkitDisplayName(right.toolkitSlug, right.toolkitName));
  });
}
