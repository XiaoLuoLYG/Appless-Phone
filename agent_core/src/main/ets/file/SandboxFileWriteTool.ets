import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { AgentTool } from '../agent/AgentTool';
import { AgentToolRunOptions } from '../agent/AgentToolRunOptions';

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'SandboxFile';
const MAX_CONTENT_BYTES = 100 * 1024;

interface SandboxFileWriteRequest {
  relativePath?: string;
  content?: string;
}

export class SandboxFileWriteTool implements AgentTool {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  name(): string {
    return 'write_sandbox_file';
  }

  description(): string {
    return 'Writes text content to a file under the app sandbox filesDir. Input JSON: ' +
      '{"relativePath":"path/under/filesDir.txt","content":"text"}. ' +
      'The path must be relative and cannot contain .. .';
  }

  async run(input: string, _options?: AgentToolRunOptions): Promise<string> {
    try {
      const request = JSON.parse(input.trim()) as SandboxFileWriteRequest;
      const relativePath = this.validateRelativePath(`${request.relativePath ?? ''}`);
      const content = `${request.content ?? ''}`;
      if (content.length === 0) {
        throw new Error('Missing content.');
      }
      if (content.length > MAX_CONTENT_BYTES) {
        throw new Error(`Content too large. Limit is ${MAX_CONTENT_BYTES} characters.`);
      }

      const targetPath = `${this.context.filesDir}/${relativePath}`;
      this.ensureParentDirectory(targetPath);
      this.writeTextFile(targetPath, content);
      this.logInfo(`wrote relativePath=${relativePath}`);
      return `Wrote sandbox file: ${relativePath}`;
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      this.logWarn(`write failed; ${message}`);
      return `Failed to write sandbox file: ${message}`;
    }
  }

  private validateRelativePath(path: string): string {
    const trimmed = path.trim().replace(/\\/g, '/');
    if (trimmed.length === 0) {
      throw new Error('Missing relativePath.');
    }
    if (trimmed.startsWith('/') || trimmed.indexOf(':') >= 0) {
      throw new Error('relativePath must not be absolute.');
    }
    const parts = trimmed.split('/').filter((part: string): boolean => part.length > 0);
    for (const part of parts) {
      if (part === '.' || part === '..') {
        throw new Error('relativePath must not contain . or .. segments.');
      }
    }
    if (parts.length === 0) {
      throw new Error('relativePath must include a file name.');
    }
    return parts.join('/');
  }

  private ensureParentDirectory(path: string): void {
    const slash = path.lastIndexOf('/');
    if (slash <= 0) {
      return;
    }
    const parent = path.substring(0, slash);
    this.ensureDirectory(parent);
  }

  private ensureDirectory(path: string): void {
    if (this.pathExists(path)) {
      return;
    }
    fs.mkdirSync(path, true);
  }

  private pathExists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (_error) {
      return false;
    }
  }

  private writeTextFile(path: string, text: string): void {
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, text);
    } finally {
      fs.closeSync(file);
    }
  }

  private logInfo(message: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  private logWarn(message: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }
}
