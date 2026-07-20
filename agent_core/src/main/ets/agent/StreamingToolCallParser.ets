const APPLESS_TOOL_OPEN_TAG = '<appless_tool>';
const APPLESS_TOOL_CLOSE_TAG = '</appless_tool>';

enum ToolCallParserState {
  TEXT,
  TOOL_BODY,
  DONE
}

export class ToolCall {
  name: string;
  input: string;

  constructor(name: string, input: string) {
    this.name = name;
    this.input = input;
  }
}

export function parseToolCallText(value: string): ToolCall | null {
  let action = value.trim();
  if (action.startsWith('Action:')) {
    action = action.substring('Action:'.length).trim();
  }

  const parenCall = parseDelimitedToolCall(action, '(', ')');
  if (parenCall !== null) {
    return parenCall;
  }
  return parseDelimitedToolCall(action, '[', ']');
}

function parseDelimitedToolCall(action: string, openToken: string, closeToken: string): ToolCall | null {
  const open = action.indexOf(openToken);
  const close = action.lastIndexOf(closeToken);
  if (open <= 0 || close < open || action.substring(close + closeToken.length).trim().length > 0) {
    return null;
  }

  const name = action.substring(0, open).trim();
  if (name.length === 0) {
    return null;
  }
  const input = action.substring(open + openToken.length, close).trim();
  return new ToolCall(name, input);
}

export class StreamingToolCallParser {
  private state: ToolCallParserState = ToolCallParserState.TEXT;
  private pending: string = '';
  private leading: string = '';
  private body: string = '';

  feed(delta: string): ToolCall | null {
    if (delta.length > 0) {
      this.pending += delta;
    }

    if (this.state === ToolCallParserState.TEXT) {
      const open = this.pending.indexOf(APPLESS_TOOL_OPEN_TAG);
      if (open < 0) {
        this.moveSafePrefixToLeading();
        return null;
      }

      this.leading += this.pending.substring(0, open);
      this.pending = this.pending.substring(open + APPLESS_TOOL_OPEN_TAG.length);
      this.state = ToolCallParserState.TOOL_BODY;
    }

    if (this.state === ToolCallParserState.TOOL_BODY) {
      const close = this.pending.indexOf(APPLESS_TOOL_CLOSE_TAG);
      if (close < 0) {
        this.moveSafePrefixToBody();
        return null;
      }

      this.body += this.pending.substring(0, close);
      this.pending = this.pending.substring(close + APPLESS_TOOL_CLOSE_TAG.length);
      this.state = ToolCallParserState.DONE;
      const call = parseToolCallText(this.body);
      if (call === null) {
        throw new Error('Malformed tool call inside <appless_tool>.');
      }
      return call;
    }

    return null;
  }

  finish(): void {
    if (this.state === ToolCallParserState.TOOL_BODY) {
      throw new Error('Tool call stream ended before </appless_tool>.');
    }
    if (this.state === ToolCallParserState.TEXT) {
      this.leading += this.pending;
      this.pending = '';
    }
  }

  leadingText(): string {
    return this.leading;
  }

  private moveSafePrefixToLeading(): void {
    const retained = this.partialMarkerLength(this.pending, APPLESS_TOOL_OPEN_TAG);
    const safeLength = this.pending.length - retained;
    if (safeLength > 0) {
      this.leading += this.pending.substring(0, safeLength);
      this.pending = this.pending.substring(safeLength);
    }
  }

  private moveSafePrefixToBody(): void {
    const retained = this.partialMarkerLength(this.pending, APPLESS_TOOL_CLOSE_TAG);
    const safeLength = this.pending.length - retained;
    if (safeLength > 0) {
      this.body += this.pending.substring(0, safeLength);
      this.pending = this.pending.substring(safeLength);
    }
  }

  private partialMarkerLength(text: string, marker: string): number {
    const maximum = Math.min(text.length, marker.length - 1);
    for (let length = maximum; length > 0; length--) {
      if (text.substring(text.length - length) === marker.substring(0, length)) {
        return length;
      }
    }
    return 0;
  }
}
