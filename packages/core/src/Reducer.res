// The missing middle of the reduxey loop (#82): an `action` variant and a pure
// `reduce` that transitions the immutable `GameState.t` (#77) and enforces the
// stacking rules (#76). This is the ROADMAP's load-bearing principle made real —
// "immutable state + action variant + pure reducer, illegal actions rejected."
//
// Deliberately still *no view changes*: nothing dispatches yet. This is the
// transition function plus its tests, so the later drivers (the view cutover and
// the CLI) have something to dispatch into. The view keeps its own mutable refs
// for now.
//
// The shapes:
//   - `Game.t` is the *board definition* — each pile's `rule` and the game's
//     `free` flag. Static across a game.
//   - `GameState.t` is the *dynamic* snapshot — where each card rests. It
//     deliberately carries no rules, so the reducer must be handed the `game`
//     too: it closes over both, `reduce(~game, state, action)`.
//   - `result<GameState.t, moveError>` makes rejection explicit, so a driver can
//     tell a *rejected* move (bounce back / red flash) from a legal no-op —
//     unlike a `state => state` reducer that would swallow both.

open Card

// Where a `Move` sends a card: onto a specific pile, or loose onto the table
// (only legal when the game is `free`). `ToPile`/`ToTable` leave room for `Deal`
// and `Undo` to join `action` later.
type target =
  | ToPile(int)
  | ToTable

// The moves the current games allow: for now, moving a single card somewhere.
// A `Move` is one card — multi-card supermoves are later. `Deal`/`Undo` will
// grow this variant when their steps land.
type action = Move({card: card, to: target})

// Why a move was rejected. Distinguishing these lets a driver react precisely —
// a rule refusal flashes red, a not-`free` loose drop snaps the card home — and
// keeps `Ok`/`Error` meaning "did the state change lawfully?", never "was it a
// no-op?" (an identity re-drop is a lawful `Ok`).
type moveError =
  | Rejected // the destination pile's rule refused the card
  | LooseNotAllowed // a loose drop when the game isn't `free`
  | NoSuchPile // the target pile index is out of range
  | CardNotFound // the card isn't anywhere in this state

// The shared legality query (#82): may `card` be dropped onto pile `onto` given
// the current state? Folds the view's current ad-hoc check into one entry point,
// so the reducer and (later) the view's hover highlight both call *this* — "valid
// outline" and "accepted drop" can never disagree, the property #75 relies on,
// now centralised. Delegates to the pure `Rules.accepts` against the pile's
// `rule` and its current top card; an out-of-range pile accepts nothing.
let canDrop = (~game: Game.t, state: GameState.t, card: card, ~onto: int): bool =>
  switch game.piles->Array.get(onto) {
  | Some(pile) => Rules.accepts(pile.rule, card, GameState.topOf(state, onto))
  | None => false
  }

// A fresh snapshot with `card` lifted from wherever it rests — every pile and
// the loose table. `filter`/`map` allocate new arrays, so the input is never
// mutated: the result is a value of its own.
let liftCard = (state: GameState.t, card: card): GameState.t => {
  piles: state.piles->Array.map(cards => cards->Array.filter(c => !GameState.sameCard(c, card))),
  loose: state.loose->Array.filter(c => !GameState.sameCard(c, card)),
}

// `state` with `card` moved to the top of pile `i` (removed from its old home
// first, so a card never appears twice). The array surgery is all copy-on-write.
let placeOnPile = (state: GameState.t, card: card, i: int): GameState.t => {
  let lifted = liftCard(state, card)
  {
    ...lifted,
    piles: lifted.piles->Array.mapWithIndex((cards, idx) =>
      idx == i ? Array.concat(cards, [card]) : cards
    ),
  }
}

// The pure transition. Closes over the board (`~game`) for each pile's `rule`
// and the `free` flag, since `GameState.t` carries no rules. Returns a fresh
// `Ok(state)` on a lawful move — including the identity re-drop of a card onto
// where it already rests — or `Error(moveError)` on an illegal one. The input
// `state` is never mutated.
let reduce = (~game: Game.t, state: GameState.t, action: action): result<GameState.t, moveError> =>
  switch action {
  | Move({card, to: ToPile(i)}) =>
    switch GameState.locationOf(state, card) {
    | None => Error(CardNotFound)
    | Some(_) =>
      switch GameState.topOf(state, i) {
      // Re-dropping a card onto the pile it already tops is an identity `Ok`
      // (mirrors the view's current "re-drop onto its home pile" no-op). Checked
      // before the rule, since a pile never `accepts` its own top card.
      | Some(top) if GameState.sameCard(top, card) => Ok(state)
      | _ =>
        switch game.piles->Array.get(i) {
        | None => Error(NoSuchPile)
        | Some(_) =>
          canDrop(~game, state, card, ~onto=i) ? Ok(placeOnPile(state, card, i)) : Error(Rejected)
        }
      }
    }
  | Move({card, to: ToTable}) =>
    if !game.free {
      // A game that confines cards to piles rejects every loose drop (#63).
      Error(LooseNotAllowed)
    } else {
      switch GameState.locationOf(state, card) {
      | None => Error(CardNotFound)
      | Some(Loose) => Ok(state) // already loose: identity re-drop
      | Some(InPile(_, _)) =>
        let lifted = liftCard(state, card)
        Ok({...lifted, loose: Array.concat(lifted.loose, [card])})
      }
    }
  }
