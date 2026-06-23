import { DynamicToolManifest } from './DynamicToolTypes';
import { DynamicToolSampleRecord, sampleRecordsForDiscovery } from './DynamicToolSamples';

export interface DynamicToolDiscoveryResult {
  toolId: string;
  manifest: DynamicToolManifest;
  query: string;
  source: string;
  score: number;
  reason: string;
}

interface ScoredDynamicToolCandidate {
  toolId: string;
  manifest: DynamicToolManifest;
  score: number;
  reason: string;
}

function appendText(target: string[], value: string): void {
  const text = value.trim();
  if (text.length > 0) {
    target.push(text);
  }
}

function searchableText(record: DynamicToolSampleRecord): string {
  const parts: string[] = [];
  for (let index = 0; index < record.toolIds.length; index++) {
    appendText(parts, record.toolIds[index]);
  }
  appendText(parts, record.manifest.id);
  appendText(parts, record.manifest.displayName);
  appendText(parts, record.manifest.sourceUrl);
  appendText(parts, record.manifest.fromSiteUrl);
  for (let index = 0; index < record.manifest.capabilities.length; index++) {
    appendText(parts, record.manifest.capabilities[index]);
  }
  for (let index = 0; index < record.manifest.requiredCredentials.length; index++) {
    appendText(parts, record.manifest.requiredCredentials[index].name);
    appendText(parts, record.manifest.requiredCredentials[index].description);
  }
  for (let index = 0; index < record.manifest.tools.length; index++) {
    appendText(parts, record.manifest.tools[index].name);
    appendText(parts, record.manifest.tools[index].description);
  }
  return parts.join(' ').toLowerCase();
}

function queryTerms(query: string): string[] {
  const normalized = query.toLowerCase();
  const terms: string[] = [];
  const candidates: string[] = [
    '天气', '气温', '降雨', '下雨',
    '统计局', 'gdp', 'cpi', '人口', '经济数据',
    'ppt', '幻灯片', '演示文稿',
    '地图', '高德', '百度',
    'mcp'
  ];
  for (let index = 0; index < candidates.length; index++) {
    if (normalized.indexOf(candidates[index]) >= 0) {
      terms.push(candidates[index]);
    }
  }
  return terms;
}

function scoreRecord(record: DynamicToolSampleRecord, query: string): ScoredDynamicToolCandidate | null {
  const text = searchableText(record);
  const terms = queryTerms(query);
  let score = 0;
  const matched: string[] = [];
  for (let index = 0; index < terms.length; index++) {
    const term = terms[index].toLowerCase();
    if (text.indexOf(term) >= 0) {
      score += term.length >= 3 ? 4 : 2;
      matched.push(terms[index]);
    }
  }
  for (let index = 0; index < record.toolIds.length; index++) {
    const alias = record.toolIds[index].toLowerCase();
    if (query.toLowerCase().indexOf(alias) >= 0) {
      score += 8;
      matched.push(record.toolIds[index]);
    }
  }
  if (score <= 0) {
    return null;
  }
  return {
    toolId: record.toolIds.length > 0 ? record.toolIds[0] : record.manifest.id,
    manifest: record.manifest,
    score: score,
    reason: matched.join(',')
  };
}

export function discoverDynamicToolForPrompt(query: string): DynamicToolDiscoveryResult | null {
  const records = sampleRecordsForDiscovery();
  let best: ScoredDynamicToolCandidate | null = null;
  for (let index = 0; index < records.length; index++) {
    const candidate = scoreRecord(records[index], query);
    if (candidate === null) {
      continue;
    }
    if (best === null || candidate.score > best.score) {
      best = candidate;
    }
  }
  if (best === null) {
    return null;
  }
  return {
    toolId: best.toolId,
    manifest: best.manifest,
    query: query,
    source: 'modelscope-local-catalog',
    score: best.score,
    reason: best.reason
  };
}
