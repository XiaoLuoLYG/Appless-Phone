import {
  CreateSurfaceBody,
  CreateSurfaceEnvelope,
  DeleteSurfaceBody,
  DeleteSurfaceEnvelope
} from './A2uiTypes';

export const A2UI_VERSION = 'v0.9.1';

/** AGenUI freestanding catalog — see AGenUI/agenui_catalog.json */
export const AGENUI_CATALOG_ID = 'https://github.com/AGenUI/AGenUI/blob/main/agenui_catalog.json';

export function buildCreateSurface(surfaceId: string): string {
  const createSurface: CreateSurfaceBody = {
    surfaceId: surfaceId,
    catalogId: AGENUI_CATALOG_ID
  };
  const envelope: CreateSurfaceEnvelope = {
    version: A2UI_VERSION,
    createSurface: createSurface
  };
  return JSON.stringify(envelope);
}

export function buildDeleteSurface(surfaceId: string): string {
  const deleteSurface: DeleteSurfaceBody = {
    surfaceId: surfaceId
  };
  const envelope: DeleteSurfaceEnvelope = {
    version: A2UI_VERSION,
    deleteSurface: deleteSurface
  };
  return JSON.stringify(envelope);
}

function stripMarkdownFences(text: string): string {
  let result = text.trim();
  if (!result.startsWith('```')) {
    return result;
  }
  const firstNewline = result.indexOf('\n');
  if (firstNewline >= 0) {
    result = result.substring(firstNewline + 1);
  }
  const closingFence = result.lastIndexOf('```');
  if (closingFence >= 0) {
    result = result.substring(0, closingFence);
  }
  return result.trim();
}

/** Pull complete {...} objects from free-form LLM text (handles pretty-printed JSON). */
export function extractJsonObjects(text: string): string[] {
  const objects: string[] = [];
  let index = 0;
  while (index < text.length) {
    const start = text.indexOf('{', index);
    if (start === -1) {
      break;
    }

    let depth = 0;
    let inString = false;
    let escaped = false;
    let closedAt = -1;

    for (let cursor = start; cursor < text.length; cursor++) {
      const ch = text[cursor];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === '\\') {
          escaped = true;
        } else if (ch === '"') {
          inString = false;
        }
      } else if (ch === '"') {
        inString = true;
      } else if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0) {
          closedAt = cursor;
          break;
        }
      }
    }

    if (closedAt === -1) {
      break;
    }

    const candidate = text.substring(start, closedAt + 1);
    try {
      JSON.parse(candidate);
      objects.push(candidate);
    } catch (_error) {
      // skip invalid object
    }
    index = closedAt + 1;
  }
  return objects;
}

/** Strip markdown fences and split LLM output into JSONL lines. */
export function parseJsonl(raw: string): string[] {
  const text = stripMarkdownFences(raw);
  const merged: string[] = [];

  const addObject = (candidate: string): void => {
    const trimmed = candidate.trim();
    if (trimmed.length === 0 || !trimmed.startsWith('{')) {
      return;
    }
    for (const existing of merged) {
      if (existing === trimmed) {
        return;
      }
    }
    try {
      JSON.parse(trimmed);
      merged.push(trimmed);
    } catch (_error) {
      // skip malformed object
    }
  };

  for (const line of text.split(/\r?\n/)) {
    addObject(line);
  }

  for (const object of extractJsonObjects(text)) {
    addObject(object);
  }

  return merged;
}

export function newSurfaceId(): string {
  return `loop_surface_${Date.now()}`;
}
