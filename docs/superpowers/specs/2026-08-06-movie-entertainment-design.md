# Movie Entertainment Scene Design

## Scope

Add a dedicated movie entertainment scene beside the existing World Cup scene.
The World Cup page remains registered and unchanged.

The scene opens through a new read-only page intent, `movie.open`. The canonical
device query is `想看看最近有什么电影`. Similar natural-language requests about
current theatrical movies, box office, trailers, or movie-star news may select
the same intent through the model tool registry.

## Evidence and content boundary

- Every visible movie, person, poster, still, hero image, trailer, and short
  video must refer to real published material.
- Placeholder photography, generated people, fake posters, gradient-only media,
  empty video slots, and invented box-office numbers are prohibited.
- Static data is allowed, but the page must show its snapshot date and source.
- Remote playback failure is shown as a real unavailable state with a source
  link. The page must not imply successful playback when the media failed.
- The page is a curated snapshot, not a live box-office or ticketing provider.
- No ticket purchase, login, payment, or provider authorization is implied.

## Architecture

Use the existing registered page-action path:

`model -> movie.open -> LocalModelClient -> registered page action -> Index route -> MovieDemo`

`MovieDemo` is a separate ArkWeb page and raw static experience. It does not
parameterize or branch the World Cup renderer. This costs one small page shell
and one media document, while keeping regression risk out of `AnythingDemo`.

The page uses the existing external URL bridge for source and trailer links.
Only `https` URLs are accepted. No new dependency or generic page framework is
added.

## Visual theme and atmosphere

Reading: a mobile-first entertainment discovery surface with the energy of a
premium cinema lobby and a modern culture magazine.

- Design variance: 8
- Motion intensity: 6
- Visual density: 7
- Theme: dark only, locked across the whole scene
- Shape system: 18 px media cards, full-pill controls, 10 px compact controls
- Accent: Cinema Coral `#E85D4A`

### Palette

- Projector Black `#101113`: page canvas
- Carbon Surface `#181A1E`: primary raised surface
- Graphite Surface `#22252A`: secondary surface
- Frost Text `#F4F1EA`: primary text
- Steel Text `#A5A7AD`: secondary text
- Whisper Line `rgba(244, 241, 234, 0.12)`: structural borders
- Cinema Coral `#E85D4A`: the only accent, used for active controls and focus

No purple, blue-neon glow, pure black, or unrelated section color is allowed.

### Typography

Use the platform sans stack with `HarmonyOS Sans SC`, `PingFang SC`, and system
fallbacks. Headlines use tight tracking and controlled weight. Numeric box
office values use the platform monospace fallback. Body copy remains at least
14 px with relaxed line height.

## Content and components

1. An asymmetric hero uses a real film still or official key art, a short
   headline, snapshot disclosure, and one trailer action.
2. A sticky category rail filters the page between overview, now showing, box
   office, stars, and video.
3. A real video stage switches between at least one long trailer or featurette
   and multiple short-form published clips. Poster, title, duration, provider,
   and source link remain visible.
4. A horizontal now-showing rail uses real posters and opens a compact detail
   panel with synopsis, release status, cast, and source.
5. A box-office component ranks sourced snapshot values without progress bars
   or unsupported live claims.
6. A star-news component uses real portraits or event photographs and expands
   into a short sourced update.
7. A mixed editorial feed uses different layouts for news, interview, and
   behind-the-scenes material.

All interactive controls have at least a 44 px touch target, visible focus,
press feedback, loading state, empty state, and media-error state.

## Motion

- Entry reveals communicate hierarchy and use 40-60 ms stagger.
- Category and card transitions acknowledge state changes.
- Pressable elements scale to 0.97 for 120-160 ms.
- Media switches use opacity and a subtle 0.98 scale, never `scale(0)`.
- Only `transform` and `opacity` animate.
- `prefers-reduced-motion` removes movement while retaining short fades.
- No custom scroll listener, perpetual decorative loop, marquee, or scroll
  hijack is added.

## Routing and safety

- `movie.open` is a read-only system intent.
- `dynamic.search` explicitly excludes first-party movie scene requests.
- Explicit requests to search YouTube or Bilibili still use media search tools.
- The fixed smoke query must produce a `movie.open` action, a movie route log,
  and a visible `电影 Anything OS` marker.
- World Cup routing and its smoke case remain intact.

## Testing

1. Add failing tests for tool registration, registered page-action validation,
   route identity, and the page marker before production changes.
2. Run the focused tests until green.
3. Run the full Hypium suite and read `test_result.txt`.
4. Build the signed HAP and install it over the existing app without clearing
   data.
5. On a physical device, submit the canonical query and capture route logs,
   screenshot, layout, media state, and external-link behavior.
6. Run changed regression: existing core cases plus the new movie query and the
   existing World Cup query.

## Explicit non-goals

- No live box-office API.
- No ticket purchase or seat selection.
- No reusable entertainment page framework.
- No modification or deletion of the World Cup feed.
- No bundled large video files unless remote playback proves unusable on the
  target device and the user approves the repository size cost.
