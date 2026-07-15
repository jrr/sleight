// The app icon, drawn from the real cards: a trio of aces fanned out over the
// game's green. It nests `CardArt.body` — the exact card face the app renders —
// so evolving the card design carries straight into the icon on the next
// `mise run icons`. `StaticRender.toString` turns this vnode into the SVG the
// generator writes as `icon.svg` and rasterizes to the PNGs the manifest needs.

// Brand green — keep in sync with the manifest theme in vite.config.js.
let green = "#166534"

// The icon is authored in a 512×512 square; the rasterizer scales it to each
// output size. Everything below is in these units.
let size = 512.

// The fan pivots about a point low and centered, so the cards splay upward and
// outward from a shared corner like a hand held open.
let pivotX = 256.
let pivotY = 470.
let lift = 150. // how far each card's center sits above the pivot
let cardScale = 1.7 // native card is 120×168; this sizes it into the icon

// The three fanned cards and their splay angles (degrees). Chosen for color
// balance — black, red, black — and drawn left→right so each overlaps the last.
let fan = [
  ({Deck.suit: Deck.Clubs, rank: Deck.Ace}, -24.),
  ({Deck.suit: Deck.Hearts, rank: Deck.Ace}, 0.),
  ({Deck.suit: Deck.Spades, rank: Deck.Ace}, 24.),
]

// One fanned card: a green "mat" (a slightly larger rounded rect in the game
// color) with the card face nested on top. The mat is what draws the clean gap
// between overlapping cards — each card's own mat masks the card beneath it.
let placedCard = ((card, angle)) => {
  let w = 120. *. cardScale
  let h = 168. *. cardScale
  let mat = 7. // gap width around each card, in icon units
  let f = Float.toString
  <g
    attrs={[
      (
        "transform",
        `translate(${f(pivotX)} ${f(pivotY)}) rotate(${f(angle)}) translate(0 ${f(-.lift)})`,
      ),
    ]}
  >
    <rect
      attrs={[
        ("x", f(-.(w /. 2. +. mat))),
        ("y", f(-.(h /. 2. +. mat))),
        ("width", f(w +. 2. *. mat)),
        ("height", f(h +. 2. *. mat)),
        ("rx", f(12. *. cardScale +. mat)),
        ("fill", green),
      ]}
    />
    <svg
      attrs={[
        ("x", f(-.(w /. 2.))),
        ("y", f(-.(h /. 2.))),
        ("width", f(w)),
        ("height", f(h)),
        ("viewBox", CardArt.viewBox),
      ]}
    >
      {CardArt.body(card)}
    </svg>
  </g>
}

// The full icon.
//   ~cornerRadius: rounded-square background as a fraction of `size` (0 = a
//                  full-bleed square, for maskable / iOS icons that get their
//                  own mask).
//   ~inset:        scales the whole fan about the icon center; < 1 pulls the
//                  cards into the maskable "safe zone".
let svg = (~cornerRadius=0.16, ~inset=1.0) => {
  let f = Float.toString
  <svg
    attrs={[
      ("xmlns", "http://www.w3.org/2000/svg"),
      ("viewBox", `0 0 ${f(size)} ${f(size)}`),
      ("width", f(size)),
      ("height", f(size)),
    ]}
  >
    <rect
      attrs={[
        ("x", "0"),
        ("y", "0"),
        ("width", f(size)),
        ("height", f(size)),
        ("rx", f(size *. cornerRadius)),
        ("fill", green),
      ]}
    />
    <g attrs={[("transform", `translate(256 256) scale(${f(inset)}) translate(-256 -256)`)]}>
      {fan->Array.map(placedCard)->Html.array}
    </g>
  </svg>
}

// Plain-argument variants for the JS build script (no labeled/optional args to
// marshal across the interop boundary): each returns finished SVG markup.
//   standard  — rounded square, full-size fan (the everyday icon and icon.svg)
//   maskable  — full-bleed square, fan pulled into the safe zone
//   fullBleed — full-bleed square, full-size fan (iOS masks the corners itself)
let standardSvg = () => StaticRender.toString(svg())
let maskableSvg = () => StaticRender.toString(svg(~cornerRadius=0., ~inset=0.78))
let fullBleedSvg = () => StaticRender.toString(svg(~cornerRadius=0.))
