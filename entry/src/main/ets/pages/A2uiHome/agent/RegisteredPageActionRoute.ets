import {
  A2uiAction,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  JsonValue,
  MapsRouteArgs,
  ToolDefinition,
  actionAgentToolDefinitions,
  mapsRouteInputFromPrompt,
  toolDefinitionForToolId
} from '@loop/agent-core';
import { HtmlHomeDocument } from '../html/HtmlHomeTypes';

const FIXED_PAGE_ACTION_IDS: string[] = [
  'luckin.order.preview',
  'social.reply.draft',
  'mail.draft.create',
  'gmail.draft.create',
  'gmail.draft.apply',
  'gmail.open.web',
  'worldcup.open',
  'payment.send',
  'payment.account.setup',
  'maps.route.open'
];

const PAGE_ACTION_CANDIDATE_IDS: string[] = [
  'luckin.order.preview',
  'social.reply.draft',
  'mail.draft.create',
  'gmail.draft.create',
  'gmail.draft.apply',
  'gmail.open.web',
  'worldcup.open',
  'payment.confirm',
  'payment.send',
  'stripe.account.create',
  'stripe.account.onboard',
  'stripe.account.refresh',
  'payment.account.setup',
  'maps.route.open'
];

export interface RegisteredPageActionResolution {
  action: A2uiAction;
  pageActionId: string;
}

export interface RegisteredPageSnapshot {
  surface: A2uiSurfaceState;
  document: HtmlHomeDocument;
  generation: number;
}

interface RegisteredPageSnapshotMaterial {
  surface: A2uiSurfaceState;
  document: HtmlHomeDocument;
}

export interface RegisteredPageDispatchResult {
  candidate: boolean;
  ok: boolean;
}

export type RegisteredPageCandidateRunner = (action: A2uiAction) => Promise<boolean>;
export type LegacyPageActionRunner = (action: A2uiAction) => Promise<void>;

interface WorldCupVirtualArgs {
  route: string;
}

function registeredProductAction(actionId: string): boolean {
  if (FIXED_PAGE_ACTION_IDS.indexOf(actionId) < 0) {
    return false;
  }
  return actionAgentToolDefinitions().some(
    (definition: ToolDefinition): boolean => definition.toolId === actionId
  );
}

function adaptedTarget(sourceToolId: string, clickedActionId: string): string {
  if (sourceToolId === 'payment.send' && clickedActionId === 'payment.confirm') {
    return 'payment.send';
  }
  if (sourceToolId === 'payment.account.setup' &&
    (clickedActionId === 'stripe.account.create' ||
      clickedActionId === 'stripe.account.onboard' ||
      clickedActionId === 'stripe.account.refresh')) {
    return 'payment.account.setup';
  }
  return '';
}

function cloneSnapshot(snapshot: RegisteredPageSnapshot): RegisteredPageSnapshot | null {
  try {
    return JSON.parse(JSON.stringify(snapshot)) as RegisteredPageSnapshot;
  } catch (_error) {
    return null;
  }
}

function canonicalJson(value: JsonValue | undefined): string {
  if (value === undefined) {
    return '';
  }
  if (value === null || typeof value === 'string' ||
    typeof value === 'number' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    const values = value as JsonValue[];
    const parts: string[] = [];
    for (let index = 0; index < values.length; index++) {
      parts.push(canonicalJson(values[index]));
    }
    return '[' + parts.join(',') + ']';
  }
  const record = value as Record<string, JsonValue | undefined>;
  const keys = Object.keys(record).sort();
  const parts: string[] = [];
  for (let index = 0; index < keys.length; index++) {
    const current = record[keys[index]];
    if (current !== undefined) {
      parts.push(JSON.stringify(keys[index]) + ':' + canonicalJson(current));
    }
  }
  return '{' + parts.join(',') + '}';
}

export function registeredPageSnapshotFingerprint(snapshot: RegisteredPageSnapshot): string {
  const material: RegisteredPageSnapshotMaterial = {
    surface: snapshot.surface,
    document: snapshot.document
  };
  return canonicalJson(material as Object);
}

export class RegisteredPageSnapshotStore {
  private snapshot: RegisteredPageSnapshot | null = null;
  private fingerprint: string = '';

