// Entry point for the web app. It pulls the string from the shared `core`
// package and renders it into the page.

// Minimal DOM bindings (kept local so the example has no extra dependencies).
@scope("document") @val external body: Dom.element = "body"
@set external setTextContent: (Dom.element, string) => unit = "textContent"

setTextContent(body, Core.greeting())
