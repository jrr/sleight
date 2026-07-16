// The update button. Hidden until the service worker reports a waiting update;
// clicking it activates the new worker and reloads to the fresh version. See
// VersionBadge for why the `props` record is spelled out rather than derived by
// the `@jsx.component` sugar. Layout for `#update-button` lives in the stylesheet
// in index.html, where it's sized and positioned to line up with the scene
// picker across the top of the chrome.
//
// The visible label is deliberately short — a reload glyph plus "Update" — so it
// stays a compact control rather than a banner; the full "Update available —
// reload" wording lives in `title`/`aria-label` for hover tooltips and assistive
// tech.
type props = {visible: bool, onReload: unit => unit}

let make = ({visible, onReload}) =>
  <button
    id="update-button"
    hidden={!visible}
    onClick={_ => onReload()}
    attrs={[
      ("title", "Update available — reload"),
      ("aria-label", "Update available — reload"),
    ]}
  >
    {Html.string("↻ Update")}
  </button>
