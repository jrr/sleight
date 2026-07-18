// Tests for the named starting scenarios (Scenario.res). The scenarios feed the
// screenshot report a fixed mid-game position, so the load-bearing guarantee is
// that the position is *well-formed* — it holds a full deck (no card invented,
// dropped or duplicated) and lays out onto the board's roles the way the report
// expects (part-built foundations, a couple of occupied cells, the rest in the
// cascades). These lock that in so a future tweak to the heights or the deal can't
// silently produce a broken board.

open Vitest
open Card

// A pile is a legal foundation run when it's the ascending Ace-up sequence in a
// single suit — Ace, Two, Three, … with no gaps. Built by comparing against the
// canonical run of the first card's suit, so an empty pile trivially passes.
let isFoundationRun = (cards: array<card>): bool =>
  switch cards[0] {
  | None => true
  | Some(first) =>
    let expected =
      Cards.ranks
      ->Array.slice(~start=0, ~end=Array.length(cards))
      ->Array.map(rank => {suit: first.suit, rank})
    cards
    ->Array.mapWithIndex((c, i) =>
      switch expected[i] {
      | Some(e) => GameState.sameCard(c, e)
      | None => false
      }
    )
    ->Array.every(x => x)
  }

describe("Scenario", () => {
  describe("freecell midgame", () => {
    let game = Game.freecell
    let state: GameState.t = Scenario.forName(game, "midgame")->Option.getOrThrow

    test(
      "holds a full 52-card deck, every card exactly once",
      () => {
        let all = state.piles->Array.flatMap(cards => cards)
        expect(Array.length(all))->toBe(52)
        // Every card of the deck is present…
        expect(
          Cards.all->Array.every(card => all->Array.some(c => GameState.sameCard(c, card))),
        )->toBe(true)
        // …and none appears twice (a permutation, not a multiset).
        expect(
          Cards.all->Array.every(
            card => all->Array.filter(c => GameState.sameCard(c, card))->Array.length == 1,
          ),
        )->toBe(true)
      },
    )

    test(
      "opens mid-game: part-built foundations, two occupied cells, the rest in cascades",
      () => {
        let pilesFor = (role: Game.role) =>
          Game.pileIndices(game, role)->Array.map(i => state.piles->Array.getUnsafe(i))
        let foundations = pilesFor(Game.Foundation)
        let cells = pilesFor(Game.FreeCell)
        let cascades = pilesFor(Game.Cascade)

        // Every foundation is a legal ascending run, and together they're partway
        // built — some cards down, but nowhere near a finished four suits.
        expect(foundations->Array.every(isFoundationRun))->toBe(true)
        let onFoundations = foundations->Array.reduce(0, (n, p) => n + Array.length(p))
        expect(onFoundations > 0 && onFoundations < 52)->toBe(true)

        // Exactly two of the four cells are occupied, each holding a single card.
        let occupied = cells->Array.filter(p => Array.length(p) > 0)
        expect(Array.length(occupied))->toBe(2)
        expect(occupied->Array.every(p => Array.length(p) == 1))->toBe(true)

        // The bulk of the deck sits in the cascades, nothing left loose.
        expect(cascades->Array.reduce(0, (n, p) => n + Array.length(p)) > 26)->toBe(true)
        expect(Array.length(state.loose))->toBe(0)
      },
    )
  })

  test("an unknown scenario, or one that doesn't fit the board, is None", () => {
    expect(Scenario.forName(Game.freecell, "no-such-scenario"))->toEqual(None)
    // "midgame" is a FreeCell position; it doesn't apply to the stacking demo.
    expect(Scenario.forName(Game.stacking, "midgame"))->toEqual(None)
  })
})
