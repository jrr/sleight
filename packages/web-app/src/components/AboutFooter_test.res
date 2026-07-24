// Size-stability test for the extracted `AboutFooter` component (#201).
//
// The bug this guards against: the update block used to be rendered with `hidden`
// (`display: none`) when no update was waiting, so the footer collapsed most of
// the time and then expanded — shoving the version line and everything above it —
// the moment an update arrived. The fix keeps the block laid out at all times and
// toggles its *visibility* instead (see `AboutFooter` and `.menu-update--hidden`),
// so the footer is the same height in both states.
//
// See `RefreshControl_test` for why the assertion is structural rather than
// pixel-measured: jsdom has no layout engine, so we pin the size-determining tree
// (element tags + nesting) — which is what a box-collapsing `display: none` would
// change but a `visibility: hidden` reserve would not — plus the specific
// regression guard that the block never falls back to the `hidden` attribute.
open Vitest

@get external tagName: Html.element => string = "tagName"
type htmlCollection
@get external childElements: Html.element => htmlCollection = "children"
@get external collLength: htmlCollection => int = "length"
@send external collItem: (htmlCollection, int) => Html.element = "item"
@send external querySelector: (Html.element, string) => Nullable.t<Html.element> = "querySelector"
@send external hasAttribute: (Html.element, string) => bool = "hasAttribute"

// The size-determining shape of a rendered subtree: tag + children skeleton, with
// text and attributes stripped. A block hidden with `visibility` keeps its box (so
// the skeleton is unchanged); one hidden with `display: none` would not — but the
// browser still reports the element, so the skeleton alone can't catch a
// regression to `hidden`. The dedicated attribute check below does.
let rec skeleton = (el: Html.element): string => {
  let kids = el->childElements
  let parts = []
  for i in 0 to kids->collLength - 1 {
    parts->Array.push(kids->collItem(i)->skeleton)
  }
  let inner = parts->Array.length == 0 ? "" : `(${parts->Array.join(",")})`
  el->tagName ++ inner
}

let render = (~updateVisible, ~offlineReady=false): Html.element =>
  Html.create(
    AboutFooter.make({
      version: "1.2.3",
      buildTime: "2026-07-23T20:20:00.000Z",
      offlineReady,
      updateVisible,
      onReload: () => (),
    }),
  )

describe("AboutFooter size stability (#201)", () => {
  let noUpdate = render(~updateVisible=false)
  let updateWaiting = render(~updateVisible=true)

  test("renders the identical box skeleton whether or not an update is waiting", () => {
    expect(skeleton(updateWaiting))->toBe(skeleton(noUpdate))
  })

  test("keeps the update block in the DOM when hidden, so its height stays reserved", () => {
    // Present in both states — reserved with `visibility`, not conjured on arrival.
    expect(noUpdate->querySelector(".menu-update")->Nullable.toOption->Option.isSome)->toBe(true)
    expect(updateWaiting->querySelector(".menu-update")->Nullable.toOption->Option.isSome)->toBe(
      true,
    )
  })

  test("hides the block with visibility, never the collapsing `hidden` attribute", () => {
    // The regression guard: `hidden` (⇒ `display: none`) would collapse the box and
    // bring the wiggle straight back. The hidden state must use the reserving class.
    switch noUpdate->querySelector(".menu-update")->Nullable.toOption {
    | Some(block) => expect(block->hasAttribute("hidden"))->toBe(false)
    | None => expect("menu-update present")->toBe("menu-update missing")
    }
  })

  test("the offline-ready badge variant doesn't change the footer skeleton", () => {
    // The version line's text grows with an "offline-ready" suffix; that's text, not
    // structure, so the footer's box tree is unchanged.
    expect(skeleton(render(~updateVisible=true, ~offlineReady=true)))->toBe(skeleton(updateWaiting))
  })
})
