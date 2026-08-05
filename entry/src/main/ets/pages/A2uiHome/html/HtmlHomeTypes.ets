import { A2uiComponent, WaterfallFeedState, WaterfallRankedCandidate, WaterfallSourceState } from '@loop/agent-core';

export type HtmlHomeSource = 'welcome' | 'pending' | 'model' | 'tool';
export type HtmlHomeKind = 'welcome' | 'thinking' | 'travel' | 'hotel' | 'food' | 'social' | 'dynamic-tools' | 'gmail' | 'media' | 'payment' | 'aggregate-search' | 'luckin' | 'multi-task' | 'generic';

export interface HtmlHomeChip {
  label: string;
  value?: string;
}

export interface HtmlHomeMetric {
  label: string;
  value: string;
}

export interface HtmlHomeTimelineItem {
  title: string;
  subtitle?: string;
  status?: string;
}

export interface HtmlHomeAction {
  id: string;
  label: string;
  prompt: string;
  variant: string;
  kind: string;
  sourceComponentId?: string;
  args?: Object;
}

export interface HtmlHomeMediaEmbed {
  provider: string;
  title: string;
  embedUrl: string;
  pageUrl: string;
  thumbnail?: string;
}

export interface HtmlHomeStripeReceiving {
  status: string;
  message: string;
  stripeAccountId: string;
  onboardingUrl: string;
  currentlyDue: string[];
}

export interface HtmlHomeBlock {
  id: string;
  kind: string;
  title: string;
  subtitle?: string;
  status?: string;
  source?: string;
  credentialName?: string;
  credentialRef?: string;
  toolId?: string;
  sectionId?: string;
  prompt?: string;
  completionReply?: string;
  metrics: HtmlHomeMetric[];
  rows: HtmlHomeMetric[];
  actions: HtmlHomeAction[];
  rawPreview?: string;
  mediaEmbed?: HtmlHomeMediaEmbed;
  stripeReceiving?: HtmlHomeStripeReceiving;
  embeddedDocument?: HtmlHomeDocument;
}

export interface HtmlHomeHistoryItem {
  id: string;
  role: string;
  content: string;
}

export interface HtmlHomePersona {
  id: string;
  name: string;
  avatarKey: string;
  status: string;
  reason: string;
}

export interface HtmlHomePersonaMemory {
  summary: string;
  preferences: string[];
}

export interface WaterfallHomePayload {
  surfaceId: string;
  query: string;
  candidates: WaterfallRankedCandidate[];
  sources: WaterfallSourceState[];
  replenishing: boolean;
  exhausted: boolean;
}

export interface HtmlHomeDocument {
  version: number;
  surfaceId?: string;
  source: HtmlHomeSource;
  kind: HtmlHomeKind;
  title: string;
  subtitle: string;
  chips: HtmlHomeChip[];
  metrics: HtmlHomeMetric[];
  timeline: HtmlHomeTimelineItem[];
  blocks: HtmlHomeBlock[];
  actions: HtmlHomeAction[];
  history: HtmlHomeHistoryItem[];
  persona: HtmlHomePersona;
  personaMemory: HtmlHomePersonaMemory;
  rawSurfaceRoot: A2uiComponent | null;
  waterfall?: WaterfallFeedState;
  activeSectionId?: string;
  executionMode?: 'parallel' | 'serial';
  generatedAt: string;
}
