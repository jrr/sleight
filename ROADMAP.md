# Roadmap: Installable PWA FreeCell

Working toward an installable, offline-capable Progressive Web App that plays
FreeCell, with drag-and-drop and animation, built on the existing pnpm +
ReScript + Vite monorepo.

## The load-bearing principle

**All game state and rules live in `core` as immutable data plus pure
transition functions. The CLI and the web app are both just drivers/renderers
over the same model.**

Concretely, we want a "reduxey" (Elm-architecture) shape in `core`:

- A single immutable `state` value describing the whole game.
- An `action` variant type describing every legal thing the player can do
  (`Move`, `Deal`, `Undo`, `AutoFoundation`, …).
- A pure `reducer: (state, action) => state` (illegal actions are rejected,
  returning the state unchanged or an explicit error).
- The UI holds only *transient* view state (what's being dragged, cursor
  offset, in-flight animations) and `dispatch`es actions into `core`.

Everything the project wants falls out of this one decision:

- **Unit-tested rules** — test the reducer directly, no UI needed.
- **Exercisable via CLI** — the CLI is a text driver that dispatches actions.
- **Undo/redo** — keep a stack of prior `state` values; undo is a pop.
- **Deterministic deals** — a seeded shuffle makes tests and shareable deal
  numbers possible.
- **Offline resume** — serialize `state` to localStorage.

## Decisions

| Decision | Choice |
|---|---|
| Rendering | **Plain DOM bindings** (no rescript-react). Revisit only if composition hurts. |
| Service worker tooling | **`vite-plugin-pwa`** — manifest, precache, build hash, and the update hook. |
| Card rendering | **SVG** cards for full visual control. |
| State ownership | **100% in `core`**, reduxey: immutable state + action variant + pure reducer. |

## Tracks

Two mostly-independent tracks, interleaved so each phase is demoable:

- **Platform track (P1–P2)** — installability, versioning, offline, updates.
  No dependency on game logic.
- **Game track (P3–P8)** — input/animation demos, then the card model, then
  FreeCell.

P1–P2 and P3–P4 have no dependency on each other and can be done in either
order or in parallel. The only hard ordering is **P5 → P6 → P7 → P8**.

---

## P1 · Installable PWA shell

Make the deployed web app installable to a phone home screen and desktop.

- Add `manifest.webmanifest`: `name`, `short_name`, `display: standalone`,
  `theme_color`, `background_color`, and icons (192, 512, plus a maskable icon).
- Add `apple-touch-icon` and the iOS meta tags (iOS ignores parts of the
  manifest and won't fire an install prompt).
- Add `vite-plugin-pwa` generating a service worker that precaches the app
  shell.
- Respect the GitHub Pages project subpath (`/<repo>/`) in `start_url`,
  manifest `scope`, and SW registration scope. Asset paths are already handled
  by `base: "./"`.

**Done when:** "Add to Home Screen" installs the app and it launches
standalone (no browser chrome) on Android/desktop.

## P2 · Version info, offline, and update flow

- Inject build version (git SHA + build timestamp) via a Vite `define`; show it
  in a small "about"/corner element.
- Confirm the app loads with no network (precache).
- Wire the SW update lifecycle (`vite-plugin-pwa` `onNeedRefresh`) so a new
  deploy surfaces an **"Update available" button** that activates the waiting
  worker and reloads.

**Done when:** reloading offline works; visiting online after a new deploy
shows the version and an update button that pulls the latest.

## P3 · Drag-and-drop tech demo

A throwaway page to learn pointer-based dragging in isolation — no game logic.

- Colored boxes draggable between drop zones using **Pointer Events**
  (`pointerdown`/`pointermove`/`pointerup` + `setPointerCapture`).
- `touch-action: none` on draggables to suppress scroll/gesture interference.
- Hit-testing to pick a drop target; snap into place on drop.

**Done when:** boxes drag smoothly between zones on both phone and desktop.

## P4 · Animation tech demo

A throwaway page to learn transitions in isolation.

- **FLIP** technique via the Web Animations API: ease a box from position A to
  B after a layout change.
- Invalid-move "bounce back" animation.

**Done when:** there's a demo showing smoothly animated position changes and a
bounce-back.

---

## P5 · Card model in `core`

- `Suit` / `Rank` / `Card` / `Deck` types.
- **Seeded shuffle** (deterministic — testable, enables deal numbers).
- Generic pile model and move-legality primitives.
- Unit tests.

**Done when:** `core` exposes a tested card model with a deterministic shuffle.

## P6 · Card table + draggable stacks

- Render cards as SVG on a table layout.
- Wire P3 dragging + P4 FLIP animation to move cards between free-form stacks —
  still no rules.

**Done when:** you can drag cards around between stacks in the web app.

## P7 · FreeCell rules in `core` + CLI exerciser

- FreeCell state as a reducer: 8 cascades, 4 free cells, 4 foundations.
- Legal moves, supermoves (limited by free cells + empty columns),
  auto-to-foundation, win detection, undo/redo, numbered deals.
- Extend the CLI into a text-playable game (`deal N`, print board, `move`
  commands) driving the same reducer.
- Unit tests including known deals.

**Done when:** you can play a full game of FreeCell in the terminal and the
rules are covered by tests.

## P8 · Playable FreeCell in the PWA

- Bind the `core` FreeCell reducer to the card table UI; enforce legal moves.
- Animate moves and auto-complete; win screen.
- Persist the in-progress game to localStorage (resume offline).
- Undo button.

**Done when:** FreeCell is fully playable in the installed, offline-capable PWA.

---

## Stretch / later

- A second variant (Klondike) reusing `core`.
- Shareable/numbered deals, timer, and stats.
- Autosolve or hint.
- Keyboard play and accessibility.
- Playwright end-to-end tests for the drag interactions.
