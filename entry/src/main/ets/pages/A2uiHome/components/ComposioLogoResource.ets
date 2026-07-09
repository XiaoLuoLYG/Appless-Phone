export function composioToolkitLogoResource(toolkitSlug: string): Resource | null {
  const slug = toolkitSlug.trim().toLowerCase().split(' ').join('').split('-').join('').split('_').join('');
  if (slug === 'gmail') {
    return $r('app.media.logo_gmail');
  }
  if (slug === 'qqmail') {
    return $r('app.media.logo_qqmail');
  }
  if (slug === 'googlecalendar' || slug === 'calendar') {
    return $r('app.media.logo_googlecalendar');
  }
  if (slug === 'googlemaps' || slug === 'googleplaces') {
    return $r('app.media.logo_googlemaps');
  }
  if (slug === 'youtube') {
    return $r('app.media.logo_youtube');
  }
  if (slug === 'bilibili') {
    return $r('app.media.logo_bilibili');
  }
  if (slug === 'x' || slug === 'twitter') {
    return $r('app.media.logo_x');
  }
  if (slug === 'wecom' || slug === 'wework') {
    return $r('app.media.logo_wecom');
  }
  if (slug === 'github') {
    return $r('app.media.logo_github');
  }
  if (slug === 'googledrive') {
    return $r('app.media.logo_googledrive');
  }
  if (slug === 'googledocs') {
    return $r('app.media.logo_googledocs');
  }
  if (slug === 'slack') {
    return $r('app.media.logo_slack');
  }
  if (slug === 'notion') {
    return $r('app.media.logo_notion');
  }
  if (slug === 'linear') {
    return $r('app.media.logo_linear');
  }
  if (slug === 'asana') {
    return $r('app.media.logo_asana');
  }
  if (slug === 'trello') {
    return $r('app.media.logo_trello');
  }
  if (slug === 'outlook' || slug === 'microsoftoutlook') {
    return $r('app.media.logo_microsoftoutlook');
  }
  if (slug === 'discord') {
    return $r('app.media.logo_discord');
  }
  if (slug === 'linkedin') {
    return $r('app.media.logo_linkedin');
  }
  if (slug === 'whatsapp') {
    return $r('app.media.logo_whatsapp');
  }
  if (slug === 'instagram') {
    return $r('app.media.logo_instagram');
  }
  if (slug === 'spotify') {
    return $r('app.media.logo_spotify');
  }
  if (slug === 'tiktok') {
    return $r('app.media.logo_tiktok');
  }
  if (slug === 'ticketmaster') {
    return $r('app.media.logo_ticketmaster');
  }
  if (slug === 'hubspot') {
    return $r('app.media.logo_hubspot');
  }
  if (slug === 'salesforce') {
    return $r('app.media.logo_salesforce');
  }
  if (slug === 'paypal') {
    return $r('app.media.logo_paypal');
  }
  if (slug === 'stripe') {
    return $r('app.media.logo_stripe');
  }
  if (slug === 'googlepay') {
    return $r('app.media.logo_googlepay');
  }
  if (slug === 'amap' || slug === 'gaode') {
    return $r('app.media.logo_amap');
  }
  if (slug === 'baidumaps' || slug === 'baidu') {
    return $r('app.media.logo_baidumaps');
  }
  if (slug === 'tencentmaps' || slug === 'tencent') {
    return $r('app.media.logo_tencentmaps');
  }
  if (slug === 'meituan') {
    return $r('app.media.logo_meituan');
  }
  if (slug === 'taobao') {
    return $r('app.media.logo_taobao');
  }
  if (slug === 'luckin') {
    return $r('app.media.logo_luckin');
  }
  if (slug === 'mcdonalds' || slug === 'mcd') {
    return $r('app.media.logo_mcdonalds');
  }
  if (slug === 'kfc') {
    return $r('app.media.logo_kfc');
  }
  return null;
}
