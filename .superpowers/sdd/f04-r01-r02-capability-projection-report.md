# F04 / R01 / R02 Capability Projection Report

## Outcome

PASS for the scoped source, build, and host-runtime migration.

- F04 price/search prompts project `food.search` without
  `luckin.order.preview`.
- Explicit Luckin ordering prompts still project `luckin.order.preview`.
- R01 projects and executes the read-only `social.community.search`.
- R02 projects and executes `social.post.preview` as a zero-Data virtual
  Action. The route renders a provider-identity-backed preview and contains no
  publish provider tool.
- `social.reply.draft` remains limited to a selected real SocialHub item.

No live device/provider checkout was requested or claimed by this scoped
migration.

## Strict TDD Evidence

Tests were added before production changes. The authoritative RED after the
complete required test set was registered was:

```text
Tests run: 1240, Failure: 8, Error: 0, Pass: 1232, Ignore: 0
```

The failures reproduced the missing 46-tool registry projection, the unscoped
Luckin preview catalog, the absent R01 community execution, the absent R02
virtual preview route, and its minimum safe argument contract.

The final authoritative Hypium artifact is:

```text
entry/.test/default/intermediates/test/coverage_data/test_result.txt
Tests run: 1246, Failure: 0, Error: 0, Pass: 1246, Ignore: 0
Timestamp: 2026-07-24T00:49:29+0800
SHA-256: a04d28e2e83923f54582fe2246a403e76cb1555ff9f5e77ff23066b0226434e9
```

The full command was:

