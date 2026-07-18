// Named *starting scenarios* — canned `GameState.t` snapshots a driver can force
// a board into, instead of always opening from the deal. The web-app selects one
// by name from a URL query parameter (see the web-app's `AppUrl`), which is how
// the screenshot report captures a *mid-game* FreeCell without having to play the
// board interactively first.
//
// A scenario is just a pure function `Game.t => GameState.t`: it lives in `core`
// alongside the state it builds, stays deterministic (seeded, no `Math.random`),
// and is exercised by the same reducer/queries as any other state. Nothing here
// is a new game — these are *positions* within the existing boards.

open Card

// A plausible **mid-game FreeCell** snapshot, derived from the seeded deal so the
// 52-card invariant (every card exactly once) holds by construction: cards are
// only ever *moved* out of the shuffled deck, never invented. It's not the result
// of playing a specific line — it doesn't need to be, the point is a representative
// *layout* — but every pile is a shape a real game reaches: foundations part-built
// up by suit, a couple of free cells occupied, the rest spread across the cascades.
//
//   - Foundations: an ascending Ace-up run per suit, at uneven heights (one suit
//     still untouched) so the top row reads as a game in progress rather than a
//     fresh or finished board.
//   - Free cells: two of the four occupied, two empty.
//   - Cascades: everything left, dealt round-robin across the board's cascades.
//
// Distributed by *role* over the board it's handed, so the snapshot lines up with
// however that board orders its piles (FreeCell puts cells and foundations before
// the cascades — see `Game.freecellDeal`).
let freecellMidgame = (game: Game.t, ~seed: int): GameState.t => {
  let deck = Cards.shuffle(~seed)

  // Each suit's foundation as an ascending run Ace..(nth rank). Heights are
  // deliberately uneven, and one suit is left empty, so the row looks mid-game.
  // Suit order follows `Cards.suits` (Spades, Hearts, Diamonds, Clubs).
  let foundationHeights = [3, 4, 0, 2]
  let foundationPiles = Cards.suits->Array.mapWithIndex((suit, i) =>
    Cards.ranks
    ->Array.slice(~start=0, ~end=foundationHeights->Array.getUnsafe(i))
    ->Array.map(rank => {suit, rank})
  )
  let onFoundation = card =>
    foundationPiles->Array.some(run => run->Array.some(f => GameState.sameCard(f, card)))

  // The rest of the deck, foundation cards removed: two go to free cells, the
  // remainder is dealt across however many cascades the board declares.
  let rest = deck->Array.filter(card => !onFoundation(card))
  let cellCards = rest->Array.slice(~start=0, ~end=2)
  let cascadeCards = rest->Array.slice(~start=2, ~end=Array.length(rest))
  let cascadeCount = Game.pileIndices(game, Game.Cascade)->Array.length
  let cascadePiles = cascadeCards->Cards.deal(~piles=cascadeCount)
  let cellPiles = cellCards->Array.map(card => [card]) // one card per occupied cell

  // Walk the board's piles in order, drawing each role's contents from its queue,
  // so the snapshot matches the board's pile order without assuming it.
  let foundationIdx = ref(0)
  let cellIdx = ref(0)
  let cascadeIdx = ref(0)
  let next = (queue, cursor) => {
    let value = queue->Array.get(cursor.contents)->Option.getOr([])
    cursor := cursor.contents + 1
    value
  }
  let piles = game.piles->Array.map((pile: Game.pile) =>
    switch pile.role {
    | Game.Foundation => next(foundationPiles, foundationIdx)
    | Game.FreeCell => next(cellPiles, cellIdx)
    | Game.Cascade => next(cascadePiles, cascadeIdx)
    }
  )
  {GameState.piles, loose: []}
}

// Resolve a scenario *name* to an initial state for `game`, or `None` when the
// name doesn't apply to this board. This is the whole vocabulary the URL exposes:
// today just FreeCell's "midgame"; new scenarios slot in as new arms.
let forName = (game: Game.t, name: string): option<GameState.t> =>
  switch (game.id, name) {
  | ("freecell", "midgame") => Some(freecellMidgame(game, ~seed=Game.freecellSeed))
  | _ => None
  }
