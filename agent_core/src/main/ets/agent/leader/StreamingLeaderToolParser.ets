const APPLESS_TOOL_OPEN_TAG: string = '<appless_tool>';
const APPLESS_TOOL_CLOSE_TAG: string = '</appless_tool>';

enum StreamingLeaderToolParserState {
  TEXT,
  TOOL_BODY
}

export class StreamingLeaderToolParser {
  private state: StreamingLeaderToolParserState = StreamingLeaderToolParserState.TEXT;
  private pending: string = '';
  private normalized: string = '';
  private body: string = '';
  private bodyInString: boolean = false;
  private bodyEscaped: boolean = false;

  feed(delta: string): string[] {
    if (delta.length > 0) {
      this.pending += delta;
    }
    const completedBodies: string[] = [];
    while (true) {
      if (this.state === StreamingLeaderToolParserState.TEXT) {
        const open: number = this.pending.indexOf(APPLESS_TOOL_OPEN_TAG);
        if (open < 0) {
          this.moveSafeTextPrefix();
          break;
        }
        this.normalized += this.pending.substring(0, open);
        this.pending = this.pending.substring(open + APPLESS_TOOL_OPEN_TAG.length);
        this.body = '';
        this.bodyInString = false;
        this.bodyEscaped = false;
        this.state = StreamingLeaderToolParserState.TOOL_BODY;
      }

      const close: number = this.structuralCloseIndex();
      if (close < 0) {
        this.moveSafeBodyPrefix();
        break;
      }
      const suffix: string = this.pending.substring(0, close);
      this.consumeBodyText(suffix);
      this.body += suffix;
      this.normalized += suffix;
      this.pending = this.pending.substring(close + APPLESS_TOOL_CLOSE_TAG.length);
      completedBodies.push(this.body);
      this.body = '';
      this.bodyInString = false;
      this.bodyEscaped = false;
      this.state = StreamingLeaderToolParserState.TEXT;
    }
    return completedBodies;
  }

  textWithoutTagsSoFar(): string {
    return this.normalized;
  }

  finish(): string {
    if (this.state === StreamingLeaderToolParserState.TOOL_BODY) {
      throw new Error('Leader tool stream ended before </appless_tool>.');
    }
    this.normalized += this.pending;
    this.pending = '';
    return this.normalized;
  }

  private moveSafeTextPrefix(): void {
    const retained: number = this.partialMarkerLength(this.pending, APPLESS_TOOL_OPEN_TAG);
    const safeLength: number = this.pending.length - retained;
    if (safeLength > 0) {
      this.normalized += this.pending.substring(0, safeLength);
      this.pending = this.pending.substring(safeLength);
    }
  }

  private moveSafeBodyPrefix(): void {
    const retained: number = this.partialMarkerLength(this.pending, APPLESS_TOOL_CLOSE_TAG);
    const safeLength: number = this.pending.length - retained;
    if (safeLength > 0) {
      const safe: string = this.pending.substring(0, safeLength);
      this.consumeBodyText(safe);
      this.body += safe;
      this.normalized += safe;
      this.pending = this.pending.substring(safeLength);
    }
  }

  private structuralCloseIndex(): number {
    let inString: boolean = this.bodyInString;
    let escaped: boolean = this.bodyEscaped;
    for (let index: number = 0; index < this.pending.length; index++) {
      const char: string = this.pending[index];
      if (escaped) {
        escaped = false;
      } else if (inString && char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = !inString;
      } else if (!inString &&
        this.pending.substring(index, index + APPLESS_TOOL_CLOSE_TAG.length) === APPLESS_TOOL_CLOSE_TAG) {
        return index;
      }
    }
    return -1;
  }

  private consumeBodyText(text: string): void {
    for (let index: number = 0; index < text.length; index++) {
      const char: string = text[index];
      if (this.bodyEscaped) {
        this.bodyEscaped = false;
      } else if (this.bodyInString && char === '\\') {
        this.bodyEscaped = true;
      } else if (char === '"') {
        this.bodyInString = !this.bodyInString;
      }
    }
  }

  private partialMarkerLength(text: string, marker: string): number {
    const maximum: number = Math.min(text.length, marker.length - 1);
    for (let length: number = maximum; length > 0; length--) {
      if (text.substring(text.length - length) === marker.substring(0, length)) {
        return length;
      }
    }
    return 0;
  }
}