```sh
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Hvigor still emits the repository's existing post-test coverage reporter
`00507008` JSON parsing error. The fresh, complete `test_result.txt` above has
zero failures and zero errors.

## Implementation

- The current prompt now reaches the multi-agent planning-context provider.
  That projection reuses `isExplicitLuckinOrderPrompt` and removes the Luckin
  preview only when the current prompt is not an explicit order.
- The fixed registries restore exactly one `social.community.search` Data tool
  and one `social.post.preview` Action tool. Fixed capability counts are now
  46 total: 25 Data and 21 Action.
- The Leader prompt declares the R01/R02/reply selection boundary.
- Existing read-only Composio adapters were selectively restored for X,
  LinkedIn, Instagram, and Reddit community/profile reads. No social provider
  write alias was added.
- The standalone post route accepts only one supported platform, the exact
  `publish` preview operation, and 1–3000 characters of text. Invalid or
  ambiguous prompts fail closed.
- Preview generation reads the real provider identity. Missing identity,
  authorization, network, or provider failures render as errors instead of
  invented success.
- The existing SocialHub A2UI/native/HTML presentation seams now carry a
  preview-only publication state. No publish button or provider receipt is
  synthesized.
- Approved design/plan documents changed only where their fixed tool counts
  conflicted with the restored R01/R02 registry.

## Verification

- `node scripts/verify-loopy-backend.mjs`
  - `AIPhone Loopy backend smoke passed (310 checks).`
  - `agent_core` HAR build: PASS
- Authoritative full Hypium: 1246/1246 PASS
- `git diff --check`: PASS

## Self-review and Preservation

- Compared the current implementation with historical commits `4a873b67` and
  `7e8e39bf`; only read/preview paths required by this brief were restored.
- No social publish, reply-publish, or delete capability was ported.
- No keyword router, provider, second registry, or UI redesign was added.
- PR #68 mail-body code and smoke-evidence scripts were not changed.
- The two pre-existing untracked smoke-evidence directories remain untouched
  and unstaged.

## Independent Review Follow-up

All findings in `f04-r01-r02-review-fixes.md` were fixed with tests registered
before the production changes.

The authoritative follow-up RED was:

```text
Tests run: 1250, Failure: 8, Error: 0, Pass: 1242, Ignore: 0
```

The failures covered the production structured renderer, unsuccessful
Composio envelopes, the production registered action handler, target-only
platform parsing, the exact approved R02 query, both legacy SocialHub gateway
invariants, and the Reddit authorization projection. The structural verifier
also failed its three new single-registry/design assertions before the fix.

The follow-up changes:

- route exact `social.community.search` results through the community A2UI
  renderer so public Reddit posts are not filtered as private messages;
- treat `successful:false` community observations as provider failures while
  retaining a concrete provider error when one exists;
- propagate `socialHub.publication.status=error` through the production page
  action handler;
- parse exactly one platform from the command target, never from post body
  text, reject ambiguous targets, and support the approved natural-language
  R02 prompt without rewriting it;
- require a selected real item ID, explicit platform, and instruction for
  legacy reply drafts, and validate `operation=publish` for preview requests
  before provider identity lookup;
- replace the independently maintained public tool-definition table with a
  compatibility projection derived from runtime `ToolDefinitionRegistry`;
- restore Reddit to the Composio toolkit candidate projection; and
- correct the remaining Action count from 20 to 21.

Final follow-up evidence:

```text
entry/.test/default/intermediates/test/coverage_data/test_result.txt
Tests run: 1250, Failure: 0, Error: 0, Pass: 1250, Ignore: 0
Timestamp: 2026-07-24T01:13:43+0800
SHA-256: ee2f2db09974d17873dddd67c8f5749fb936e1fccdd308f82d198840c6f76fcc
```

- `node scripts/verify-loopy-backend.mjs`
  - `AIPhone Loopy backend smoke passed (287 checks).`
  - `agent_core` HAR build: PASS
- `git diff --check`: PASS
- no social publication write route was added;
- PR #68 mail-body code, smoke scripts, cleanup paths, and both pre-existing
  untracked smoke-evidence directories remain untouched.

The verifier count is lower than the earlier 310 because checks against the
deleted duplicate public registry were removed; the runtime authority and
compatibility derivation are now checked directly.

## Selected-Item Projection Re-review

The second re-review was implemented test-first. The authoritative RED was:

```text
Tests run: 1252, Failure: 4, Error: 0, Pass: 1248, Ignore: 0
```

Those four failures proved that a legacy model could still invent an item ID
for `social.reply.draft`, that both the legacy and multi-agent top-level model
catalogs still exposed that selected-item action, and that the gateway accepted
the model-owned legacy route. The strengthened structural verifier separately
reported 12 expected failures covering the same two catalog leaks, the missing
historical Reddit default connection, and stale count/list/gate claims in the
four approved migration documents. Its HAR build already passed in RED.

The re-review changes:

- remove `social.reply.draft` from both top-level model catalog projections
  while retaining it in the single runtime registry and selected-item
  ActionOffer path;
- make the SocialHub gateway reject reply drafts unless the invocation is the
  exact `social.reply.draft` page action, clearing any model-supplied item ID
  from the error surface before a provider draft can run;
- add no selection cache or inferred selection fallback;
- restore `reddit` / `Reddit` to `defaultSocialHubConnections`;
- correct the approved design, foundation, domain-migration, and cutover
  documents to 46 fixed tools split into 25 Data and 21 Action tools, including
  `social.community.search` and `social.post.preview`; and
- strengthen the verifier to check the design table, fenced tool lists,
  foundation examples and gate, domain executor count, cutover gate, restored
  IDs, Reddit production default, both catalog exclusions, and absence of the
  stale 44 or 24/20 gates.

Final second re-review evidence:

```text
entry/.test/default/intermediates/test/coverage_data/test_result.txt
Tests run: 1252, Failure: 0, Error: 0, Pass: 1252, Ignore: 0
Timestamp: 2026-07-24T01:23:38+0800
SHA-256: 3c638e634e4e42013ef9ecda496b194054dea0a3ae3d958caa45d8d12fa539e7
```

- `node scripts/verify-loopy-backend.mjs`
  - `AIPhone Loopy backend smoke passed (299 checks).`
  - `agent_core` HAR build: PASS
- `git diff --check`: PASS
- the existing coverage reporter warning `00507008` remains non-fatal;
- no social write, selection cache, smoke script, mail-body code, or cleanup
  path was added or changed; and
- both pre-existing untracked smoke-evidence directories remain untouched and
  unstaged.

## Approved-Plan Count Re-review

The final Minor was reproduced with a verifier-first change. Six mutation
fixtures separately proved rejection of these stale forms:

- `20 fixed definitions`;
- `20 fixed Action tools`;
- complete `44-tool` migration set;
- wave `.size).assertEqual(44)`;
- `44 migrated IDs`; and
- completed `44-tool` ownership.

Before the documents changed, all six fixture checks passed while the real
approved-document aggregate failed exactly one gate:

```text
FAIL approved specs and plans contain no stale fixed-tool count claims
1 verification check(s) failed.
```

The domain plan now uses 21 for both remaining Action statements. The cutover
plan now uses 46 for the migration-set interface, wave-size assertion, expected
migrated IDs, and completed ownership dependency.

Final evidence:

- `node scripts/verify-loopy-backend.mjs`
  - `AIPhone Loopy backend smoke passed (305 checks).`
  - all six stale-form fixtures: PASS
  - approved-document aggregate gate: PASS
  - `agent_core` HAR build: PASS
- `git diff --check`: PASS
- full Hypium was not rerun because the complete follow-up diff contains only
  Markdown evidence/plans and the Node verifier; no ArkTS/runtime/test source
  changed.
- both pre-existing untracked smoke-evidence directories remain untouched and
  unstaged.
