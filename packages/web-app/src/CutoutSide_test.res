// `CutoutSide.sideFrom` is the whole decision: given the two resolved safe-area
// insets, which side (if any) carries the display cutout. Pure and px-in/string-out
// free, so it's unit-tested directly — the DOM probe and listeners around it
// (`install`) are the untestable-in-jsdom glue.

open Vitest

describe("CutoutSide.sideFrom (#179 follow-up)", () => {
  test("larger left inset ⇒ cutout on the left", () => {
    expect(CutoutSide.sideFrom(44., 0.))->toBe("left")
  })

  test("larger right inset ⇒ cutout on the right", () => {
    expect(CutoutSide.sideFrom(0., 44.))->toBe("right")
  })

  test("equal insets ⇒ none (rail stays on its default side)", () => {
    expect(CutoutSide.sideFrom(0., 0.))->toBe("none")
  })

  test("a sub-pixel difference is noise, not a cutout", () => {
    expect(CutoutSide.sideFrom(0.4, 0.))->toBe("none")
  })

  test("NaN insets (env() unresolved off-device) read as none", () => {
    expect(CutoutSide.sideFrom(Float.Constants.nan, Float.Constants.nan))->toBe("none")
  })
})
