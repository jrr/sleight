// Publishes which side a display cutout (notch / front camera) sits on to the
// CSS, as a `data-cutout` attribute on the document root, so the landscape
// chrome can move its control rail to the *safe* side and hand the freed width
// back to the cards (cutout-aware orientation, #179 follow-up).
//
// A `@media (orientation: landscape)` query separates portrait from landscape
// but not landscape-left from landscape-right, and CSS has no way to compare the
// two `env(safe-area-inset-*)` values against each other. So the side is decided
// here in JS: a fixed, zero-size probe element carries
// `padding-left: env(safe-area-inset-left)` and
// `padding-right: env(safe-area-inset-right)`, and whichever *computed* padding
// is larger marks the cutout side. The probe is `position: fixed` so it never
// perturbs the flex layout, and reading a resolved *padding* keeps the value a
// plain px length — the same trick TableScene uses to read the row's insets
// (#179), just at the chrome level and independent of which scene is mounted.

type computed = {"paddingLeft": string, "paddingRight": string}
@val external getComputedStyle: WebDom.element => computed = "getComputedStyle"
@val external parseFloat: string => float = "parseFloat"
@val @scope("document") external documentElement: WebDom.element = "documentElement"
@val @scope("document") external body: WebDom.element = "body"
// The insets change on rotation and on any viewport resize; both events re-read
// the probe. `resize` in particular fires *after* iOS has settled the new insets,
// covering the case where `orientationchange` alone would read stale values.
@val @scope("window")
external addWindowListener: (string, unit => unit) => unit = "addEventListener"

// The probe carries the two insets as paddings we can read back as px. Parked
// off-screen and out of flow (`position: fixed`) so it costs nothing but the read.
let makeProbe = () => {
  let el = WebDom.createElement("div")
  el->WebDom.setAttribute(
    "style",
    "position:fixed;top:0;left:0;width:0;height:0;visibility:hidden;pointer-events:none;" ++ "padding-left:env(safe-area-inset-left);padding-right:env(safe-area-inset-right)",
  )
  el
}

// A ≥1px difference is treated as a real cutout on the larger side; anything
// smaller — symmetric insets, or none at all — is `"none"`, which leaves the rail
// on its default left. `parseFloat` yields NaN where `env()` doesn't resolve
// (e.g. jsdom), read as 0 so a non-browser host simply reports `"none"`.
let sideFrom = (left, right) => {
  let l = Float.isNaN(left) ? 0. : left
  let r = Float.isNaN(right) ? 0. : right
  if l -. r >= 1. {
    "left"
  } else if r -. l >= 1. {
    "right"
  } else {
    "none"
  }
}

let read = probe => {
  let cs = getComputedStyle(probe)
  sideFrom(parseFloat(cs["paddingLeft"]), parseFloat(cs["paddingRight"]))
}

// Mount the probe, publish the side once, and keep it current on rotate/resize.
let install = () => {
  let probe = makeProbe()
  body->WebDom.appendChild(probe)->ignore
  let refresh = () => documentElement->WebDom.setAttribute("data-cutout", read(probe))
  refresh()
  addWindowListener("resize", refresh)
  addWindowListener("orientationchange", refresh)
}
