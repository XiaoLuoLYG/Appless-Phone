import { AgentToolRunOptions } from './AgentToolRunOptions';

export interface AgentTool {
  name(): string;

  description(): string;

  run(input: string, options?: AgentToolRunOptions): Promise<string>;
}
