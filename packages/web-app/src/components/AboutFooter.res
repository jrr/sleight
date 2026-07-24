// The **About** footer that sits at the foot of both menu screens (#165/#191),
// lifted out of `Menu` into its own pure component so its states can be exercised
// in isolation (#201): the build/version line (`<VersionBadge>`) and, below it,
// the "update available" call-to-action — a short note plus the green **Update
// now** button.
//
// **Why it's a component now — the size story (#201).** This footer was one of
// two areas that changed height with their state. The update block used to be
// rendered with `hidden` (i.e. `display: none`) when no update was waiting, so it
// collapsed to nothing most of the time and then *expanded* — pushing the version
// line and everything above it — the moment an update arrived. The fix keeps the
// block always laid out and toggles its *visibility* instead: `visibility: hidden`
// (via `menu-update--hidden`) reserves the block's box whether or not there's an
// update, so the footer is the same height in both states — only the note and
// button fade in and out of that reserved space. `AboutFooter_test` pins that
// invariant: the size-determining structure is identical for `updateVisible` true
// and false.
//
// `visibility: hidden` also takes the hidden button out of the tab order and out
// of pointer events, so a reserved-but-invisible button can't be focused or
// clicked; `aria-hidden` on the block hides it from assistive tech to match.
//
// A component is just a `props => vnode` function (see `VersionBadge` for why the
// record is spelled out by hand rather than derived by `@jsx.component`).
type props = {
  version: string,
  buildTime: string,
  offlineReady: bool,
  updateVisible: bool,
  onReload: unit => unit,
}

let make = ({version, buildTime, offlineReady, updateVisible, onReload}) =>
  <div className="menu-footer" attrs={[("aria-label", "About")]}>
    <h2 className="menu-section__heading"> {Html.string("About")} </h2>
    <VersionBadge version={version} buildTime={buildTime} offlineReady={offlineReady} />
    // The update block stays in the layout at all times so the footer never
    // reflows; `--hidden` reserves its space with `visibility: hidden` rather than
    // removing it. `aria-hidden` mirrors that for assistive tech when there's no
    // update to offer.
    <div
      className={updateVisible ? "menu-update" : "menu-update menu-update--hidden"}
      attrs={[("aria-hidden", updateVisible ? "false" : "true")]}
    >
      <p className="menu-update__note"> {Html.string("A new version is available")} </p>
      <button
        className="menu-update__button"
        onClick={_ => onReload()}
        attrs={[
          ("type", "button"),
          ("title", "Update available — reload"),
          ("aria-label", "Update now — reload to the new version"),
        ]}
      >
        {Html.string("↻ Update now")}
      </button>
    </div>
  </div>
