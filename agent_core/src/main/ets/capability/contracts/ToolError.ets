export interface ToolError {
  code: string;
  message: string;
  retryable: boolean;
}

export function toolError(code: string, message: string, retryable: boolean = false): ToolError {
  return { code, message, retryable };
}
