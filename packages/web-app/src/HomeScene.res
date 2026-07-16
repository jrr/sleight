// The Home scene: the app's title and tagline, mined out of the permanent chrome
// into a scene of their own (issue #59). They now show only when "Home" is the
// selected scene — every other scene gets the scene area to itself — so the
// header no longer sits fixed above the switcher.
//
// Static content, but it renders through the same `Html.mount` loop as the other
// JSX scenes (GalleryScene, SvgScene); a trivial unit-state loop hosts it. The
// switcher clears the container when another scene is picked, so there's no extra
// teardown.

let view = (_model, _dispatch) => <>
  <h1 id="greeting"> {Html.string("Sleight")} </h1>
  <p id="tagline"> {Html.string("Might become a solitaire game someday")} </p>
</>

let make = (): Scene.t => {
  id: "home",
  label: "Home",
  mount: container => {
    Html.mount(
      ~root=container,
      ~init=(),
      ~update=(_msg, model) => (model, Html.noEffect),
      ~view,
    )->ignore
    () => ()
  },
}
