// The build-version badge tucked into the corner of the chrome: version and
// build time, plus an "offline-ready" suffix once the service worker reports
// its precache is complete.
//
// A component is just a `props => vnode` function. The JSX transform lowers
// `<VersionBadge .../>` to `Html.jsx(VersionBadge.make, props)` and fills this
// record from the attributes. (The `@jsx.component` sugar that would auto-derive
// `props` isn't usable here — it types `make` as the runtime's `element`, i.e. a
// real DOM node, but on this diffing runtime a view is a `vnode` description — so
// we spell the record out, which is all that sugar expands to anyway.) Layout and
// colors for `#version-badge` live in the stylesheet in index.html; here we build
// only structure and state-dependent text.
//
// `standalone` is whether the app launched as an installed PWA rather than in a
// browser tab (detected via `Pwa.isStandalone`); when set, the badge appends an
// "installed" marker — the visible confirmation that PWA-mode detection works.
type props = {version: string, buildTime: string, offlineReady: bool, standalone: bool}

let monthNames = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
]

// Reformat the raw build timestamp — an ISO 8601 string baked in at build time
// (`2026-07-21T11:03:00.000Z`, always UTC — see vite.config.js's `toISOString`)
// — into something a human reads at a glance (`Jul 21, 2026 · 11:03 UTC`). It's
// parsed by slicing the fixed ISO layout rather than through a `Date`, so it
// stays in UTC with no timezone handling and no `Date` binding; anything that
// doesn't look like that layout (it shouldn't happen) falls back to itself.
let formatBuildTime = iso =>
  if iso->String.length < 16 {
    iso
  } else {
    switch (
      Int.fromString(iso->String.slice(~start=5, ~end=7)),
      Int.fromString(iso->String.slice(~start=8, ~end=10)),
    ) {
    | (Some(month), Some(day)) if month >= 1 && month <= 12 =>
      let year = iso->String.slice(~start=0, ~end=4)
      let hourMinute = iso->String.slice(~start=11, ~end=16)
      let monthName = monthNames->Array.get(month - 1)->Option.getOr("")
      `${monthName} ${day->Int.toString}, ${year} · ${hourMinute} UTC`
    | _ => iso
    }
  }

let make = ({version, buildTime, offlineReady, standalone}) => {
  let built = formatBuildTime(buildTime)
  // Suffixes accrue right-to-left as the app confirms its capabilities: the
  // precache reporting ready, and — when launched from the home screen — that
  // we're running as the installed app.
  let label =
    `v${version} · ${built}` ++
    (offlineReady ? " · offline-ready" : "") ++ (standalone ? " · installed" : "")
  <div id="version-badge"> {Html.string(label)} </div>
}