  record(
    surface: A2uiSurfaceState,
    document: HtmlHomeDocument,
    generation: number
  ): boolean {
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
      surface.surfaceId.trim().length === 0 ||
      document.surfaceId === undefined ||
      document.surfaceId !== surface.surfaceId ||
      document.generatedAt.trim().length === 0) {
      return false;
    }
    const candidate: RegisteredPageSnapshot = { surface, document, generation };
    const cloned = cloneSnapshot(candidate);
    if (cloned === null) {
      return false;
    }
    const nextFingerprint = registeredPageSnapshotFingerprint(cloned);
    if (this.snapshot !== null &&
      (generation < this.snapshot.generation ||
        (generation === this.snapshot.generation && nextFingerprint !== this.fingerprint))) {
      return false;
    }
    this.snapshot = cloned;
    this.fingerprint = nextFingerprint;
    return true;
  }

  current(): RegisteredPageSnapshot | null {
    return this.snapshot === null ? null : cloneSnapshot(this.snapshot);
  }

  clear(): void {
    this.snapshot = null;
    this.fingerprint = '';
  }
}

export function registeredPageSourceToolId(surface: A2uiSurfaceState): string {
  try {
    const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    const sourceToolId = model.summary.toolName.trim();
    return toolDefinitionForToolId(sourceToolId) === null ? '' : sourceToolId;
  } catch (_error) {
    return '';
  }
}

export function resolveRegisteredPageAction(
  sourceToolId: string,
  clicked: A2uiAction
): RegisteredPageActionResolution | null {
  if (clicked.args === undefined || clicked.args === null ||
    typeof clicked.args !== 'object' || Array.isArray(clicked.args)) {
    return null;
  }
  const source = toolDefinitionForToolId(sourceToolId);
  if (source === null) {
    return null;
  }
  let targetId = '';
  if (source.actions.indexOf(clicked.id) >= 0 && registeredProductAction(clicked.id)) {
    targetId = clicked.id;
  } else if (sourceToolId === 'luckin.order.preview' && clicked.id === 'luckin.order.preview') {
    targetId = clicked.id;
  } else {
    targetId = adaptedTarget(sourceToolId, clicked.id);
  }
  if (!registeredProductAction(targetId)) {
    return null;
  }
  return {
    pageActionId: clicked.id,
    action: {
      id: targetId,
      label: clicked.label,
      prompt: clicked.prompt,
      variant: clicked.variant,
      kind: clicked.kind,
      args: clicked.args
    }
  };
}

export function isFixedRegisteredPageAction(actionId: string): boolean {
  return registeredProductAction(actionId);
}

export function isRegisteredPageActionCandidate(actionId: string): boolean {
  return PAGE_ACTION_CANDIDATE_IDS.indexOf(actionId) >= 0;
}

export async function dispatchRegisteredPageActionCandidate(
  action: A2uiAction,
  registered: RegisteredPageCandidateRunner,
  legacy: LegacyPageActionRunner
): Promise<RegisteredPageDispatchResult> {
  if (isRegisteredPageActionCandidate(action.id)) {
    let ok = false;
    try {
      ok = await registered(action);
    } catch (_error) {
      ok = false;
    }
    return { candidate: true, ok };
  }
  await legacy(action);
  return { candidate: false, ok: true };
}

export function resolveVirtualRegisteredPageAction(
  actionId: string,
  inputText: string
): A2uiAction | null {
  if (actionId === 'worldcup.open' && inputText.trim().length > 0) {
    const args: WorldCupVirtualArgs = { route: 'pages/A2uiHome/AnythingDemo' };
    return {
      id: actionId,
      label: actionId,
      prompt: inputText.trim(),
      variant: 'primary',
      kind: 'prompt',
      args: args as Object
    };
  }
  if (actionId === 'maps.route.open') {
    const args: MapsRouteArgs | null = mapsRouteInputFromPrompt(inputText);
    if (args === null) {
      return null;
    }
    return {
      id: actionId,
      label: actionId,
      prompt: inputText.trim(),
      variant: 'primary',
      kind: 'prompt',
      args: args as Object
    };
  }
  return null;
}
