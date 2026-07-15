// A tiny hand-rolled JSX runtime — no React, no framework, no dependency.
//
// ReScript's *generic* JSX transform ("jsx": {"module": "Html"} in rescript.json)
// lowers JSX into calls on THIS module. The view is a *description* — a `vnode`
// tree — and `mount` reconciles it against the real DOM: on each change it diffs
// the new tree against the previous one and patches in place, reusing DOM nodes
// wherever the shape matches. That reuse is what lets a state change update an
// element's class (say, to reverse a spin) without tearing the node down and
// restarting its CSS animation.
//
// The transform's contract (discovered from the compiler's own output):
//   <div class=..>{x}</div>   →  Elements.jsx("div", {className:.., children:?someElement(x)})
//   <div>{a}{b}</div>         →  Elements.jsxs("div", {children:?Some(array([a, b]))})
//   <Comp prop=.. />          →  jsx(Comp.make, {prop:..})
//   <>{a}{b}</>               →  jsxs(jsxFragment, {children:?Some(array([a, b]))})

type element // a real DOM Node
type domEvent
type nodeList

// HTML elements are created with `createElement`; SVG elements must be created
// in the SVG namespace with `createElementNS`, or the browser treats an <svg> /
// <path> as unknown HTML and never draws it. Which one a tag uses is decided by
// the `inSvg` flag threaded through create/patch below (an <svg> ancestor puts
// every descendant in this namespace).
@val @scope("document") external make: string => element = "createElement"
let svgNamespace = "http://www.w3.org/2000/svg"
@val @scope("document") external makeNS: (string, string) => element = "createElementNS"
@val @scope("document") external textNode: string => element = "createTextNode"
@val @scope("document") external fragment: unit => element = "createDocumentFragment"
@send external appendChild: (element, element) => element = "appendChild"
@send external removeChild: (element, element) => element = "removeChild"
@send
external replaceChild: (element, ~newNode: element, ~oldNode: element) => element = "replaceChild"
@send external setAttribute: (element, string, string) => unit = "setAttribute"
@send external removeAttribute: (element, string) => unit = "removeAttribute"
@set external setTextContent: (element, string) => unit = "textContent"
@send external addEventListener: (element, string, domEvent => unit) => unit = "addEventListener"
@get external childNodes: element => nodeList = "childNodes"
@send external nodeAt: (nodeList, int) => element = "item"
@get external lastChild: element => Nullable.t<element> = "lastChild"

// The current click handler is stashed on the node itself, so one stable
// listener can forward to it. Patching then swaps the handler by re-stashing —
// no add/removeEventListener churn, and no dangling closures.
@set external setClick: (element, option<domEvent => unit>) => unit = "_onClick"
@get external getClick: element => option<domEvent => unit> = "_onClick"

// The keys of the generic `attrs` last applied to a node are stashed on the
// node too, so patching can remove any attribute that's gone in the new props
// without needing the old vnode — keeping `applyProps` idempotent (absent ⇒
// removed) on its own.
@set external setAttrKeys: (element, array<string>) => unit = "_attrKeys"
@get external getAttrKeys: element => Nullable.t<array<string>> = "_attrKeys"

