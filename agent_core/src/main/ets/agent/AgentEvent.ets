export enum AgentEventKind {
  THOUGHT = 'THOUGHT',
  ACTION = 'ACTION',
  OBSERVATION = 'OBSERVATION',
  UI = 'UI',
  FINAL = 'FINAL',
  ERROR = 'ERROR'
}

export class AgentEvent {
  kind: AgentEventKind;
  text: string;
  toolId: string;
  toolInput: string;

  constructor(kind: AgentEventKind, text: string, toolId: string = '', toolInput: string = '') {
    this.kind = kind;
    this.text = text;
    this.toolId = toolId;
    this.toolInput = toolInput;
  }
}
