export class AgentSkill {
  readonly name: string;
  readonly description: string;
  readonly homepage: string;
  readonly metadata: string;
  readonly location: string;
  readonly body: string;

  constructor(
    name: string,
    description: string,
    homepage: string,
    metadata: string,
    location: string,
    body: string
  ) {
    this.name = name;
    this.description = description;
    this.homepage = homepage;
    this.metadata = metadata;
    this.location = location;
    this.body = body;
  }

  instructions(): string {
    return this.body.trim();
  }
}
