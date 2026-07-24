// The Settings screen's **Updates** section (#112), lifted out of `Menu` into its
// own pure component so its states can be exercised in isolation (#201). It's the
// adaptive refresh button plus the transient status line that reports back under
// it ("Checking…", "Up to date"): `label` and `onClick` adapt to whether a
// service worker is registered (see Refresh/Main), and `status` is the momentary
// line the button's action publishes.
//
// **Why it's a component now — the size story (#201).** This section was one of
// two areas that changed height with their state: the status line was rendered
// only when there was a message, so the section grew a line the instant a
// "Checking…" appeared and shrank back when it cleared — a visible reflow of
// everything below it. The fix is to make the status line *always present* and
// reserve its height in CSS (`.menu-refresh__status { min-height }`), so the box
// is the same height whether the line is blank or filled. The text just changes
// inside a slot that's always there. `RefreshControl_test` pins that invariant:
// the size-determining structure is identical across every `status`.
//
// The status slot is a persistent `aria-live="polite"` region — now that it's
// always in the DOM (rather than appearing and disappearing), a screen reader can
// watch it and announce each message as the text changes.
//
// A component is just a `props => vnode` function (see `VersionBadge` for why the
// record is spelled out by hand rather than derived by `@jsx.component`). The
// whole section is optional at the *call* site — `Menu` shows it only once a
// worker state is known — so this component always renders a shown control; its
// states are the `status` variations, which is exactly what must not wiggle.
type props = {
  label: string,
  status: option<string>,
  onClick: unit => unit,
}

let make = ({label, status, onClick}) =>
  <div className="menu-section" attrs={[("aria-label", "Updates")]}>
    <h2 className="menu-section__heading"> {Html.string("Updates")} </h2>
    <button className="menu-button" onClick={_ => onClick()} attrs={[("type", "button")]}>
      {Html.string(label)}
    </button>
    // The status line: always rendered so its height is reserved (`min-height` in
    // the stylesheet) and the section never reflows as messages come and go. Blank
    // when there's nothing to say. A polite live region so the change is announced.
    <p className="menu-refresh__status" attrs={[("aria-live", "polite")]}>
      {Html.string(status->Option.getOr(""))}
    </p>
  </div>
