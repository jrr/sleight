// Tests for the SVG support added to the hand-rolled `Html` runtime (#35):
//   1. <svg> and its descendants are created in the SVG namespace (so a browser
//      draws them as vector graphics), while ordinary HTML tags are not.
//   2. Generic `attrs` (viewBox, d, fill, hyphenated stroke-width, …) are set.
//   3. An attribute-only change *patches the existing node in place* — the same
//      DOM node is reused, its attribute updated, and a dropped attribute
//      removed — rather than tearing the subtree down and rebuilding it.
//
// These run under jsdom (see vitest.config.js), which implements namespaces and
// attribute reflection.
open Vitest

let svgNS = "http://www.w3.org/2000/svg"
let htmlNS = "http://www.w3.org/1999/xhtml"

// A few read-side DOM bindings the runtime itself doesn't need but the assertions
// do. `Html.element` so they line up with the nodes `Html.create` returns.
@get external namespaceURI: Html.element => string = "namespaceURI"
@send external getAttribute: (Html.element, string) => Nullable.t<string> = "getAttribute"
@get external firstChild: Html.element => Html.element = "firstChild"

describe("Html SVG support", () => {
  test("creates <svg> and its descendants in the SVG namespace", () => {
    let dom = Html.create(
      <svg>
        <circle />
      </svg>,
    )
    expect(namespaceURI(dom))->toBe(svgNS)
    expect(namespaceURI(firstChild(dom)))->toBe(svgNS)
  })

  test("keeps ordinary HTML tags in the HTML namespace", () => {
    let dom = Html.create(
      <div>
        <span />
      </div>,
    )
    expect(namespaceURI(dom))->toBe(htmlNS)
    expect(namespaceURI(firstChild(dom)))->toBe(htmlNS)
  })

  test("sets generic attributes, including hyphenated ones", () => {
    let dom = Html.create(
      <svg attrs={[("viewBox", "0 0 10 10"), ("stroke-width", "2")]}>
        <circle />
      </svg>,
    )
    expect(getAttribute(dom, "viewBox")->Nullable.toOption)->toEqual(Some("0 0 10 10"))
    expect(getAttribute(dom, "stroke-width")->Nullable.toOption)->toEqual(Some("2"))
  })

  test("patches an attribute change in place, reusing the node", () => {
    // Render an initial <svg><circle fill=red .../></svg> into a container.
    let before =
      <svg>
        <circle attrs={[("fill", "red"), ("r", "5")]} />
      </svg>
    let container = Html.create(<div />)
    Html.patchChildren(container, [], [before])

    let circleBefore = firstChild(firstChild(container))
    expect(getAttribute(circleBefore, "fill")->Nullable.toOption)->toEqual(Some("red"))

    // Patch to a new tree that only changes `fill` and drops `r`.
    let after =
      <svg>
        <circle attrs={[("fill", "blue")]} />
      </svg>
    Html.patchChildren(container, [before], [after])

    let circleAfter = firstChild(firstChild(container))
    // Same physical DOM node — patched, not recreated.
    expect(circleAfter === circleBefore)->toBe(true)
    // The changed attribute is updated…
    expect(getAttribute(circleAfter, "fill")->Nullable.toOption)->toEqual(Some("blue"))
    // …and the dropped attribute is removed (idempotent: absent ⇒ removed).
    expect(getAttribute(circleAfter, "r")->Nullable.toOption)->toEqual(None)
  })
})
