// Size-stability test for the extracted `RefreshControl` component (#201).
//
// The bug this guards against: the Updates section used to grow a line the moment
// a status message ("Checking…") appeared and shrink back when it cleared, so the
// whole Settings screen below it reflowed. The fix reserves the status line's
// height (it's always in the DOM, blank when idle — see `RefreshControl` and the
// `.menu-refresh__status` rule), so the section is the same size in every state.
//
// **What "a good size test" means here.** These run under jsdom (see
// vitest.config.js), which has no layout engine — every `getBoundingClientRect`
// is zero, so we can't measure pixels. What we *can* assert is the thing pixels
// depend on: the **size-determining structure**. Two renders that produce the
// same tree of element boxes lay out identically; a section only wiggles when a
// box appears, disappears, or collapses. So the test renders the component across
// all its states, reduces each to a *tag skeleton* (element tags + nesting, with
// text and attributes stripped — those don't change the box count), and asserts
// the skeleton is invariant. Reserved-but-blank and reserved-and-filled render
// the identical skeleton; a status line that came and went would not.
//
// (A pixel-exact version — measure each state's height in a real browser and
// assert equality — is the belt-and-suspenders complement, but it needs a real
// layout engine, i.e. Playwright, rather than jsdom.)
open Vitest

@get external tagName: Html.element => string = "tagName"
type htmlCollection
@get external childElements: Html.element => htmlCollection = "children"
@get external collLength: htmlCollection => int = "length"
@send external collItem: (htmlCollection, int) => Html.element = "item"
@send external querySelector: (Html.element, string) => Nullable.t<Html.element> = "querySelector"

// The size-determining shape of a rendered subtree: each element's tag plus the
// skeleton of its element children, in order. Text nodes and attributes are
// ignored — reserving a line with `min-height` keeps the box even when its text
// is blank, and that's exactly the invariant we're pinning.
let rec skeleton = (el: Html.element): string => {
  let kids = el->childElements
  let parts = []
  for i in 0 to kids->collLength - 1 {
    parts->Array.push(kids->collItem(i)->skeleton)
  }
  let inner = parts->Array.length == 0 ? "" : `(${parts->Array.join(",")})`
  el->tagName ++ inner
}

let render = (status): Html.element =>
  Html.create(RefreshControl.make({label: "Check for updates", status, onClick: () => ()}))

describe("RefreshControl size stability (#201)", () => {
  // The three states a shown refresh control moves through: idle (no message),
  // and two different transient messages.
  let idle = render(None)
  let checking = render(Some("Checking…"))
  let upToDate = render(Some("Up to date"))

  test("renders the identical box skeleton whether or not a status is showing", () => {
    let reference = skeleton(idle)
    expect(skeleton(checking))->toBe(reference)
    expect(skeleton(upToDate))->toBe(reference)
  })

  test("keeps the status line in the DOM even when idle, so its height stays reserved", () => {
    // The reserved slot is what makes the skeletons above match: it's present with
    // no message, not conjured into existence when one arrives.
    expect(idle->querySelector(".menu-refresh__status")->Nullable.toOption->Option.isSome)->toBe(
      true,
    )
  })
})
