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
        this.state = StreamingLeaderToolParserState.TOOL_BODY;
      }

      const close: number = this.pending.indexOf(APPLESS_TOOL_CLOSE_TAG);
      if (close < 0) {
        this.moveSafeBodyPrefix();
        break;
      }
      const suffix: string = this.pending.substring(0, close);
      this.body += suffix;
      this.normalized += suffix;
      this.pending = this.pending.substring(close + APPLESS_TOOL_CLOSE_TAG.length);
      completedBodies.push(this.body);
      this.body = '';
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
      this.body += safe;
      this.normalized += safe;
      this.pending = this.pending.substring(safeLength);
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
