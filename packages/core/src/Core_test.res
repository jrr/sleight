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
    // Both piles enforce the tableau rule; take the first and stack the dealt run
    // end-to-end onto it: each card lands on the one below it (an empty pile
    // founds the run).
    let rule = (Game.stacking.piles->Array.getUnsafe(0)).rule
    let run = Game.stacking.loose
    let legal =
      run->Array.mapWithIndex(
        (c, i) => Rules.accepts(rule, c, i == 0 ? None : Some(run->Array.getUnsafe(i - 1))),
      )
    expect(legal->Array.every(x => x))->toBe(true)
    // A same-colour or non-consecutive drop is rejected.
    expect(Rules.accepts(rule, {suit: Spades, rank: Two}, Some({suit: Clubs, rank: Ace})))->toBe(
      false,
    )
    expect(Rules.accepts(rule, {suit: Hearts, rank: Four}, Some({suit: Clubs, rank: Ace})))->toBe(
      false,
    )
  })

  test("foundations pairs a same-suit foundation with an alternating tableau", () => {
    let piles = Game.foundations.piles
    expect(piles->Array.map(p => p.rule))->toEqual([Rules.foundation, Rules.tableau])
    // The dealt Hearts Ace→King run stacks end-to-end onto the foundation and
    // completes it, ending on the King.
    let hearts = Game.foundations.loose->Array.filter(c => c.suit == Hearts)
    let foundationRule = (piles->Array.getUnsafe(0)).rule
    let legal =
      hearts->Array.mapWithIndex(
        (c, i) =>
          Rules.accepts(foundationRule, c, i == 0 ? None : Some(hearts->Array.getUnsafe(i - 1))),
      )
    expect(legal->Array.every(x => x))->toBe(true)
    expect(Rules.isCompleteRun(hearts))->toBe(true)
    // The foundation rejects an off-suit card even when the rank ascends, and
    // opens accepting only an Ace.
    expect(
      Rules.accepts(foundationRule, {suit: Spades, rank: Two}, Some({suit: Hearts, rank: Ace})),
    )->toBe(false)
    expect(Rules.accepts(foundationRule, {suit: Hearts, rank: King}, None))->toBe(false)
  })

  test("four-fans is free-arrangement: any card lands on any pile", () => {
    // The un-ordered demo uses the permissive rule, so no drop is rejected.
    let rule = (Game.fourFans.piles->Array.getUnsafe(0)).rule
    expect(Rules.accepts(rule, {suit: Spades, rank: King}, Some({suit: Spades, rank: Two})))->toBe(
      true,
    )
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
    expect(Game.all->Array.map(g => g.id))->toEqual(["stacking", "foundations", "four-fans"])
    expect(Game.all->Array.every(g => g.name != ""))->toBe(true)
  })
})

