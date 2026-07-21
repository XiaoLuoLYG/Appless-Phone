# Loopy Single-Runtime Convergence and PR Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Every task follows superpowers:test-driven-development and every completion claim follows superpowers:verification-before-completion.

**Goal:** Delete Loopy's older Leader/UIMaker orchestration from both shared-core copies, keep only the structured four-agent architecture as the public runtime, turn the Loopy app into a non-interactive library status shell, preserve the still-used `ReActAgentRunner` as a private migration utility, and update the two existing Draft PRs with a new upstream Loopy base branch.

**Architecture:** Appless remains the product host and temporary canonical working copy for the shared core. Loopy receives the exact controlled shared-core file set, then removes its old assistant demo. `ReActAgentRunner` remains only because `LoopBackend` still has real non-hotel callers; it is not exported or wrapped as a second agent architecture. Cross-repository parity is proven with tracked path and SHA-256 comparisons before any push.

**Tech Stack:** Git, GitHub CLI, HarmonyOS ArkTS, Hvigor, Hypium, Node.js source verifiers, GitHub Draft PRs.

## Global Constraints

- Update existing Appless PR #67 and Loopy PR #11. Do not create replacement PRs.
- Create `Raym0ndKwan/loopy:agent-core-convergence` from the latest upstream `hos`, then retarget PR #11 to that branch.
- Keep Appless PR #67 based on `main`.
- Do not force-push, rebase published branches, reset, discard unrelated commits, delete user files, or reuse another application's signing identity.
- Preserve the concurrent commit `a8f5fd07 docs: design in-app hotel web booking`; it is not part of this plan and must not be removed or rewritten.
- Delete only the explicitly identified obsolete runtime and demo files after a live caller scan.
- Keep only one real worktree per repository; do not create a new worktree for this already-isolated branch.
- Do not add a fake provider, fake four-agent production runtime, or model probe to the Loopy app.
- Remove this plan and its approved design spec from the final product diff after implementation evidence is complete.

---

## Task 1: Refresh both published branches without rewriting history

**Repositories:**

- `/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo`
- `/Users/luoyige/DevEcoStudioProjects/loopy`

- [ ] **Step 1: Record protected baselines**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo status --short
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo branch --show-current
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo worktree list
git -C /Users/luoyige/DevEcoStudioProjects/loopy status --short
git -C /Users/luoyige/DevEcoStudioProjects/loopy branch --show-current
git -C /Users/luoyige/DevEcoStudioProjects/loopy worktree list
```

Expected: each repository has one worktree and no uncommitted product changes. If either is dirty, stop and isolate the exact unrelated paths; do not stash them without user approval.

- [ ] **Step 2: Fetch fresh remote state**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo fetch origin main codex/multi-agent-hotel-implementation
git -C /Users/luoyige/DevEcoStudioProjects/loopy fetch origin hos
git -C /Users/luoyige/DevEcoStudioProjects/loopy fetch fork hos codex/appless-agent-core-convergence
```

- [ ] **Step 3: Recheck the existing Draft PRs and target branch availability**

```bash
gh pr view 67 --repo XiaoLuoLYG/Appless-Phone \
  --json number,state,isDraft,baseRefName,headRefName,headRefOid,url
gh pr view 11 --repo Raym0ndKwan/loopy \
  --json number,state,isDraft,baseRefName,headRefName,headRefOid,url
gh api repos/Raym0ndKwan/loopy/git/ref/heads/agent-core-convergence
```

Expected before publishing: both PRs remain open Drafts. A 404 for the new upstream branch is expected at this point. If it already exists, compare its SHA with current `origin/hos` before deciding whether it is safe to reuse.

- [ ] **Step 4: Merge current bases only when needed**

Inspect:

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo rev-list --left-right --count HEAD...origin/main
git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-list --left-right --count HEAD...origin/hos
```

If the right-hand count is non-zero, merge the fetched base without rebasing:

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo merge --no-edit origin/main
git -C /Users/luoyige/DevEcoStudioProjects/loopy merge --no-edit origin/hos
```

Resolve conflicts by preserving the approved structured contract and upstream changes that are not the obsolete orchestration. Run `git diff --check` and commit the merge before continuing.

---

## Task 2: Delete the obsolete runtime from the Appless shared core

**Files:**

