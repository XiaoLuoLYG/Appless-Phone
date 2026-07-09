export function composioToolkitLogoResource(toolkitSlug: string): Resource {
  const slug = toolkitSlug.trim().toLowerCase().split(' ').join('').split('-').join('').split('_').join('');
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
  return $r('app.media.logo_appless');
}