// The stackability rules (#76): pure predicates over `rule` data, tested without
// any view.
describe("Rules", () => {
  test("suits map to their two colours", () => {
    expect(Rules.color(Hearts))->toBe(Rules.Red)
    expect(Rules.color(Diamonds))->toBe(Rules.Red)
    expect(Rules.color(Spades))->toBe(Rules.Black)
    expect(Rules.color(Clubs))->toBe(Rules.Black)
  })

  // The #75 rule, now expressed as data (`Rules.tableau`) and weighed by the one
  // shared `accepts` predicate.
  describe("tableau (alternating colour, ascending)", () => {
    let accepts = (c, onto) => Rules.accepts(Rules.tableau, c, onto)

    test(
      "any card founds an empty pile",
      () => {
        expect(accepts({suit: Spades, rank: King}, None))->toBe(true)
        expect(accepts({suit: Hearts, rank: Ace}, None))->toBe(true)
      },
    )

    test(
      "the opposite colour, one rank higher, stacks",
      () => {
        // black Ace ← red Two, red Two ← black Three.
        expect(accepts({suit: Hearts, rank: Two}, Some({suit: Spades, rank: Ace})))->toBe(true)
        expect(accepts({suit: Clubs, rank: Three}, Some({suit: Hearts, rank: Two})))->toBe(true)
      },
    )

    test(
      "same colour is rejected even when the rank ascends",
      () => {
        expect(accepts({suit: Clubs, rank: Two}, Some({suit: Spades, rank: Ace})))->toBe(false)
      },
    )

    test(
      "a non-consecutive rank is rejected even when the colour alternates",
      () => {
        expect(accepts({suit: Hearts, rank: Three}, Some({suit: Spades, rank: Ace})))->toBe(false)
      },
    )

    test(
      "a descending or equal rank is rejected",
      () => {
        expect(accepts({suit: Hearts, rank: Ace}, Some({suit: Spades, rank: Two})))->toBe(false)
        expect(accepts({suit: Hearts, rank: Two}, Some({suit: Spades, rank: Two})))->toBe(false)
      },
    )
  })

  // A foundation (`Rules.foundation`): build up by suit from the Ace.
  describe("foundation (same suit, ascending from Ace)", () => {
    let accepts = (c, onto) => Rules.accepts(Rules.foundation, c, onto)

    test(
      "only an Ace founds an empty pile",
      () => {
        expect(accepts({suit: Hearts, rank: Ace}, None))->toBe(true)
        expect(accepts({suit: Spades, rank: Ace}, None))->toBe(true)
        // No higher card may open the pile.
        expect(accepts({suit: Hearts, rank: Two}, None))->toBe(false)
        expect(accepts({suit: Hearts, rank: King}, None))->toBe(false)
      },
    )

    test(
      "the same suit, one rank higher, stacks",
      () => {
        expect(accepts({suit: Hearts, rank: Two}, Some({suit: Hearts, rank: Ace})))->toBe(true)
        // The King completes the run: Queen ← King, same suit.
        expect(accepts({suit: Hearts, rank: King}, Some({suit: Hearts, rank: Queen})))->toBe(true)
      },
    )

    test(
      "a different suit is rejected even when the rank ascends",
      () => {
        // Same colour, different suit (both red) is still rejected.
        expect(accepts({suit: Diamonds, rank: Two}, Some({suit: Hearts, rank: Ace})))->toBe(false)
        expect(accepts({suit: Spades, rank: Two}, Some({suit: Hearts, rank: Ace})))->toBe(false)
      },
    )

    test(
      "a non-consecutive or descending rank is rejected within the suit",
      () => {
        expect(accepts({suit: Hearts, rank: Three}, Some({suit: Hearts, rank: Ace})))->toBe(false)
        expect(accepts({suit: Hearts, rank: Ace}, Some({suit: Hearts, rank: Two})))->toBe(false)
      },
    )
  })

  test("Free accepts anything", () => {
    expect(
      Rules.accepts(Rules.Free, {suit: Spades, rank: Two}, Some({suit: Spades, rank: King})),
    )->toBe(true)
    expect(Rules.accepts(Rules.Free, {suit: Spades, rank: Two}, None))->toBe(true)
  })

  describe("isCompleteRun", () => {
    // A full Ace→King run in one suit, built low-to-high.
    let fullRun =
      [Ace, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King]->Array.map(
        rank => {suit: Hearts, rank},
      )

    test(
      "a full Ace→King run is complete",
      () => {
        expect(Rules.isCompleteRun(fullRun))->toBe(true)
      },
    )

    test(
      "an empty pile is not complete",
      () => {
        expect(Rules.isCompleteRun([]))->toBe(false)
      },
    )

    test(
      "a pile short of the King is not complete",
      () => {
        // Ace→Queen: twelve cards, not yet done.
        let almost = fullRun->Array.slice(~start=0, ~end=12)
        expect(Rules.isCompleteRun(almost))->toBe(false)
      },
    )
  })
})