- Delete: `agent_core/src/main/ets/agent/AgentMessageTypes.ets`
- Delete: `agent_core/src/main/ets/agent/CreateUiTaskTool.ets`
- Delete: `agent_core/src/main/ets/agent/LeaderAgent.ets`
- Delete: `agent_core/src/main/ets/agent/LeaderAgentPrompt.ets`
- Delete: `agent_core/src/main/ets/agent/LeaderToolRegistry.ets`
- Delete: `agent_core/src/main/ets/agent/MessageBus.ets`
- Delete: `agent_core/src/main/ets/agent/MessageDrivenAgent.ets` (old ReAct base)
- Delete: `agent_core/src/main/ets/agent/ReActAgent.ets`
- Delete: `agent_core/src/main/ets/agent/UIMakerAgent.ets`
- Delete: `agent_core/src/main/ets/agent/UIMakerAgentPrompt.ets`
- Delete: `agent_core/src/main/ets/agent/UIMakerToolRegistry.ets`
- Delete: `agent_core/src/main/ets/agent/LoopAgentPrompt.ets` if the live scan still shows no caller
- Rename: `agent_core/src/main/ets/agent/StructuredMessageDrivenAgent.ets` to `agent_core/src/main/ets/agent/MessageDrivenAgent.ets`
- Modify: `agent_core/src/main/ets/agent/leader/LeaderAgent.ets`
- Modify: `agent_core/src/main/ets/agent/data/DataAgent.ets`
- Modify: `agent_core/src/main/ets/agent/ui/UiAgent.ets`
- Modify: `agent_core/src/main/ets/agent/action/ActionAgent.ets`
- Modify: `agent_core/Index.ets`
- Modify: `entry/src/test/LinkedMessageBus.test.ets`
- Modify: `scripts/verify-loopy-backend.mjs`

- [ ] **Step 1: Prove the delete set with a live caller scan**

```bash
for name in AgentMessageTypes CreateUiTaskTool LeaderAgentPrompt LeaderToolRegistry \
  MessageBus ReActAgent UIMakerAgent UIMakerAgentPrompt UIMakerToolRegistry LoopAgentPrompt; do
  rg -n "$name" agent_core entry scripts \
    --glob '!**/build/**' --glob '!**/.test/**'
done
```

Expected: references form the obsolete subgraph plus public exports/verifier assertions only. Separately prove the retained runner has a real caller:

```bash
rg -n "new ReActAgentRunner|ReActAgentRunner" \
  agent_core/src/main/ets/aiphone/LoopBackend.ets \
  agent_core/src/main/ets/agent/ReActAgentRunner.ets \
  entry/src/test/ReActAgentRunner.test.ets
```

- [ ] **Step 2: Write failing single-runtime verifier assertions**

Require:

- old files do not exist;
- `Index.ets` contains no `ReactLeaderAgent`, `ReactLinkedMessageBus`, `ReactMessageDrivenAgent`, `UIMakerAgent`, or `ReActAgent` export;
- `ReActAgentRunner` remains exported because `LoopBackend` still imports it;
- `ToolRegistry`, `TimeTool`, `UiTool`, and skill support remain only when reached from the runner/LoopBackend;
- the four agents extend the canonical `MessageDrivenAgent` class;
- there is only one public `LinkedMessageBus` and one public `LeaderAgent`.

- [ ] **Step 3: Run the verifier and confirm RED**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node scripts/verify-loopy-backend.mjs
```

- [ ] **Step 4: Delete the obsolete subgraph and make the structured base canonical**

Use `apply_patch` for deletions and imports. Rename the structured base class itself, not through an alias:

```ts
export abstract class MessageDrivenAgent {
  // existing independent-reader, serial pump, stop/start behavior unchanged
}
```

Update the four agents to:

```ts
import { MessageDrivenAgent } from '../MessageDrivenAgent';
export class DataAgent extends MessageDrivenAgent { /* existing behavior */ }
```

Update `Index.ets` to export only:

```ts
export { MessageDrivenAgent } from './src/main/ets/agent/MessageDrivenAgent';
export { LeaderAgent } from './src/main/ets/agent/leader/LeaderAgent';
export { DataAgent } from './src/main/ets/agent/data/DataAgent';
export { UiAgent } from './src/main/ets/agent/ui/UiAgent';
export { ActionAgent } from './src/main/ets/agent/action/ActionAgent';
export { AgentMessageReader, LinkedMessageBus } from './src/main/ets/agent/message/LinkedMessageBus';
```

Keep the separate utility export:

```ts
export { ReActAgentRunner, AgentListener, ReActRunOptions, UiRenderHandler }
  from './src/main/ets/agent/ReActAgentRunner';
```

- [ ] **Step 5: Run Hypium and verifier, then commit**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=test test --no-daemon
sed -n '1,160p' entry/.test/default/intermediates/test/coverage_data/test_result.txt

DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node scripts/verify-loopy-backend.mjs
```

