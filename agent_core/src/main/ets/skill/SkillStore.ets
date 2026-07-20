import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { AgentSkill } from './AgentSkill';
import { skillLogInfo, skillLogWarn } from './SkillLog';
import { parseSkillMarkdown } from './SkillMarkdownParser';

const SKILLS_ROOT = 'skills';
const SKILL_FILE = 'SKILL.md';

export function sandboxSkillsRoot(context: common.UIAbilityContext): string {
  return `${context.filesDir}/${SKILLS_ROOT}`;
}

export async function ensureBundledSkillsInSandbox(context: common.UIAbilityContext): Promise<void> {
  const root = sandboxSkillsRoot(context);
  ensureDirectory(root);

  let entries: string[] = [];
  try {
    entries = await context.resourceManager.getRawFileList(SKILLS_ROOT);
  } catch (_error) {
    skillLogWarn(`SkillStore: no bundled rawfile/${SKILLS_ROOT} directory`);
    return;
  }

  skillLogInfo(`SkillStore: syncing ${entries.length} bundled skills into sandbox`);
  for (const name of entries) {
    const rawPath = `${SKILLS_ROOT}/${name}/${SKILL_FILE}`;
    const targetDir = `${root}/${safeDirectoryName(name)}`;
    const targetPath = `${targetDir}/${SKILL_FILE}`;
    if (pathExists(targetPath)) {
      skillLogInfo(`SkillStore: sandbox skill exists, skip bundled copy path=${targetPath}`);
      continue;
    }

    try {
      const raw = await context.resourceManager.getRawFileContent(rawPath);
      ensureDirectory(targetDir);
      writeTextFile(targetPath, decodeRawFile(raw));
      skillLogInfo(`SkillStore: copied bundled skill raw=${rawPath} target=${targetPath}`);
    } catch (error) {
      skillLogWarn(`SkillStore: failed to copy bundled skill raw=${rawPath}; ${describeError(error)}`);
    }
  }
}

export async function loadSandboxSkills(context: common.UIAbilityContext): Promise<AgentSkill[]> {
  await ensureBundledSkillsInSandbox(context);

  const root = sandboxSkillsRoot(context);
  const skills: AgentSkill[] = [];
  let entries: string[] = [];
  try {
    entries = fs.listFileSync(root);
  } catch (error) {
    skillLogWarn(`SkillStore: failed to list sandbox skills root=${root}; ${describeError(error)}`);
    return skills;
  }

  skillLogInfo(`SkillStore: loading ${entries.length} sandbox skill entries root=${root}`);
  for (const name of entries) {
    const path = `${root}/${name}/${SKILL_FILE}`;
    if (!pathExists(path)) {
      continue;
    }
    try {
      const skill = parseSkillMarkdown(readTextFile(path), path);
      skills.push(skill);
      skillLogInfo(`SkillStore: loaded sandbox skill name=${skill.name} location=${path}`);
    } catch (error) {
      skillLogWarn(`SkillStore: skipped sandbox skill path=${path}; ${describeError(error)}`);
    }
  }
  skillLogInfo(`SkillStore: ready sandboxSkillCount=${skills.length}`);
  return skills;
}

function ensureDirectory(path: string): void {
  if (pathExists(path)) {
    return;
  }
  fs.mkdirSync(path, true);
}

function pathExists(path: string): boolean {
  try {
    return fs.accessSync(path);
  } catch (_error) {
    return false;
  }
}

function readTextFile(path: string): string {
  return fs.readTextSync(path, { encoding: 'utf-8' });
}

function writeTextFile(path: string, text: string): void {
  const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, text);
  } finally {
    fs.closeSync(file);
  }
}

function safeDirectoryName(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    throw new Error('Skill name cannot be empty.');
  }
  return trimmed.replace(/[^A-Za-z0-9_-]/g, '_');
}

function decodeRawFile(raw: Uint8Array | ArrayBuffer): string {
  const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  const bytes = raw instanceof ArrayBuffer ? new Uint8Array(raw) : new Uint8Array(raw.buffer);
  return decoder.decodeToString(bytes);
}

function describeError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  return `${error}`;
}
