// Stackability rules: *pure* predicates over card identities, deciding whether a
// candidate card may land on a pile. This is Step 1 of the roadmap-to-M1 sketch
// (#75): the rule is a standalone `(candidate, target) => bool` function rather
// than logic inlined in the pointer/drop handler, even though the game state is
// still view-owned for now.
//
// Keeping it here — pure and free of any view or DOM concern — means the later
// M1 migration relocates it into a reducer (`Rules.canDrop`) instead of
// rewriting it, and it is unit-testable immediately (see `Core_test`). A game
// picks the rule its piles enforce (`Game.stackRule`); the view's hover
// highlight and its drop-accept/reject decision call that one function, so the
// green "valid" outline and the accepted drop can never disagree.
//
// #76 then generalises this single rule into a data-driven rule per pile (adding
// a same-suit foundation).

open Card

// The two card colours. The alternating-colour rule cares only about this
// coarser distinction, not the suit itself — hearts and diamonds are red; spades
// and clubs black. (The presentation layer has its own `suitColor` for the ink;
// this is the model's notion, so the rule stays presentation-free.)
type color =
  | Red
  | Black

let color = suit =>
  switch suit {
  | Hearts | Diamonds => Red
  | Spades | Clubs => Black
  }

// A rank's position in the Ace→King run, so "ascends consecutively" is just a
// `+ 1` comparison. Ace is the low end (1), King the high end (13).
let rankValue = rank =>
  switch rank {
  | Ace => 1
  | Two => 2
  | Three => 3
  | Four => 4
  | Five => 5
  | Six => 6
  | Seven => 7
  | Eight => 8
  | Nine => 9
  | Ten => 10
  | Jack => 11
  | Queen => 12
  | King => 13
  }

// May `candidate` be stacked on a pile whose current top card is `onto` (`None`
// for an empty pile)? The alternating-colour, ascending-run rule: any card may
// found an empty pile, and thereafter each newcomer must be the opposite colour
// and exactly one rank higher — so a pile climbs Ace→King in alternating
// colours, and a full run can be assembled from a dealt one.
let alternatingAscending = (candidate: card, onto: option<card>): bool =>
  switch onto {
  | None => true
  | Some(top) =>
    color(candidate.suit) != color(top.suit) && rankValue(candidate.rank) == rankValue(top.rank) + 1
  }

// The permissive rule: any card may land on any pile. Games that don't order
// their piles (the free-arrangement card-table demos) use this.
let free = (_candidate: card, _onto: option<card>): bool => true
