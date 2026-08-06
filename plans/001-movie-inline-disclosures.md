# 001 — Layer movie interactions with polished inline disclosures

- **Status**: DONE
- **Commit**: 053e56a0
- **Severity**: HIGH
- **Category**: Purpose & frequency, easing & duration, interruptibility, accessibility
- **Estimated scope**: 2 files, about 180 lines changed

## Problem

The movie page currently routes movie, box-office, actor, and briefing details through the same modal. This makes distinct content types feel identical and overuses an occasional interaction pattern for frequently scanned information.

```html
<!-- entry/src/main/resources/rawfile/movie_entertainment.html:400 — current -->
<button class="rank-row" data-detail-title="Spider-Man: Brand New Day" ...>
```

```html
<!-- entry/src/main/resources/rawfile/movie_entertainment.html:417 — current -->
<button data-detail-title="Tom Holland" ...>App 内查看资料</button>
```

```js
// entry/src/main/resources/rawfile/movie_entertainment.html:528 — current
var detailTitle = target.getAttribute('data-detail-title') || target.getAttribute('data-movie');
```

There is also no disclosure motion. The existing reduced-motion rule suppresses every transition, including useful opacity feedback:

```css
/* entry/src/main/resources/rawfile/movie_entertainment.html:293 — current */
*, *::before, *::after { scroll-behavior: auto !important; transition-duration: 0.01ms !important; }
```

The visible UI also repeats `2026.08.06` snapshot labels, which the product no longer wants.

## Target

- Keep movie `查看详情` actions in the existing App-local dialog, but replace each short sentence with a complete multi-sentence synopsis.
- Convert each actor action into an inline biography disclosure inside its actor card.
- Convert each box-office row into an inline five-day trend disclosure.
- Convert each movie briefing into an inline full-article disclosure.
- Leave only explicit `官方来源` actions as external navigation.
- Remove every visible `2026.08.06` / `08.06 页面快照` field. Preserve a concise `演示数据，非实时` boundary without a date.
- Use one native JavaScript disclosure handler keyed by `data-expand`, `aria-expanded`, and panel `id`; opening one panel closes its siblings in the same section.
- Add these motion tokens:

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
```

- Disclosure content enters with `opacity: 0` and `transform: translateY(-6px)`, then reaches `opacity: 1` and `transform: translateY(0)` over `220ms var(--ease-out)`. The intrinsic disclosure wrapper may transition `grid-template-rows` over the same 220ms so surrounding content moves continuously instead of teleporting.
- Press feedback uses `transform: scale(.97)` for `140ms var(--ease-out)`.
- The modal enters from `opacity: 0; transform: translateY(8px) scale(.97)` to its resting state over `220ms var(--ease-out)`.
- Under `prefers-reduced-motion: reduce`, remove translation and grid movement but retain a `120ms` opacity/color transition.

## Repo conventions to follow

- Keep all web presentation and interaction code in `entry/src/main/resources/rawfile/movie_entertainment.html`.
- Reuse the existing event delegation and existing `<dialog>`; do not create another page, bridge, or dependency.
- Reuse the existing `--accent`, `--panel`, `--line`, and `.button:active` conventions.
- Keep the light native shell colors already staged in `entry/src/main/ets/pages/A2uiHome/MovieDemo.ets`.

## Steps

1. In `movie_entertainment.html`, remove visible dated snapshot labels and replace them with undated, truthful static-data wording.
2. Expand all six movie `data-copy` values into complete synopses. Keep `data-movie` wired to the existing dialog and add `white-space: pre-line` plus a bounded scroll area if needed.
3. Replace box-office `data-detail-*` modal wiring with five inline panels containing accessible text rows for `前四日` through `今日`. Give each row button `data-expand`, `aria-expanded="false"`, and `aria-controls`.
4. Replace actor `data-detail-*` modal wiring with one inline biography panel per actor card, preserving an explicit small `官方资料` external link inside the expanded panel.
5. Refactor each briefing button into a card with an internal toggle button and a full article panel of at least two paragraphs. Keep a small explicit `阅读官方来源` action inside the expanded panel.
6. Add one delegated `data-expand` handler before the external-link branch. Toggle `aria-expanded`, the panel `.open` class, and the trigger label. Close sibling disclosures within the closest section.
7. Add the exact motion tokens and disclosure/modal/press transitions from the Target section. Do not add keyframes or dependencies.
8. Preserve the existing HTTPS trust check and `AIPhoneMovie` bridge. Do not change World Cup, routing, tool registration, or provider code.

## Boundaries

- Do NOT touch the World Cup page or shared renderers.
- Do NOT add a new component, dependency, route, or action type.
- Do NOT convert official-source links into local copies.
- Do NOT claim the static box-office trend is live data.
- If the current file no longer contains the cited interaction seams, stop and report instead of improvising.

## Verification

- **Mechanical**:
  - Extract the inline `<script>` and compile it with `new Function`.
  - Assert the HTML contains six `data-movie` actions, five box-office `data-expand` actions, three actor `data-expand` actions, and three briefing `data-expand` actions.
  - Assert `2026.08.06` and `08.06 页面快照` do not appear.
  - Run `git diff --check`.
  - Run Harmony tests and expect `Tests run: 1599, Failure: 0, Error: 0`.
  - Build and install the signed HAP.
- **Feel check**:
  - On a real device, expand a box-office row and confirm the five-day trend unfolds in place.
  - Immediately tap another row and confirm the first closes while the second opens without restarting from a blank state.
  - Expand an actor biography and a briefing article; confirm neither launches another app.
  - Open a movie detail and confirm the dialog contains a full synopsis and enters without a visual jump.
  - Confirm explicit `官方来源` controls remain visually secondary.
  - With reduced motion enabled, confirm content still fades but does not translate.
- **Done when**: all four interaction types behave at their intended layer, the light page remains intact, no dated snapshot field is visible, and real-device evidence shows at least one inline disclosure plus the movie modal.
