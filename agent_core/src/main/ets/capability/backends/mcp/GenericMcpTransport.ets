export interface McpToolRequest {
  serverId: string;
  toolName: string;
  arguments: Object;
}

export interface McpToolResponse {
  ok: boolean;
  content: Object;
  errorCode: string;
  errorMessage: string;
}

export interface GenericMcpTransport {
  call(request: McpToolRequest): Promise<McpToolResponse>;
}
