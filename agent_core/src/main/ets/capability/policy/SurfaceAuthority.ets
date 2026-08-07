import { ToolCall } from '../contracts/ToolCall';

export class SurfaceAuthority {
  allows(call: ToolCall): boolean {
    return call.context.surfaceId.trim().length > 0 && call.context.turnId.trim().length > 0;
  }
}
