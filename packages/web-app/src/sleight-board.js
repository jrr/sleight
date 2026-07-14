// The <sleight-board> custom element.
//
// This file is now just the *shell*: the `class extends HTMLElement` lifecycle
// that ReScript can't express (no class syntax) plus registration. Everything
// that used to be hand-written DOM here — the `innerHTML` string, `querySelector`,
// the click listener, the transform decoding — moved into Board.res, which
// renders the inside as ReScript JSX on the Html runtime (see Board.res).
//
// The custom-element contract is unchanged (*attributes in, events out*):
//   inward   — the observed `spin="cw" | "ccw"` attribute; CSS in Board.res
//              reacts, so changing direction still needs no JavaScript.
//   outward  — Board.res calls the `notify` callback with the card's current
//              rotation; we wrap that in the same `card-poked` CustomEvent
//              (`bubbles`/`composed` so it escapes the shadow root).

import { mount } from "./Board.res.mjs";

class SleightBoard extends HTMLElement {
  connectedCallback() {
    const root = this.attachShadow({ mode: "open" });
    // Hand the ReScript view the shadow root to paint into, plus the one
    // capability it needs across the boundary: emit an outward event.
    mount(root, (angle) => {
      this.dispatchEvent(
        new CustomEvent("card-poked", {
          detail: { angle },
          bubbles: true,
          composed: true,
        }),
      );
    });
  }
}

// Registration is exposed as an explicit call rather than a bare import side
// effect, so Main can guarantee the element is defined before it creates one.
// Idempotent: safe if called more than once (e.g. under HMR).
export function register() {
  if (!customElements.get("sleight-board")) {
    customElements.define("sleight-board", SleightBoard);
  }
}
