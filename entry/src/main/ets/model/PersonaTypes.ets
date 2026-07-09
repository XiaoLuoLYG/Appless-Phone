import { PersonaMarkdownSection, PersonaSkillMarkdown } from './PersonaMarkdown';

export interface PersonaManifest {
  id: string;
  name: string;
  avatarKey: string;
  domains: string[];
  defaultTools: string[];
}

export interface PersonaSkillRef {
  id: string;
  path: string;
  status: string;
}

export interface PersonaSkillManifest {
  activeSkillId: string;
  skills: PersonaSkillRef[];
}

export interface PersonaPack {
  manifest: PersonaManifest;
  soul: string;
  soulSections: PersonaMarkdownSection[];
  skills: string;
  skillManifest: PersonaSkillManifest;
  skillList: PersonaSkillMarkdown[];
  activeSkill: PersonaSkillMarkdown;
  memory: string;
  memorySections: PersonaMarkdownSection[];
}

export interface PersonaEditableSnapshot {
  id: string;
  soul: string;
  memory: string;
}

export interface PersonaRoute {
  personaId: string;
  reason: string;
}

export interface PersonaRuntimeData {
  id: string;
  name: string;
  avatarKey: string;
  status: string;
  reason: string;
}

export interface PersonaMemoryRuntimeData {
  summary: string;
  preferences: string[];
}

export function emptyPersonaRuntimeData(): PersonaRuntimeData {
  return {
    id: '',
    name: '',
    avatarKey: '',
    status: '',
    reason: ''
  };
}

export function emptyPersonaMemoryRuntimeData(): PersonaMemoryRuntimeData {
  return {
    summary: '',
    preferences: []
  };
}