// --- Custom events (outward DOM CustomEvents) --------------------------------
// A component defines its own events in ReScript (see OutwardEvents) and fires
// them from a host element with `emit`; `on` is the listener side. `composed`
// lets the event cross the shadow-DOM boundary.
type customEvent<'detail>
@new
external makeCustomEvent: (
  string,
  {"detail": 'detail, "bubbles": bool, "composed": bool},
) => customEvent<'detail> = "CustomEvent"
@send external dispatchEvent: (element, customEvent<'detail>) => bool = "dispatchEvent"

let emit = (host, ~name, ~detail) =>
  dispatchEvent(
    host,
    makeCustomEvent(name, {"detail": detail, "bubbles": true, "composed": true}),
  )->ignore

@get external eventDetail: customEvent<'detail> => 'detail = "detail"
@send
external addCustomListener: (element, string, customEvent<'detail> => unit) => unit =
  "addEventListener"

let on = (target, ~name, handler) =>
  addCustomListener(target, name, event => handler(eventDetail(event)))

// --- Virtual nodes -----------------------------------------------------------
type rec vnode =
  | VNode({tag: string, props: elementProps, children: array<vnode>})
  | VText(string)
  | VGroup(array<vnode>) // sibling group from `array`; flattened when materialised
  | VRaw(element) // an externally-owned real DOM node, spliced in untouched
and elementProps = {
  id?: string,
  className?: string,
  hidden?: bool,
  onClick?: domEvent => unit,
  // A generic attribute map — the escape hatch for anything without a typed
  // field above. This is what carries SVG geometry (`viewBox`, `d`, `fill`,
  // `x`/`y`, `transform`, hyphenated `stroke-width`, …), which is too open-ended
  // and too namespaced to spell out as record fields. Written as `[(name, value)
  // …]` in JSX; applied and patched idempotently by `applyProps`.
  attrs?: array<(string, string)>,
  children?: vnode,
}

// Text child: `{Html.string("hi")}` inside JSX.
let string = s => VText(s)
// Combine sibling children; flattened out when a node's children are built.
let array = xs => VGroup(xs)
// Splice a real DOM node, built elsewhere (imperatively), straight into the
// view — e.g. `{Html.node(sceneSwitcher)}`. The reconciler leaves it entirely
// alone across re-renders, so its owner keeps full control of its subtree.
let node = el => VRaw(el)

// Capitalized <Component/> → jsx(Component.make, props); a component is just a
// function from its props to a vnode.
let jsx = (component, props) => component(props)
let jsxs = jsx

// Fragments (<>…</>): a component whose only prop is its already-combined children.
type fragmentProps = {children?: vnode}
let jsxFragment = (props: fragmentProps) => props.children->Option.getOr(VGroup([]))

// Expand VGroups so a node's children are a flat list of VNode/VText, each of
// which maps to exactly one real DOM node (keeps the positional diff simple).
let childrenOf = (c: option<vnode>): array<vnode> => {
  let acc = []
  let rec go = n =>
    switch n {
    | VGroup(xs) => xs->Array.forEach(go)
    | leaf => acc->Array.push(leaf)
    }
  c->Option.forEach(go)
  acc
}

module Elements = {
  // Props for lowercase DOM elements. Grow this record as the UI needs more
  // (href, type_, value, draggable, aria-*, …) — the one place attributes live.
  type props = elementProps
  // The transform wraps a single child through `someElement`; after `array`
  // combining, children is one vnode, so jsx and jsxs share a builder.
  let someElement = x => Some(x)
  let jsx = (tag: string, props: props) => VNode({tag, props, children: childrenOf(props.children)})
  let jsxs = jsx
}

// --- Reconciler --------------------------------------------------------------
// Set/clear the flat attributes an elementProps can carry, idempotently — the
// same function serves both creation and patching (absent field => removed).
let applyProps = (el, props: elementProps) => {
  switch props.id {
  | Some(v) => setAttribute(el, "id", v)
  | None => removeAttribute(el, "id")
  }
  switch props.className {
  | Some(v) => setAttribute(el, "class", v)
  | None => removeAttribute(el, "class")
  }
  switch props.hidden {
  | Some(true) => setAttribute(el, "hidden", "")
  | _ => removeAttribute(el, "hidden")
  }
  setClick(el, props.onClick)

  // Generic attributes: set every pair in the new map, and remove any attribute
  // that was in the *previous* map (stashed on the node) but is now gone — so an
  // attribute-only change patches in place and dropped attributes disappear.
  let newAttrs = props.attrs->Option.getOr([])
  let newKeys = newAttrs->Array.map(((k, _)) => k)
  switch getAttrKeys(el)->Nullable.toOption {
  | Some(oldKeys) =>
    oldKeys->Array.forEach(k =>
      if !(newKeys->Array.includes(k)) {
        removeAttribute(el, k)
      }
    )
  | None => ()
  }
  newAttrs->Array.forEach(((k, v)) => setAttribute(el, k, v))
  setAttrKeys(el, newKeys)
}

// Build a real DOM node from a vnode (used for first render and for subtrees the
// diff decides to replace wholesale). `inSvg` says whether this vnode sits under
// an <svg> ancestor — if so (or if it *is* the <svg>), it and its descendants
// are created in the SVG namespace so they render as vector graphics.
let rec create = (~inSvg=false, vnode) =>
  switch vnode {
  | VText(s) => textNode(s)
  | VRaw(el) => el
  | VGroup(xs) =>
    let frag = fragment()
    xs->Array.forEach(x => appendChild(frag, create(~inSvg, x))->ignore)
    frag
  | VNode({tag, props, children}) =>
    let inSvg = inSvg || tag == "svg"
    let el = inSvg ? makeNS(svgNamespace, tag) : make(tag)
    applyProps(el, props)
    // One listener, attached once; it forwards to whatever handler is stashed.
    addEventListener(el, "click", ev =>
      switch getClick(el) {
      | Some(h) => h(ev)
      | None => ()
      }
    )
    children->Array.forEach(c => appendChild(el, create(~inSvg, c))->ignore)
    el
  }

// Patch one DOM node to match `newV`, given the `oldV` it currently reflects.
// `inSvg` is threaded so a wholesale replacement rebuilds in the right namespace.
let rec patch = (~inSvg=false, parent, dom, oldV, newV) =>
  switch (oldV, newV) {
  | (VText(a), VText(b)) =>
    if a != b {
      setTextContent(dom, b)
    }
  | (VNode({tag: t1, children: oldKids, _}), VNode({tag: t2, props, children: newKids, _}))
    if t1 == t2 =>
    // Same tag → reuse this node: just update its attributes and its children.
    applyProps(dom, props)
    patchChildren(~inSvg=inSvg || t1 == "svg", dom, oldKids, newKids)
  | (VRaw(a), VRaw(b)) if a === b => () // same externally-owned node → leave it be
  | (_, _) => replaceChild(parent, ~newNode=create(~inSvg, newV), ~oldNode=dom)->ignore
  }
// Positional diff of a parent's children: patch the overlap, then append or
// trim the tail. No keys yet — fine for fixed structure; add keys when a list
// can reorder.
and patchChildren = (~inSvg=false, parent, oldKids, newKids) => {
  let oldLen = Array.length(oldKids)
  let newLen = Array.length(newKids)
  let shared = oldLen < newLen ? oldLen : newLen
  for i in 0 to shared - 1 {
    patch(
      ~inSvg,
      parent,
      nodeAt(childNodes(parent), i),
      oldKids->Array.getUnsafe(i),
      newKids->Array.getUnsafe(i),
    )
  }
  for i in oldLen to newLen - 1 {
    appendChild(parent, create(~inSvg, newKids->Array.getUnsafe(i)))->ignore
  }
  for _ in 1 to oldLen - newLen {
    switch lastChild(parent)->Nullable.toOption {
    | Some(n) => removeChild(parent, n)->ignore
    | None => ()
    }
  }
}

// --- A minimal Elm-style loop ------------------------------------------------
// `update` is pure state and may return a command (a `unit => unit` effect,
// `noEffect` for none) run after the patch. Each dispatch re-derives the view
// and reconciles it against the previous one, so unchanged nodes stay put.
let noEffect = () => ()

let mount = (~root, ~init, ~update, ~view) => {
  let model = ref(init)
  let prev = ref([]) // previous flattened top-level children
  let rec dispatch = msg => {
    let (next, effect) = update(msg, model.contents)

    // Re-render only when the model actually changed (physical equality): a
    // message that just fires an effect (e.g. a click reported outward) touches
    // no DOM at all.
    if next !== model.contents {
      model := next
      render()
    }
    effect()
  }
  and render = () => {
    let nextKids = childrenOf(Some(view(model.contents, dispatch)))
    patchChildren(root, prev.contents, nextKids)
    prev := nextKids
  }
  render()
  dispatch
}
