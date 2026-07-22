// PWA runtime helpers: two browser capabilities the manifest itself can't
// express, both driven from the app at runtime.
//
//   1. **Are we the installed app?** `isStandalone` reports whether the page is
//      running as an installed PWA (launched from the home screen / its own app
//      window) rather than inside a browser tab. It reads the `display-mode`
//      media query that the manifest's `display: "standalone"` drives, and falls
//      back to iOS Safari's non-standard `navigator.standalone` — iOS never
//      matches the media query, so that flag is the only signal there.
//
//   2. **Offer to install.** Chromium fires `beforeinstallprompt` when the app is
//      installable; the platform's own install dialog is *only* reachable by
//      stashing that event and calling `.prompt()` from a later user gesture (a
//      button click). `watchInstall` captures the event and reports availability
//      out; `promptInstall` fires the stashed event on demand. iOS Safari never
//      fires `beforeinstallprompt` — there is no programmatic install on iOS,
//      only the manual Share → "Add to Home Screen" route — so on iOS nothing is
//      captured and the install affordance stays hidden.
//
// These are thin bindings over browser globals (no offline/unit-test surface),
// wired into the Elm loop from Main.res exactly like the service-worker glue.

type window
@val external window: window = "window"

// `matchMedia(query).matches` — the standards-based way to ask the platform what
// display mode the app is actually running in.
type mediaQueryList = {matches: bool}
@send external matchMedia: (window, string) => mediaQueryList = "matchMedia"
let matches = query => (window->matchMedia(query)).matches

// iOS Safari's non-standard `navigator.standalone`: `true` when launched from a
// home-screen icon. Absent everywhere else (hence nullable), which is why the
// media-query check above carries the load on every other platform.
@val @scope("navigator") external navigatorStandalone: Nullable.t<bool> = "standalone"

// True when running as an installed app rather than a browser tab. `standalone`
// is the manifest's mode; `fullscreen` / `minimal-ui` are the other installed
// display modes a manifest can request, folded in so detection doesn't depend on
// which one is configured.
let isStandalone = () =>
  matches("(display-mode: standalone)") ||
  matches("(display-mode: fullscreen)") ||
  matches("(display-mode: minimal-ui)") ||
  navigatorStandalone->Nullable.toOption->Option.getOr(false)

// The Chromium-only `BeforeInstallPromptEvent`. We `preventDefault()` it so the
// browser suppresses its own mini-infobar and hands us control, then `prompt()`
// opens the real install dialog when the user asks for it.
type installPromptEvent
@send external preventDefault: installPromptEvent => unit = "preventDefault"
@send external prompt: installPromptEvent => promise<unit> = "prompt"

@send
external addEventListener: (window, string, installPromptEvent => unit) => unit = "addEventListener"

// The stashed install event. `beforeinstallprompt` fires once when the app
// becomes installable; the event is single-use, so we hold exactly one and clear
// it after prompting (or once installed). `None` means "no install to offer".
let deferredPrompt: ref<option<installPromptEvent>> = ref(None)

// Start listening for installability. `onAvailable` fires when the platform says
// the app can be installed (so the UI can reveal an Install button); `onInstalled`
// fires once the app is actually installed (so the UI can retire it). Called once,
// after the loop is mounted, from Main.res.
let watchInstall = (~onAvailable, ~onInstalled) => {
  window->addEventListener("beforeinstallprompt", event => {
    event->preventDefault
    deferredPrompt := Some(event)
    onAvailable()
  })
  window->addEventListener("appinstalled", _ => {
    deferredPrompt := None
    onInstalled()
  })
}

// Open the platform's install dialog, if one is pending. Must be called from a
// user gesture (a click) — browsers reject a `prompt()` that isn't. The event is
// single-use, so clear it here; the button's visibility is then driven by the
// `appinstalled` callback (or the next `beforeinstallprompt`).
let promptInstall = () =>
  switch deferredPrompt.contents {
  | Some(event) =>
    deferredPrompt := None
    event->prompt->ignore
  | None => ()
  }
