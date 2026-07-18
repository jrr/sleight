// The URL query parameters the app understands, parsed once at startup. Two knobs,
// both aimed at driving the app into a fixed, shareable position without touching
// it — which is exactly what the screenshot report needs (it points a headless
// browser at `?scene=freecell&state=midgame` and shoots the result):
//
//   - `scene` — which scene to mount, by its id (`?scene=freecell`). Overrides the
//     last scene persisted in localStorage, so a link always lands on the named
//     scene regardless of what was last viewed on that device.
//   - `state` — a named starting *scenario* for that scene (`?state=midgame`),
//     resolved against `core`'s `Scenario.forName`. Absent (or unrecognised for
//     the scene) means the ordinary opening deal.
//
// Both are plain reads of `window.location.search`; nothing here mutates the URL.

@val @scope(("window", "location")) external search: string = "search"

// The browser's own query-string parser, so escaping and repeated keys behave
// exactly as a URL says rather than by hand-rolled splitting.
type searchParams
@new external makeSearchParams: string => searchParams = "URLSearchParams"
@send external getParam: (searchParams, string) => Nullable.t<string> = "get"

type t = {
  scene: option<string>,
  state: option<string>,
}

// Parse the current location's query string. A missing *or empty* parameter reads
// as `None`, so `?scene=` is treated the same as no `scene` at all.
let parse = (): t => {
  let params = makeSearchParams(search)
  let read = key =>
    switch params->getParam(key)->Nullable.toOption {
    | Some("") | None => None
    | Some(value) => Some(value)
    }
  {scene: read("scene"), state: read("state")}
}
