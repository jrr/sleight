// The scene switcher: a picker control (a <select> drop-down) that selects which
// scene is mounted into a separate shared container.
// Selecting a scene tears the current one down, clears the container, and mounts
// the chosen one — exactly one scene is live at a time. The selection is
// persisted to localStorage so a reload returns to the same scene.
//
// `render` hands the picker and container back as two separate nodes (see `t`)
// rather than one wrapper, so the caller can place the controls outside the
// scene box while the box wraps only the scene itself.

// localStorage can throw (private mode, storage disabled), so every access is
// wrapped below; these bindings stay thin.
@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"

let storageKey = "sleight:active-scene"

let readPersisted = () =>
  try getItem(storageKey)->Nullable.toOption catch {
  | _ => None
  }

let persist = id =>
  try setItem(storageKey, id) catch {
  | _ => ()
  }

// The switcher's two pieces, handed back separately so the caller can place
// them independently — the `controls` drop-down sits outside (and above) the
// scene band, while the `scene` container is what the band wraps.
type t = {
  controls: WebDom.element, // the picker drop-down
  scene: WebDom.element, // the shared container hosting the active scene
}

// Build the switcher UI and return its two pieces. When `scenes` is empty the
// container simply stays empty. Otherwise the initial scene is the first of these
// that names a real scene: the `~forced` id (from the URL's `?scene=`, so a link
// always lands where it says), then the persisted scene, then the first scene.
let render = (~forced: option<string>=?, scenes: array<Scene.t>): t => {
  let picker = WebDom.createElement("select")
  picker->WebDom.setAttribute("id", "scene-picker")

  let container = WebDom.createElement("section")
  container->WebDom.setAttribute("id", "scene-container")

  // Teardown for the currently mounted scene; a noop until one is mounted.
  let teardown = ref(() => ())

  // One <option> per scene, keyed by scene id so a change event can look the
  // selected scene back up.
  scenes->Array.forEach(scene => {
    let option = WebDom.createElement("option")
    option->WebDom.setAttribute("value", scene.id)
    option->WebDom.setTextContent(scene.label)
    picker->WebDom.appendChild(option)->ignore
  })

  let activate = (scene: Scene.t) => {
    teardown.contents()
    WebDom.clear(container)
    teardown := scene.mount(container)
    persist(scene.id)
    // Keep the <select> in sync — matters for the initial mount, where the
    // scene is chosen programmatically rather than by the user.
    picker->WebDom.setValue(scene.id)
  }

  // Selecting an option activates its scene.
  picker->WebDom.addEventListener("change", () =>
    switch scenes->Array.find(scene => scene.id == picker->WebDom.value) {
    | Some(scene) => activate(scene)
    | None => ()
    }
  )

  // Initial scene: the forced (URL) id if it names a scene, else the persisted one
  // if it's still present, else the first.
  let byId = id => scenes->Array.find(scene => scene.id == id)
  let initial =
    forced
    ->Option.flatMap(byId)
    ->Option.orElse(readPersisted()->Option.flatMap(byId))
    ->Option.orElse(scenes[0])
  switch initial {
  | Some(scene) => activate(scene)
  | None => ()
  }

  {controls: picker, scene: container}
}
