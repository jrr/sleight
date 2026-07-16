open Vitest
open Card

test("greeting returns the expected message", () => {
  expect(Core.greeting())->toBe("Hello from ReScript core!")
})

// The modelled games (#62): assert the rules the presentation layer reads back.
describe("Game", () => {
  test(
    "the stacking demo is two piles (squared, then fanned), free, dealt an Ace→King run",
    () => {
      expect(Game.stacking.piles->Array.map(p => p.stacking))->toEqual([Game.Squared, Game.Fanned])
      expect(Game.stacking.free)->toBe(true)
      // The whole run is dealt loose, low-to-high, so it can be assembled onto a
      // pile: thirteen cards, Ace→King, each the opposite colour of the one below.
      expect(Game.stacking.loose->Array.map(c => c.rank))->toEqual([
        Ace,
        Two,
        Three,
        Four,
        Five,
        Six,
        Seven,
        Eight,
        Nine,
        Ten,
        Jack,
        Queen,
        King,
      ])
      let colours = Game.stacking.loose->Array.map(c => Rules.color(c.suit))
      expect(colours->Array.every(c => c == Rules.Red || c == Rules.Black))->toBe(true)
      // No two neighbours share a colour, so every step up the run is a legal drop.
      let alternates =
        colours
        ->Array.mapWithIndex((c, i) => i == 0 || c != colours->Array.getUnsafe(i - 1))
        ->Array.every(x => x)
      expect(alternates)->toBe(true)
    },
  )

  test("the stacking demo confines drops to a legal Ace→King run", () => {
    // The dealt run stacks end-to-end onto a pile: each card lands on the one
    // below it (an empty pile founds the run).
    let run = Game.stacking.loose
    let legal =
      run->Array.mapWithIndex(
        (c, i) => Game.stacking.stackRule(c, i == 0 ? None : Some(run->Array.getUnsafe(i - 1))),
      )
    expect(legal->Array.every(x => x))->toBe(true)
    // A same-colour or non-consecutive drop is rejected.
    expect(
      Game.stacking.stackRule({suit: Spades, rank: Two}, Some({suit: Clubs, rank: Ace})),
    )->toBe(false)
    expect(
      Game.stacking.stackRule({suit: Hearts, rank: Four}, Some({suit: Clubs, rank: Ace})),
    )->toBe(false)
  })

  test("four-fans is free-arrangement: any card lands on any pile", () => {
    // The un-ordered demo uses the permissive rule, so no drop is rejected.
    expect(
      Game.fourFans.stackRule({suit: Spades, rank: King}, Some({suit: Spades, rank: Two})),
    )->toBe(true)
  })

  test("four-fans is four fanned piles, not free, opening with cards in each pile", () => {
    expect(Game.fourFans.piles->Array.map(p => p.stacking))->toEqual([
      Game.Fanned,
      Game.Fanned,
      Game.Fanned,
      Game.Fanned,
    ])
    expect(Game.fourFans.free)->toBe(false)
    // Every pile opens holding a few cards, and nothing is dealt loose.
    expect(Game.fourFans.piles->Array.every(p => Array.length(p.cards) > 0))->toBe(true)
    expect(Game.fourFans.loose)->toEqual([])
  })

  test("every game is listed with a stable id and a non-empty name", () => {
    expect(Game.all->Array.map(g => g.id))->toEqual(["stacking", "four-fans"])
    expect(Game.all->Array.every(g => g.name != ""))->toBe(true)
  })
})

// The stackability rule (#75): a pure predicate, tested without any view.
describe("Rules", () => {
  test("suits map to their two colours", () => {
    expect(Rules.color(Hearts))->toBe(Rules.Red)
    expect(Rules.color(Diamonds))->toBe(Rules.Red)
    expect(Rules.color(Spades))->toBe(Rules.Black)
    expect(Rules.color(Clubs))->toBe(Rules.Black)
  })

  describe("alternatingAscending", () => {
    test(
      "any card founds an empty pile",
      () => {
        expect(Rules.alternatingAscending({suit: Spades, rank: King}, None))->toBe(true)
        expect(Rules.alternatingAscending({suit: Hearts, rank: Ace}, None))->toBe(true)
      },
    )

    test(
      "the opposite colour, one rank higher, stacks",
      () => {
        // black Ace ← red Two, red Two ← black Three.
        expect(
          Rules.alternatingAscending({suit: Hearts, rank: Two}, Some({suit: Spades, rank: Ace})),
        )->toBe(true)
        expect(
          Rules.alternatingAscending({suit: Clubs, rank: Three}, Some({suit: Hearts, rank: Two})),
        )->toBe(true)
      },
    )

    test(
      "same colour is rejected even when the rank ascends",
      () => {
        expect(
          Rules.alternatingAscending({suit: Clubs, rank: Two}, Some({suit: Spades, rank: Ace})),
        )->toBe(false)
      },
    )

    test(
      "a non-consecutive rank is rejected even when the colour alternates",
      () => {
        expect(
          Rules.alternatingAscending({suit: Hearts, rank: Three}, Some({suit: Spades, rank: Ace})),
        )->toBe(false)
      },
    )

    test(
      "a descending or equal rank is rejected",
      () => {
        expect(
          Rules.alternatingAscending({suit: Hearts, rank: Ace}, Some({suit: Spades, rank: Two})),
        )->toBe(false)
        expect(
          Rules.alternatingAscending({suit: Hearts, rank: Two}, Some({suit: Spades, rank: Two})),
        )->toBe(false)
      },
    )
  })

  test("free accepts anything", () => {
    expect(Rules.free({suit: Spades, rank: Two}, Some({suit: Spades, rank: King})))->toBe(true)
    expect(Rules.free({suit: Spades, rank: Two}, None))->toBe(true)
  })
})
