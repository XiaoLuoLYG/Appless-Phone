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