Expected: zero Hypium failures/errors and verifier PASS.

```bash
git add -A agent_core entry/src/test/LinkedMessageBus.test.ets scripts/verify-loopy-backend.mjs
git commit -m "refactor: remove obsolete agent orchestration"
```

---

## Task 3: Synchronize the controlled shared core into Loopy

**Files:**

- Mirror: `agent_core/**` to `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/agent_core/**`
- Modify: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/scripts/verify-aiphone-backend.mjs`

- [ ] **Step 1: List controlled tracked files on both sides**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo ls-files agent_core | sort > /tmp/appless-agent-core-files.txt
git -C /Users/luoyige/DevEcoStudioProjects/loopy ls-files harmony/agent_core | \
  sed 's#^harmony/##' | sort > /tmp/loopy-agent-core-files.txt
comm -3 /tmp/appless-agent-core-files.txt /tmp/loopy-agent-core-files.txt
```

Expected before sync: only the intentional new/deleted files from phase one differ.

- [ ] **Step 2: Perform a controlled tracked-file sync**

Run this exact Node script from the Appless repository. It copies the source tracked set and deletes only target files tracked under `harmony/agent_core` that no longer exist in the source set. It does not touch build output, credentials, entry code, or unrelated Loopy paths.

```bash
node --input-type=module <<'NODE'
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';

const appless = '/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo';
const loopy = '/Users/luoyige/DevEcoStudioProjects/loopy';
const lines = (cwd, prefix) => execFileSync('git', ['-C', cwd, 'ls-files', prefix], { encoding: 'utf8' })
  .trim().split('\n').filter(Boolean);
const source = lines(appless, 'agent_core');
const target = lines(loopy, 'harmony/agent_core').map((path) => path.substring('harmony/'.length));
const sourceSet = new Set(source);

for (const relative of target) {
  if (!sourceSet.has(relative)) {
    rmSync(join(loopy, 'harmony', relative));
  }
}
for (const relative of source) {
  const from = join(appless, relative);
  const to = join(loopy, 'harmony', relative);
  if (!existsSync(dirname(to))) mkdirSync(dirname(to), { recursive: true });
  copyFileSync(from, to);
}
NODE
```

Stage only the synchronized shared core so the index reflects new and deleted tracked paths before parity comparison:

```bash
git -C /Users/luoyige/DevEcoStudioProjects/loopy add -A harmony/agent_core
```

- [ ] **Step 3: Update the Loopy verifier for the single runtime**

Make `harmony/scripts/verify-aiphone-backend.mjs` assert the same ownership and absence rules as the Appless verifier. Retain Loopy-specific HAR and entry checks. Remove assertions that instantiate or export the old React Leader/UIMaker runtime.

- [ ] **Step 4: Prove path and content identity**

Use Node SHA-256 rather than BSD-incompatible GNU `diff` flags:

```bash
node --input-type=module <<'NODE'
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
const a = '/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo';
const l = '/Users/luoyige/DevEcoStudioProjects/loopy';
const files = execFileSync('git', ['-C', a, 'ls-files', 'agent_core'], { encoding: 'utf8' })
  .trim().split('\n').filter(Boolean);
const loopyFiles = execFileSync('git', ['-C', l, 'ls-files', 'harmony/agent_core'], { encoding: 'utf8' })
  .trim().split('\n').filter(Boolean).map((path) => path.substring('harmony/'.length));
const pathDiff = [...new Set([...files, ...loopyFiles])].filter((path) => files.includes(path) !== loopyFiles.includes(path));
const mismatches = files.filter((path) => {
  const sha = (buffer) => createHash('sha256').update(buffer).digest('hex');
  return sha(readFileSync(join(a, path))) !== sha(readFileSync(join(l, 'harmony', path)));
});
console.log(JSON.stringify({ files: files.length, pathDiff, mismatches }, null, 2));
if (pathDiff.length > 0 || mismatches.length > 0) process.exit(1);
NODE
```

Expected: `pathDiff: []`, `mismatches: []`.

- [ ] **Step 5: Run the Loopy shared-core verifier and commit**

```bash
cd /Users/luoyige/DevEcoStudioProjects/loopy
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node harmony/scripts/verify-aiphone-backend.mjs
git add -A harmony/agent_core harmony/scripts/verify-aiphone-backend.mjs
git commit -m "refactor(harmony): converge on structured agent runtime"
```

---

## Task 4: Replace the Loopy assistant demo with a library-status page

**Files:**

- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/interactor/ChatInteractor.ets`
- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/agenui/A2uiFallbackParser.ets`
- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/agenui/A2uiFallbackView.ets`
- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/agenui/AgenuiNativeProbe.ets`
- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/agenui/AgenuiSurfaceController.ets`
- Delete: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/agenui/LoopUiApplier.ets`
- Replace: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/entry/src/main/ets/pages/Index.ets`
- Modify: `/Users/luoyige/DevEcoStudioProjects/loopy/harmony/scripts/verify-aiphone-backend.mjs`

- [ ] **Step 1: Write failing source-verifier checks**

Require the Loopy entry to contain no model factory, message bus, Agent instantiation, provider claim, input box, send button, fake tool, or A2UI fallback. Require the obsolete entry files to be absent.

- [ ] **Step 2: Run the Loopy verifier and confirm RED**

Expected: current entry imports `ReactLeaderAgent`, `UIMakerAgent`, `ChatInteractor`, model factories, and A2UI demo code.

- [ ] **Step 3: Replace the page with a non-interactive status view**

Use a simple page with no runtime imports:

```ts
@Entry
@Component
struct Index {
  build() {
    Column({ space: 12 }) {
      Text('Loopy Agent Core')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text('Structured Leader · Data · UI · Action runtime library')
        .fontSize(16)
      Text('This app module is a build shell. Runtime behavior is verified by shared tests.')
        .fontSize(14)
        .opacity(0.7)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding(24)
  }
}
```

Do not display provider availability, successful agent execution, or live data.

- [ ] **Step 4: Delete demo-only files after a second caller scan**

```bash
rg -n "ChatInteractor|A2uiFallback|AgenuiNativeProbe|AgenuiSurfaceController|LoopUiApplier" \
  /Users/luoyige/DevEcoStudioProjects/loopy/harmony \
  --glob '!**/build/**'
```

Expected before deletion: only the files themselves and old verifier assertions. After deletion: no matches.

- [ ] **Step 5: Run verifier and entry compilation**

```bash
cd /Users/luoyige/DevEcoStudioProjects/loopy
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node harmony/scripts/verify-aiphone-backend.mjs

cd /Users/luoyige/DevEcoStudioProjects/loopy/harmony
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=debug \
  :entry:default@CompileArkTS --no-daemon
```

Expected: verifier PASS and entry ArkTS compilation PASS without using maintainer-local signing files.

- [ ] **Step 6: Commit the Loopy app cleanup**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/loopy add -A \
  harmony/entry/src/main/ets harmony/scripts/verify-aiphone-backend.mjs
git -C /Users/luoyige/DevEcoStudioProjects/loopy commit \
  -m "refactor(harmony): make demo a library status shell"
```

---

## Task 5: Run final double-repository gates and remove process documents

**Files:**

- Remove from final product diff: `docs/superpowers/specs/2026-07-21-agent-core-single-runtime-convergence-design.md`
- Remove from final product diff: `docs/superpowers/plans/2026-07-21-structured-agent-contract-hotel-ui.md`
- Remove from final product diff: `docs/superpowers/plans/2026-07-21-loopy-single-runtime-delivery.md`

- [ ] **Step 1: Re-run Appless authoritative tests and audits**

```bash
cd /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node scripts/verify-loopy-backend.mjs
node --test scripts/hotel-smoke-evidence.test.mjs
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=test test --no-daemon
sed -n '1,180p' entry/.test/default/intermediates/test/coverage_data/test_result.txt
node /Users/luoyige/.codex/skills/appless-device-regression/scripts/audit-coverage.mjs \
  --repo /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo \
  --skill-root /Users/luoyige/.codex/skills/appless-device-regression
```

Expected: verifier and hotel evidence PASS, capability audit has no gaps, Hypium has zero Failure/Error. Do not treat coverage reporter noise as product failure, and do not treat command exit 0 as a substitute for `test_result.txt`.

- [ ] **Step 2: Re-run Loopy gates**

```bash
cd /Users/luoyige/DevEcoStudioProjects/loopy
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
node harmony/scripts/verify-aiphone-backend.mjs
```

Then run the entry compile command from Task 4.

- [ ] **Step 3: Re-run the SHA-256 parity script**

Expected: identical controlled path sets and zero content mismatches after all tests and verifier edits.

- [ ] **Step 4: Remove only this design/plan material**

```bash
git rm \
  docs/superpowers/specs/2026-07-21-agent-core-single-runtime-convergence-design.md \
  docs/superpowers/plans/2026-07-21-structured-agent-contract-hotel-ui.md \
  docs/superpowers/plans/2026-07-21-loopy-single-runtime-delivery.md
git status --short
git commit -m "chore: keep process docs out of product diff"
```

Do not remove or alter `a8f5fd07` or its in-app hotel booking design file.

- [ ] **Step 5: Inspect both final diffs for secrets and generated output**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo diff --check origin/main...HEAD
git -C /Users/luoyige/DevEcoStudioProjects/loopy diff --check origin/hos...HEAD
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo status --short
git -C /Users/luoyige/DevEcoStudioProjects/loopy status --short
```

Search changed files for raw keys, passwords, signing material, `.p12`, `.csr`, `.cer`, `.hap`, `.app`, `.smoke`, and `.test`. Any match must be understood and removed before publishing.

---

## Task 6: Create the upstream base branch and update the existing Draft PRs

**External changes:**

- Create: `Raym0ndKwan/loopy:agent-core-convergence`
- Update: `Raym0ndKwan/loopy#11`
- Update: `XiaoLuoLYG/Appless-Phone#67`

- [ ] **Step 1: Fetch once more and verify exact SHAs**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo fetch origin main
git -C /Users/luoyige/DevEcoStudioProjects/loopy fetch origin hos
git -C /Users/luoyige/DevEcoStudioProjects/loopy fetch fork
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo rev-parse HEAD
git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-parse HEAD
git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-parse origin/hos
```

If `origin/hos` advanced after Task 1, merge it into the Loopy feature branch, re-run Tasks 3–5, and only then continue.

- [ ] **Step 2: Create the upstream base branch from the exact latest `hos` SHA**

First confirm the branch still does not exist. Then:

```bash
UPSTREAM_HOS_SHA=$(git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-parse origin/hos)
gh api repos/Raym0ndKwan/loopy/git/refs \
  -f ref='refs/heads/agent-core-convergence' \
  -f sha="$UPSTREAM_HOS_SHA"
```

Verify:

```bash
gh api repos/Raym0ndKwan/loopy/git/ref/heads/agent-core-convergence \
  --jq '.object.sha'
```

Expected: exact equality with `UPSTREAM_HOS_SHA`.

- [ ] **Step 3: Push the existing feature branches**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo push \
  origin codex/multi-agent-hotel-implementation
git -C /Users/luoyige/DevEcoStudioProjects/loopy push \
  fork codex/appless-agent-core-convergence
```

No force flag.

- [ ] **Step 4: Update PR #11 instead of creating another PR**

Prepare a body that states:

- the structured four-agent runtime is the only public orchestration;
- old Leader/UIMaker/bus files and demo are removed;
- `ReActAgentRunner` remains only for real Appless migration callers;
- hotel facts remain deterministic and planner layout is constrained/fallback-safe;
- shared core path/SHA parity and exact validation results;
- base branch purpose and phase-two boundary.

Then run:

```bash
gh pr edit 11 --repo Raym0ndKwan/loopy \
  --base agent-core-convergence \
  --title "refactor(harmony): converge on structured four-agent core" \
  --body-file /tmp/loopy-single-runtime-pr.md
```

Keep it Draft.

- [ ] **Step 5: Update PR #67 and keep base `main`**

```bash
gh pr edit 67 --repo XiaoLuoLYG/Appless-Phone \
  --base main \
  --title "refactor: converge Appless on structured four-agent runtime" \
  --body-file /tmp/appless-single-runtime-pr.md
```

Keep it Draft and report the real validation results without claiming a device run in this phase.

- [ ] **Step 6: Verify remote alignment and PR targets**

```bash
gh pr view 11 --repo Raym0ndKwan/loopy \
  --json number,state,isDraft,baseRefName,headRefName,headRefOid,url
gh pr view 67 --repo XiaoLuoLYG/Appless-Phone \
  --json number,state,isDraft,baseRefName,headRefName,headRefOid,url
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo rev-parse HEAD
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo rev-parse origin/codex/multi-agent-hotel-implementation
git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-parse HEAD
git -C /Users/luoyige/DevEcoStudioProjects/loopy rev-parse fork/codex/appless-agent-core-convergence
```

Expected:

- PR #11 base is `agent-core-convergence`, head is the existing fork branch, Draft is true;
- PR #67 base is `main`, head is the existing Appless branch, Draft is true;
- both local HEADs equal their pushed remote heads.

- [ ] **Step 7: Final repository and worktree cleanup proof**

```bash
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo worktree list
git -C /Users/luoyige/DevEcoStudioProjects/loopy worktree list
git -C /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo status --short
git -C /Users/luoyige/DevEcoStudioProjects/loopy status --short
```

Expected: one worktree and clean status in each repository. Delete no branch or directory merely to make the count look clean; remove only stale linked worktrees that are clean and fully absorbed.
