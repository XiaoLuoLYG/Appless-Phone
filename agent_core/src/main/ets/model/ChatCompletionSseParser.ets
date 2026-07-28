class SseBoundary {
  index: number;
  length: number;

  constructor(index: number, length: number) {
    this.index = index;
    this.length = length;
  }
}

export class ChatCompletionSseParser {
  private buffer: string = '';

  feed(text: string): string[] {
    if (text.length > 0) {
      this.buffer += text;
    }

    const payloads: string[] = [];
    while (true) {
      const boundary: SseBoundary | null = this.findBoundary();
      if (boundary === null) {
        break;
      }
      const frame: string = this.buffer.substring(0, boundary.index);
      this.buffer = this.buffer.substring(boundary.index + boundary.length);
      const payload: string | null = this.readDataPayload(frame);
      if (payload !== null) {
        payloads.push(payload);
      }
    }
    return payloads;
  }

  finish(): string[] {
    if (this.buffer.trim().length === 0) {
      this.buffer = '';
      return [];
    }
    const frame: string = this.buffer;
    this.buffer = '';
    const payload: string | null = this.readDataPayload(frame);
    return payload === null ? [] : [payload];
  }

  private findBoundary(): SseBoundary | null {
    const crlf: number = this.buffer.indexOf('\r\n\r\n');
    const lf: number = this.buffer.indexOf('\n\n');
    const cr: number = this.buffer.indexOf('\r\r');
    let index: number = -1;
    let length: number = 0;
    if (crlf >= 0) {
      index = crlf;
      length = 4;
    }
    if (lf >= 0 && (index < 0 || lf < index)) {
      index = lf;
      length = 2;
    }
    if (cr >= 0 && (index < 0 || cr < index)) {
      index = cr;
      length = 2;
    }
    return index < 0 ? null : new SseBoundary(index, length);
  }

  private readDataPayload(frame: string): string | null {
    const normalized: string = frame.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    const lines: string[] = normalized.split('\n');
    const values: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.startsWith('data:')) {
        values.push(line.substring('data:'.length).trim());
      }
    }
    return values.length === 0 ? null : values.join('\n');
  }
}
